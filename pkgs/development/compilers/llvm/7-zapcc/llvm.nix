{ stdenv
, fetch
, fetchpatch
, fetchFromGitHub
, gcc
, cmake
, python3
, libffi
, libbfd
, libpfm
, libxml2
, ncurses
, version
, release_version
, zlib
, buildPackages
, debugVersion ? false
, enableManpages ? false
, enableSharedLibraries ? true
, enablePFM ? !(stdenv.isDarwin
  || stdenv.isAarch64 # broken for Ampere eMAG 8180 (c2.large.arm on Packet) #56245
  )
, enablePolly ? false
}:

let
  inherit (stdenv.lib) optional optionals optionalString;

  # Used when creating a versioned symlinks of libLLVM.dylib
  versionSuffixes = with stdenv.lib;
    let parts = splitVersion release_version; in
    imap (i: _: concatStringsSep "." (take i parts)) parts;

in stdenv.mkDerivation ({
  pname = "zapcc-llvm";
  inherit version;

  src = fetchFromGitHub rec {
    owner = "yrnkrn";
    repo = "zapcc";
    rev = "51132ba4029e09aa2faa400b7ca09c5b9f618877"; # last llvm sync is with llvm 7, commit "Merge LLVM 325000"
    sha256 = "0jzan8cl21ybqkjdpd3w9v4f63w6p3ijxylk86fg8y4lfpw4wfqy";
    name = "zapcc-source-${rev}";
  };
  polly_src = fetch "polly" "16qkns4ab4x0azrvhy4j7cncbyb2rrbdrqj87zphvqxm5pvm8m1h";

  outputs = [ "out" "python" ]
    ++ optional enableSharedLibraries "lib";

  nativeBuildInputs = [ cmake python3 ]
    ++ optional enableManpages python3.pkgs.sphinx;

  buildInputs = [ libxml2 libffi ]
    ++ optional enablePFM libpfm; # exegesis

  propagatedBuildInputs = [ ncurses zlib ];

  patches = [
    # backport, fix building rust crates with lto
    (fetchpatch {
      url = "https://github.com/llvm-mirror/llvm/commit/da1fb72bb305d6bc1f3899d541414146934bf80f.patch";
      sha256 = "0p81gkhc1xhcx0hmnkwyhrn8x8l8fd24xgaj1whni29yga466dwc";
    })
    (fetchpatch {
      url = "https://github.com/llvm-mirror/llvm/commit/cc1f2a595ead516812a6c50398f0f3480ebe031f.patch";
      sha256 = "0k6k1p5yisgwx417a67s7sr9930rqh1n0zv5jvply8vjjy4b3kf8";
    })
  ];

  postPatch = optionalString stdenv.isDarwin ''
    substituteInPlace cmake/modules/AddLLVM.cmake \
      --replace 'set(_install_name_dir INSTALL_NAME_DIR "@rpath")' "set(_install_name_dir)" \
      --replace 'set(_install_rpath "@loader_path/../lib" ''${extra_libdir})' ""
  ''
  # Patch llvm-config to return correct library path based on --link-{shared,static}.
  + optionalString (enableSharedLibraries) ''
    substitute '${./llvm-outputs.patch}' ./llvm-outputs.patch --subst-var lib
    patch -p1 < ./llvm-outputs.patch
  '' + ''
    # FileSystem permissions tests fail with various special bits
    substituteInPlace unittests/Support/CMakeLists.txt \
      --replace "Path.cpp" ""
    rm unittests/Support/Path.cpp
  '' + optionalString stdenv.hostPlatform.isMusl ''
    patch -p1 -i ${../TLI-musl.patch}
    substituteInPlace unittests/Support/CMakeLists.txt \
      --replace "add_subdirectory(DynamicLibrary)" ""
    rm unittests/Support/DynamicLibrary/DynamicLibraryTest.cpp
  '' + optionalString stdenv.hostPlatform.isAarch32 ''
    # skip failing X86 test cases on armv7l
    rm test/DebugInfo/X86/debug_addr.ll
    rm test/tools/llvm-dwarfdump/X86/debug_addr.s
    rm test/tools/llvm-dwarfdump/X86/debug_addr_address_size_mismatch.s
    rm test/tools/llvm-dwarfdump/X86/debug_addr_dwarf4.s
    rm test/tools/llvm-dwarfdump/X86/debug_addr_unsupported_version.s
    rm test/tools/llvm-dwarfdump/X86/debug_addr_version_mismatch.s
  '' + optionalString (stdenv.hostPlatform.system == "armv6l-linux") ''
    # Seems to require certain floating point hardware (NEON?)
    rm test/ExecutionEngine/frem.ll
  '' + ''
    patchShebangs test/BugPoint/compile-custom.ll.py
  '' +
  # clang patches taken from `clang/default.nix`, with `tools/clang/` prefix added:
  ''
    sed -i -e 's/DriverArgs.hasArg(options::OPT_nostdlibinc)/true/' \
           -e 's/Args.hasArg(options::OPT_nostdlibinc)/true/' \
           tools/clang/lib/Driver/ToolChains/*.cpp
  '' + stdenv.lib.optionalString stdenv.hostPlatform.isMusl ''
    sed -i -e 's/lgcc_s/lgcc_eh/' tools/clang/lib/Driver/ToolChains/*.cpp
  '' +
  # Manual application of clang `purity.patch` to `tools/clang/` subdir:
  ''
    patch -p1 --directory=tools/clang/ < ${./clang/purity.patch}
  '';

  # hacky fix: created binaries need to be run before installation
  preBuild = ''
    mkdir -p $out/
    ln -sv $PWD/lib $out
  '' +
  # nh2: Hack: There is a bug in the build system as part of which
  # `llvm/IR/Attributes.gen` can racily be built too late, and then includes
  # fail. Build it first to work around that (`intrinsics_gen` builds it).
  ''
    make -j $NIX_BUILD_CORES -l $NIX_BUILD_CORES intrinsics_gen
  '';

  cmakeFlags = with stdenv; [
    "-DCMAKE_BUILD_TYPE=${if debugVersion then "Debug" else "Release"}"
    "-DLLVM_INSTALL_UTILS=ON"  # Needed by rustc
    "-DLLVM_BUILD_TESTS=OFF" # nh2: some tests may fail, or at least I haven't intestigated them yet
    "-DLLVM_ENABLE_FFI=ON"
    "-DLLVM_ENABLE_RTTI=ON"
    "-DLLVM_HOST_TRIPLE=${stdenv.hostPlatform.config}"
    "-DLLVM_DEFAULT_TARGET_TRIPLE=${stdenv.hostPlatform.config}"
    "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly"
    "-DLLVM_ENABLE_DUMP=ON"

    "-DLLVM_ENABLE_WARNINGS=OFF" # from zapcc README
  ] ++ optionals enableSharedLibraries [
    "-DLLVM_LINK_LLVM_DYLIB=ON"
  ] ++ optionals enableManpages [
    "-DLLVM_BUILD_DOCS=ON"
    "-DLLVM_ENABLE_SPHINX=ON"
    "-DSPHINX_OUTPUT_MAN=ON"
    "-DSPHINX_OUTPUT_HTML=OFF"
    "-DSPHINX_WARNINGS_AS_ERRORS=OFF"
  ] ++ optionals (!isDarwin) [
    "-DLLVM_BINUTILS_INCDIR=${libbfd.dev}/include"
  ] ++ optionals (isDarwin) [
    "-DLLVM_ENABLE_LIBCXX=ON"
    "-DCAN_TARGET_i386=false"
  ] ++ optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    "-DCMAKE_CROSSCOMPILING=True"
    "-DLLVM_TABLEGEN=${buildPackages.llvm_7}/bin/llvm-tblgen"
  ]
  # taken from clang/default.nix
  ++ [ "-DCMAKE_CXX_FLAGS=-std=c++11" ]
  ++ stdenv.lib.optional stdenv.isLinux "-DGCC_INSTALL_PREFIX=${gcc}"
  ++ stdenv.lib.optional (stdenv.cc.libc != null) "-DC_INCLUDE_DIRS=${stdenv.cc.libc}/include";

  postBuild = ''
    rm -fR $out
  '';

  preCheck = ''
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$PWD/lib
  '';

  postInstall = ''
    mkdir -p $python/share
    mv $out/share/opt-viewer $python/share/opt-viewer
  ''
  + optionalString enableSharedLibraries ''
    moveToOutput "lib/libLLVM-*" "$lib"
    moveToOutput "lib/libLLVM${stdenv.hostPlatform.extensions.sharedLibrary}" "$lib"
    substituteInPlace "$out/lib/cmake/llvm/LLVMExports-${if debugVersion then "debug" else "release"}.cmake" \
      --replace "\''${_IMPORT_PREFIX}/lib/libLLVM-" "$lib/lib/libLLVM-"
  ''
  + optionalString (stdenv.isDarwin && enableSharedLibraries) ''
    substituteInPlace "$out/lib/cmake/llvm/LLVMExports-${if debugVersion then "debug" else "release"}.cmake" \
      --replace "\''${_IMPORT_PREFIX}/lib/libLLVM.dylib" "$lib/lib/libLLVM.dylib"
    ${stdenv.lib.concatMapStringsSep "\n" (v: ''
      ln -s $lib/lib/libLLVM.dylib $lib/lib/libLLVM-${v}.dylib
    '') versionSuffixes}
  '';

  # doCheck = stdenv.isLinux && (!stdenv.isx86_32);
  doCheck = false; # nh2: some tests may fail, or at least I haven't intestigated them yet

  checkTarget = "check-all";

  enableParallelBuilding = true;

  # taken from clang/default.nix
  passthru = {
    isClang = true;
  } // stdenv.lib.optionalAttrs stdenv.isLinux {
    inherit gcc;
  };

  meta = {
    description = "Collection of modular and reusable compiler and toolchain technologies";
    homepage    = http://llvm.org/;
    license     = stdenv.lib.licenses.ncsa;
    maintainers = with stdenv.lib.maintainers; [ lovek323 raskin dtzWill ];
    platforms   = stdenv.lib.platforms.all;
  };
} // stdenv.lib.optionalAttrs enableManpages {
  pname = "llvm-manpages";

  buildPhase = ''
    make docs-llvm-man
  '';

  propagatedBuildInputs = [];

  installPhase = ''
    make -C docs install
  '';

  postPatch = null;
  postInstall = null;

  outputs = [ "out" ];

  doCheck = false;

  meta.description = "man pages for LLVM ${version}";
})
