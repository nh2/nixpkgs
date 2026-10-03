{
  applyPatches,
  fetchpatch2,
  fetchurl,
}:

applyPatches (final: {
  pname = "ceph-src";
  version = "20.2.4";

  src = fetchurl {
    url = "https://download.ceph.com/tarballs/ceph-${final.version}.tar.gz";
    hash = "sha256-XzRWkkGiiQRGuTHwbNhE+TvKZl90CiBjFCnS1Vsemzc=";
  };

  patches = [
    # required to be able to compile s3select against nixpkgs' arrow-cpp
    # See: https://github.com/ceph/s3select/pull/169
    (fetchpatch2 {
      name = "ceph-s3select-arrow-cpp-20.patch";
      url = "https://github.com/ceph/s3select/pull/169.diff?full_index=1";
      extraPrefix = "src/s3select/";
      stripLen = 1;
      hash = "sha256-0jn5X4jIdluCufFXWHeO6skMz6XQpliHkC1tPLK6dbk=";
    })
    # arrow-cpp 24 dropped the `arrow/util/span.h` header and switched its
    # parquet encryption API from `arrow::util::span` to `std::span`.
    # Must be applied on top of the s3select patch above, which introduces the
    # vendored headers this touches.
    ./patches/0002-s3select-std-span.patch
    # fixes issues when python3 is not on the PATH
    # See: https://github.com/ceph/ceph/pull/67904
    ./patches/0001-mgr-python-interpreter.patch
    # fixes compilation on the gcc version present in nixos-unstable
    # See: https://github.com/ceph/ceph/pull/67081
    # Source: https://aur.archlinux.org/cgit/aur.git/tree/ceph-20.2.1-backport-gcc16-fixes.patch?h=ceph&id=b158fda8a3e3834a7aa362954dc17077dc46f609#n4998
    ./patches/0003-compiler-compat-67081.patch
    # GCC 16: radosgw fails to link with an undefined reference to
    # `RGWSwiftWebsiteHandler::error_handler`.
    # See: https://github.com/ceph/ceph/pull/69166
    (fetchpatch2 {
      name = "ceph-rgw-swift-error_handler-out-of-line.patch";
      url = "https://github.com/ceph/ceph/commit/868fdd8120790ef453692604fff910e29c56cee1.patch?full_index=1";
      hash = "sha256-yaqOrmw0ZItT2efzNfpDqjTRsva8VN0R+TLqbTX0snc=";
    })
  ];
})
