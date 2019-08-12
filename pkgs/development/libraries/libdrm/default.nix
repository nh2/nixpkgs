{ stdenv, fetchurl, curl, lib, fetchpatch, pkgconfig, libpthreadstubs, libpciaccess, valgrind-light }:

stdenv.mkDerivation rec {
  name = "libdrm-2.4.97";

  src = fetchurl {
    url = "https://dri.freedesktop.org/libdrm/${name}.tar.bz2";
    sha256 = "08yimlp6jir1rs5ajgdx74xa5qdzcqahpdzdk0rmkmhh7vdcrl3p";
  };

  outputs = [ "out" "dev" "bin" ];

  nativeBuildInputs = [ pkgconfig ];
  buildInputs = [ libpthreadstubs libpciaccess valgrind-light ];
    # libdrm as of 2.4.70 does not actually do anything with udev.

  patches =
    lib.optionals stdenv.targetPlatform.isMusl [
      # Fix tests not building on musl because they use the glibc-specific
      # (non-POSIX) `ioctl()` type signature. See #66441.
      (fetchpatch {
        url = "https://raw.githubusercontent.com/openembedded/openembedded-core/30a2af80f5f8c8ddf0f619e4f50451b02baa22dd/meta/recipes-graphics/drm/libdrm/musl-ioctl.patch";
        # Wrong hash on purpose to reliably reproduce
        # https://github.com/NixOS/nixpkgs/issues/66499
        # (once the file is downloaded successfully, it won't be retried).
        sha256 = "0000000000000000000000000000000000000000000123123123";
      })
    ];

  postPatch = ''
    for a in */*-symbol-check ; do
      patchShebangs $a
    done
  '';

  configureFlags = [ "--enable-install-test-programs" ]
    ++ stdenv.lib.optionals (stdenv.isAarch32 || stdenv.isAarch64)
      [ "--enable-tegra-experimental-api" "--enable-etnaviv-experimental-api" ]
    ++ stdenv.lib.optional stdenv.isDarwin "-C"
    ++ stdenv.lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) "--disable-intel"
    ;

  meta = {
    homepage = https://dri.freedesktop.org/libdrm/;
    description = "Library for accessing the kernel's Direct Rendering Manager";
    license = "bsd";
    platforms = stdenv.lib.platforms.unix;
  };
}
