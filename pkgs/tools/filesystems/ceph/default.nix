{ stdenv, fetchurl, cmake, pkgconfig, makeWrapper
, python2
, python2Packages
, cunit
, lz4
, oathToolkit
, libuuid
, udev, libaio, utillinux, keyutils, fuse, libxfs
, leveldb, snappy, curl
, nss
, ncurses
, expat, boost, gperftools, gperf, yasm, libibverbs, kmod, cryptsetup, lvm2, coreutils
}:

let
  version = "13.2.0";
  ceph-unwrapped = stdenv.mkDerivation {
    name = "ceph-unwrapped-${version}";

    src = fetchurl {
      url = "https://download.ceph.com/tarballs/ceph_${version}.orig.tar.gz";
      sha256 = "0sdqzplpkha8jac00n4w1m9x7yyy3rzw1lh4dadhcz7xg91f1ays";
    };

    buildInputs = [
      udev
      libaio
      utillinux
      keyutils

      libuuid
      lz4
      leveldb
      snappy
      curl
      nss
      ncurses
      expat
      boost
      gperftools
      gperf
      fuse
      libxfs
      libibverbs
      oathToolkit
    ];

    nativeBuildInputs = [
      cmake
      cunit
      python2Packages.sphinx
      python2Packages.cython
      python2Packages.virtualenv
      python2Packages.pip
      yasm
      pkgconfig
      makeWrapper
    ];

    patches = [
      # TODO: remove when https://github.com/ceph/ceph/pull/21289 is merged
      ./ceph-volume-allow-loop.patch
      # TODO: remove when https://github.com/ceph/ceph/pull/20938 is merged
      ./dont-hardcode-bin-paths.patch
    ];

    preConfigure = ''
      pushd systemd
      # Checking systemd units are unchanged:
      echo "Actual systemd file hashes:"
      sha256sum *.target *.service *.service.in | tee actual-systemd-hashes
      echo "Diff of actual systemd file hashes with expected ones:"
      diff -u ${./expected-systemd-hashes} actual-systemd-hashes
      if [ $? != 0 ]; then
        echo "Ceph's systemd files have changed. Please ensure that the corresponding units in ceph.nix of the ceph NixOS service are up to date, and bump ./expected-systemd-hashes."
        exit 1
      fi
      popd

      patchShebangs .
    '';

    # Flags from https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=ceph-git#n142
    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
      "-DWITH_SYSTEM_BOOST=ON"
      "-DWITH_SYSTEMD=OFF" # We need to make custom Nix units anyway
      "-DWITH_EMBEDDED=OFF"
      "-DWITH_OPENLDAP=OFF"
      "-DWITH_LTTNG=OFF"
      "-DWITH_BABELTRACE=OFF"
      "-DWITH_TESTS=OFF"

      # Can't build this for now because we get a build error from it:
      #     Traceback (most recent call last):
      #      File "/tmp/nix-build-ceph-unwrapped-13.2.0.drv-7/ceph-13.2.0/build/src/pybind/mgr/dashboard/node-env/bin/pip", line 7, in <module>
      #        from pip._internal import main
      #     ModuleNotFoundError: No module named 'pip._internal'
      "-DWITH_MGR_DASHBOARD_FRONTEND=OFF"
      # Can't build this for now because the vendored `spdk` build complains:
      #     /tmp/nix-build-ceph-unwrapped-13.2.0.drv-1/ceph-13.2.0/src/spdk/include/spdk_internal/lvolstore.h:41:10: fatal error: uuid/uuid.h: No such file or directory
      # We haven't figured out yet what's the problem here.
      "-DWITH_SPDK=OFF"
      "-DXFS_INCLUDE_DIR=${libxfs}/include"
    ];

    # Set the LD_LIBRARY_PATH, otherwise Cython can't find the ceph libraries during compilation
    # We also need to include our install dir in PYTHONPATH otherwise pip will refuse to install ceph-disk.
    preBuild = ''
      export LD_LIBRARY_PATH=$PWD/lib:$LD_LIBRARY_PATH
      export PYTHONPATH=$(toPythonPath $out):$PYTHONPATH
    '';

    enableParallelBuilding = true;
  };

# do the binary wrapping in a separate derivation so that we don't need to rebuild ceph if only this changes
in
let
  pythonEnv = python2.withPackages (pkgs: with pkgs; [
      python
      flask
      prettytable
      requests
      cherrypy
      jinja2
      pecan
      pyopenssl
      setuptools
      werkzeug
      Mako
    ]);
in
stdenv.mkDerivation {
  name = "ceph-${version}";

  buildInputs = [ ceph-unwrapped ];
  nativeBuildInputs = [ makeWrapper python2Packages.python ];

  buildCommand = let
    extraPythonPaths = with python2Packages;
      map
        (path: "$(toPythonPath ${path})")
        [ "$out"
          # Python dependencies from: https://git.archlinux.org/svntogit/community.git/tree/trunk/PKGBUILD?h=packages/ceph#n142
       ];
    in ''
      set -eo pipefail
      cp -rvs ${ceph-unwrapped} --no-preserve=mode $out

      # for some reason easy_install ends up in the bin dir
      rm -v $out/bin/easy_install*

      # Some executables in `bin` call out to Python; wrap them all with PYTHONPATH so that this works.
      for script in $out/bin/*; do
        echo "Adding Python paths to $script"
        wrapProgram $script --suffix-each PYTHONPATH : "$(toPythonPath $out):$(toPythonPath ${pythonEnv})" \
          --suffix PATH : "$out/bin"
      done

      wrapProgram $out/bin/mount.ceph --suffix PATH : ${kmod}/bin
      wrapProgram $out/bin/ceph-volume --suffix PATH : "${lvm2}/bin:${utillinux}/bin:${coreutils}/bin:${cryptsetup}/bin"
  '';
}
