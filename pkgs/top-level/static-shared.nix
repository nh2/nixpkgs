# Overlay that builds packages with both static and shared libraries.
#
# Executable linking is not affected; this overlay aims to
# allow you to choose whether to link statically or dynamically
# at the very end.
#
# Not all packages will build but support is done on a
# best effort basic.

self: super: let
  inherit (super.stdenvAdapters) makeStaticSharedLibraries
                                 propagateBuildInputs;
  inherit (super.lib) foldl flip id;

  staticSharedAdapters = [
    makeStaticSharedLibraries
    # TODO Check if we want to enable this, or if it's too much of a hack.
    #      Especially, check whether it affects closure size of the static
    #      executables' packages.
    #      Given that we keep .so's, if somebody links dynamically in
    #      the end, this would likely blow up their closure; however
    #      it may simply be required for easy static linking, so we
    #      could make that tradeoff, given that people would most likely
    #      want to use this overlay with the end goal of static linking.
    # propagateBuildInputs
  ];

in {
  stdenv = foldl (flip id) super.stdenv staticSharedAdapters;
  gcc49Stdenv = foldl (flip id) super.gcc49Stdenv staticSharedAdapters;
  gcc5Stdenv = foldl (flip id) super.gcc5Stdenv staticSharedAdapters;
  gcc6Stdenv = foldl (flip id) super.gcc6Stdenv staticSharedAdapters;
  gcc7Stdenv = foldl (flip id) super.gcc7Stdenv staticSharedAdapters;
  gcc8Stdenv = foldl (flip id) super.gcc8Stdenv staticSharedAdapters;
  gcc9Stdenv = foldl (flip id) super.gcc9Stdenv staticSharedAdapters;
  clangStdenv = foldl (flip id) super.clangStdenv staticSharedAdapters;
  libcxxStdenv = foldl (flip id) super.libcxxStdenv staticSharedAdapters;

  ncurses = super.ncurses.override {
    enableStatic = true;
  };
  libxml2 = super.libxml2.override {
    enableShared = true;
    enableStatic = true;
  };
  zlib = super.zlib.override {
    shared = true;
    static = true;
    splitStaticOutput = false;
  };
  xz = super.xz.override {
    enableStatic = true;
  };
  busybox = super.busybox.override {
    enableStatic = true;
  };
  # TODO Check if this package can be improved, stripping the manual `--enable-shared`.
  libiberty = super.libiberty.override {
    staticBuild = true;
  };
  ipmitool = super.ipmitool.override {
    static = true;
  };
  neon = super.neon.override {
    static = true;
    shared = true;
  };
  gifsicle = super.gifsicle.override {
    static = true;
  };
  # TODO Check if this package can be improved, allowing both static and shared.
  bzip2 = super.bzip2.override {
    linkStatic = true;
  };
  # TODO Check if this package can be improved, removing `LDFLAGS = "-static"` and using autoconf as usual.
  optipng = super.optipng.override {
    static = true;
  };
  openblas = super.openblas.override { enableStatic = true; };
  openssl = super.openssl.override {
    static = true;

    # Don’t use new stdenv for openssl because it doesn’t like the
    # --disable-shared flag
    stdenv = super.stdenv;
  };
  boost = super.boost.override {
    enableStatic = true;
    enableShared = true;
  };
  gmp = super.gmp.override {
    withStatic = true;
  };
  cdo = super.cdo.override {
    enable_all_static = true;
  };
  gsm = super.gsm.override {
    staticSupport = true;
  };
  parted = super.parted.override {
    enableStatic = true;
  };
  libiconvReal = super.libiconvReal.override {
    enableShared = true;
    enableStatic = true;
  };
  perl = super.perl.override {
    # Don’t use new stdenv zlib because
    # it doesn’t like the --disable-shared flag
    stdenv = super.stdenv;
  };
  lz4 = super.lz4.override {
    enableShared = true;
    enableStatic = true;
  };

  darwin = super.darwin // {
    libiconv = super.darwin.libiconv.override {
      enableShared = true;
      enableStatic = true;
    };
  };

  llvmPackages_8 = super.llvmPackages_8 // {
    libraries = super.llvmPackages_8.libraries // rec {
      libcxxabi = super.llvmPackages_8.libraries.libcxxabi.override {
        enableShared = true;
      };
      libcxx = super.llvmPackages_8.libraries.libcxx.override {
        enableShared = true;
        inherit libcxxabi;
      };
    };
  };

  python27 = super.python27.override { static = true; };

  krb5 = previous.krb5.override {
    # Note [krb5 can only be static XOR shared]
    # krb5 does not support building both static and shared at the same time.
    # That means *anything* on top of this overlay trying to link krb5
    # dynamically from this overlay will fail with linker errors.
    # For that reason we export a `krb5_dynamic` below.
    staticOnly = true;
  };
  krb5_dynamic = previous.krb5;

}
