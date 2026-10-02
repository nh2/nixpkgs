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
    # There is no commit/PR/diff which can be easily fetchpatch'd so this requires vendoring.
    # See: https://github.com/ceph/ceph/pull/67081
    ./patches/0003-gcc16-cstdint.patch
    # GCC 16: `make_message` calls in the MDS are ambiguous between
    # `ceph::make_message` and `crimson::make_message`.
    # Part of https://github.com/ceph/ceph/pull/67081
    (fetchpatch2 {
      name = "ceph-mds-qualify-make_message.patch";
      url = "https://github.com/ceph/ceph/commit/ea218daf73965fdaee54693bbfcd675c031992f9.patch?full_index=1";
      hash = "sha256-Ti03FlvW74uZITbpb7JGlyZAdF6QH3b0tjNs6G3gVuA=";
    })
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
