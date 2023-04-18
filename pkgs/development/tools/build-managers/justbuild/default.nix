{ stdenv
, fetchFromGitHub

, fmt_9
, nlohmann_json
, cli11
, gsl-lite
, libgit2
, openssl


, pkg-config
# , clang
, clang_15
# , llvmPackages
, python3
, unzip
, zip
, wget
, lib
, jq
, breakpointHook

, useClang ? false
} :

stdenv.mkDerivation rec {
  pname = "justbuild";
  version = "1.0.0-master";

  # src = lib.cleanSource /home/niklas/src/justbuild; # TODO: Remove

  src = fetchFromGitHub {
    owner = "just-buildsystem";
    repo = "justbuild";
    # rev = "v${version}";
    rev = "d078dced9183e80786d8b3624fb0b9c3c459b55a";
    sha256 = "sha256:03h297lq63412kmxvpkrf3l68fbcnc30p010g3fs7ia90axrjdr9";
  };

  nativeBuildInputs = [
    # breakpointHook
    python3
    unzip
    jq
    wget

    pkg-config

    cli11
    fmt_9
    gsl-lite
    nlohmann_json
  ] ++ lib.optional useClang clang_15;

  buildInputs = [
    libgit2
    openssl
  ];

  postPatch = ''
    sed -ie 's|\./bin/just-mr.py|${python3}/bin/python3 ./bin/just-mr.py|' bin/bootstrap.py
    sed -ie 's|#!/usr/bin/env python3|#!${python3}/bin/python3|' bin/parallel-bootstrap-traverser.py
  '';

  # TODO: Remove this hack.
  #       Find out why these flags are necessary in the first place.
  NIX_CFLAGS_COMPILE = "-Dgsl_CONFIG_DEFAULTS_VERSION=1 -Dgsl_CONFIG_NOT_NULL_EXPLICIT_CTOR=0 -Dgsl_CONFIG_TRANSPARENT_NOT_NULL=0";

  buildPhase = ''
    runHook preBuild

    export PACKAGE=YES
    export JUST_BUILD_CONF=`echo $PATH | jq -R '{ ENV: { PATH: . }, "COMPILER_FAMILY": "${if useClang then "clang" else "gnu"}" }'`

    python3 ./bin/bootstrap.py

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    find .
    # TODO: Copy results to $out

    runHook postInstall
  '';

  meta = with lib; {
    description = " just, a generic build tool ";
    homepage = "https://github.com/just-buildsystem/justbuild";
    license = licenses.asl20;
    maintainers = with maintainers; [ clkamp ];
  };
}
