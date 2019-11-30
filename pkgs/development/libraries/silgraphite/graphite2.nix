{ stdenv, fetchurl, pkgconfig, freetype, cmake, python, enableStatic ? false }:

stdenv.mkDerivation rec {
  version = "1.3.13";
  pname = "graphite2";

  src = fetchurl {
    url = "https://github.com/silnrsi/graphite/releases/download/"
      + "${version}/graphite2-${version}.tgz";
    sha256 = "01jzhwnj1c3d68dmw15jdxly0hwkmd8ja4kw755rbkykn1ly2qyx";
  };

  nativeBuildInputs = [ pkgconfig cmake ];
  buildInputs = [ freetype ];

  patches = stdenv.lib.optionals stdenv.isDarwin [ ./macosx.patch ];

  # graphite2 can be built only static XOR dynamic.
  # Alpine builds both by building it twice and copying the `.a` over:
  # https://git.alpinelinux.org/aports/tree/main/graphite2/APKBUILD?id=ad6c116184b345846b7bd42746d7b4d47871ab05
  # We do that here as well.

  postConfigure = if !enableStatic then null else ''
    if [ -z ''${staticConfigureDone+x} ]; then
      staticConfigureDone=1

      mkdir -p ../build_static
      cd ../build_static
      dontUseCmakeBuildDir=1
      cmakeDir=..
      cmakeFlags="$cmakeFlags -DBUILD_SHARED_LIBS=OFF"
      cmakeConfigurePhase

      cd ../build
    fi
  '';

  postBuild = if !enableStatic then null else ''
    if [ -z ''${staticBuildDone+x} ]; then
      staticBuildDone=1

      cd ../build_static
      buildPhase

      cd ../build
    fi
  '';

  # In theory we would also have to adjust the `graphite2.pc` file to contain
  # info about both the static and shared libs, but as of writing (1.3.11),
  # the static and shared builds generate identical `.pc` files.
  postInstall = if !enableStatic then null else ''
    cp ../build_static/src/libgraphite2.a $out/lib/libgraphite2.a
  '';

  checkInputs = [ python ];
  doCheck = false; # fails, probably missing something

  meta = with stdenv.lib; {
    description = "An advanced font engine";
    maintainers = [ maintainers.raskin ];
    platforms = platforms.unix;
    license = licenses.lgpl21;
  };
}
