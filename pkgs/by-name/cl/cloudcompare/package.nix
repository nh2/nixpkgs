{
  lib,
  stdenv,
  fetchFromGitHub,
  makeDesktopItem,
  copyDesktopItems,
  cmake,
  pkg-config,
  boost,
  cgal,
  eigen,
  flann,
  gdal,
  gmp,
  laszip,
  libusb1,
  mpfr,
  pcl,
  qt6,
  onetbb,
  xercesc,
  wrapGAppsHook3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cloudcompare";
  version = "2.13.2-unstable-2026-07-22";

  src = fetchFromGitHub {
    owner = "CloudCompare";
    repo = "CloudCompare";
    # TODO: Switch back to a release tag once one in includes this ref.
    rev = "d2edaad207ea34990aae268d74c52b94c66b2ee6";
    hash = "sha256-4GMzEhMgsWQ1wJSIeFQWGoZ9ughq9JoU09B9Wf+h9RM=";
    fetchSubmodules = true;
  };

  # CloudCompare's 3DConnexion (3D mouse) support compiles a bundled `hidapi` Git
  # submodule and installs its `libhidapi-hidraw.so.0` into
  # `CLOUDCOMPARE_DEST_FOLDER`, which on Linux is `bin`, that is, next to the
  # executable. That works on Windows/macOS, where libraries next to the
  # executable are found automatically, but not on NixOS, where there is no such
  # implicit lookup, so CloudCompare fails to start with:
  #     error while loading shared libraries: libhidapi-hidraw.so.0
  #
  # Install it into `LINUX_INSTALL_SHARED_DESTINATION` (`$out/lib/cloudcompare`)
  # instead, which upstream already assigns to `CMAKE_INSTALL_RPATH` for exactly
  # this purpose (it is where CloudCompare's own shared libs go).
  #
  # Note it's also possible to use nixkpgs's `hidapi` entirely,
  # but the required CMake patching is larger.
  #
  # The PhotoScan plugin has a similar problem with its bundled `quazip`,
  # which it adds via `add_subdirectory( extern/quazip EXCLUDE_FROM_ALL )`.
  # `EXCLUDE_FROM_ALL` makes CMake ignore that subdirectory's `install()` rules,
  # while `quazip` defaults to `BUILD_SHARED_LIBS=ON`, so its
  # `libquazip1-qt6.so.1.5.0` is linked but never installed and the plugin fails
  # to load at runtime with:
  #     libQPHOTOSCAN_IO_PLUGIN.so does not seem to be a valid plugin
  #     (... libquazip1-qt6.so.1.5.0: cannot open shared object file)
  # So we build that `quazip` statically instead, so it is linked into the plugin
  # and needs no install rule. This works because CloudCompare sets
  # `CMAKE_POSITION_INDEPENDENT_CODE ON` globally.
  # Note we set `BUILD_SHARED_LIBS` only around that `add_subdirectory` instead of
  # passing it in `cmakeFlags`, because as a global variable it would also make
  # the bundled `hidapi` static, which would break the `install()` patched above.
  postPatch = ''
    substituteInPlace libs/CCAppCommon/devices/3dConnexion/CMakeLists.txt \
      --replace-fail \
        'install( FILES ''${HIDAPI_LIB} DESTINATION ''${CLOUDCOMPARE_DEST_FOLDER} RENAME "libhidapi-hidraw.so.0")' \
        'install( FILES ''${HIDAPI_LIB} DESTINATION ''${LINUX_INSTALL_SHARED_DESTINATION} RENAME "libhidapi-hidraw.so.0")'

    substituteInPlace plugins/core/IO/qPhotoscanIO/CMakeLists.txt \
      --replace-fail \
        'add_subdirectory( extern/quazip EXCLUDE_FROM_ALL )' \
        'set( BUILD_SHARED_LIBS OFF )
 add_subdirectory( extern/quazip EXCLUDE_FROM_ALL )
 unset( BUILD_SHARED_LIBS )'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config # required by some plugins' `find_package(PkgConfig REQUIRED)`
    eigen # header-only
    wrapGAppsHook3
    copyDesktopItems
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    boost
    cgal
    flann
    gdal
    gmp
    laszip
    libusb1 # for the bundled `hidapi` of the 3DConnexion (3D mouse) support
    mpfr
    pcl
    qt6.qtbase
    qt6.qtsvg
    qt6.qttools
    onetbb
    xercesc
  ];

  cmakeFlags = [
    "-DCCCORELIB_USE_TBB=ON"
    "-DOPTION_USE_DXF_LIB=ON"
    "-DOPTION_USE_GDAL=ON"
    "-DOPTION_USE_SHAPE_LIB=ON"

    "-DPLUGIN_GL_QEDL=ON"
    "-DPLUGIN_GL_QSSAO=ON"

    "-DPLUGIN_IO_QADDITIONAL=ON"
    "-DPLUGIN_IO_QCORE=ON"
    "-DPLUGIN_IO_QCSV_MATRIX=ON"
    "-DPLUGIN_IO_QE57=ON"
    "-DPLUGIN_IO_QFBX=OFF" # Autodesk FBX SDK is gratis+proprietary; not packaged in nixpkgs
    "-DPLUGIN_IO_QLAS=ON" # required for .las/.laz support
    "-DLASZIP_INCLUDE_DIR=${lib.getInclude laszip}/include/laszip"
    "-DPLUGIN_IO_QPHOTOSCAN=ON"
    "-DPLUGIN_IO_QRDB=OFF" # Riegl rdblib is proprietary; not packaged in nixpkgs

    "-DCCCORELIB_USE_CGAL=ON" # enables Delauney triangulation support
    "-DPLUGIN_STANDARD_QPCL=ON" # Adds PCD import and export support
    "-DPLUGIN_STANDARD_QANIMATION=ON"
    "-DPLUGIN_STANDARD_QBROOM=ON"
    "-DPLUGIN_STANDARD_QCANUPO=ON"
    "-DPLUGIN_STANDARD_QCOMPASS=ON"
    "-DPLUGIN_STANDARD_QCSF=ON"
    "-DPLUGIN_STANDARD_QFACETS=ON"
    "-DPLUGIN_STANDARD_QHOUGH_NORMALS=ON"
    "-DEIGEN_ROOT_DIR=${eigen}/include/eigen3" # needed for hough normals
    "-DPLUGIN_STANDARD_QHPR=ON"
    "-DPLUGIN_STANDARD_QM3C2=ON"
    "-DPLUGIN_STANDARD_QMPLANE=ON"
    "-DPLUGIN_STANDARD_QPOISSON_RECON=ON"
    "-DPLUGIN_STANDARD_QRANSAC_SD=OFF" # not compatible with GPL, broken on non-x86
    "-DPLUGIN_STANDARD_QSRA=ON"
    "-DPLUGIN_STANDARD_QCLOUDLAYERS=ON"
    # Fix the build with CMake 4, by overriding the minimum version globally, as support for < 3.5 was removed
    # Ideally this can be removed at some time, but there are a lot of dependencies (e.g. plugins) which have a lower minimum version configured.
    (lib.strings.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
  ];

  dontWrapGApps = true;

  postInstall = ''
    install -Dm444 $src/qCC/images/icon/cc_icon_16.png $out/share/icons/hicolor/16x16/apps/CloudCompare.png
    install -Dm444 $src/qCC/images/icon/cc_icon_32.png $out/share/icons/hicolor/32x32/apps/CloudCompare.png
    install -Dm444 $src/qCC/images/icon/cc_icon_64.png $out/share/icons/hicolor/64x64/apps/CloudCompare.png
    install -Dm444 $src/qCC/images/icon/cc_icon_256.png $out/share/icons/hicolor/256x256/apps/CloudCompare.png

    install -Dm444 $src/qCC/images/icon/cc_viewer_icon_16.png $out/share/icons/hicolor/16x16/apps/ccViewer.png
    install -Dm444 $src/qCC/images/icon/cc_viewer_icon_32.png $out/share/icons/hicolor/32x32/apps/ccViewer.png
    install -Dm444 $src/qCC/images/icon/cc_viewer_icon_64.png $out/share/icons/hicolor/64x64/apps/ccViewer.png
    install -Dm444 $src/qCC/images/icon/cc_viewer_icon_256.png $out/share/icons/hicolor/256x256/apps/ccViewer.png
  '';

  # fix file dialogs crashing on non-NixOS (and avoid double wrapping)
  preFixup = ''
    qtWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "CloudCompare";
      desktopName = "CloudCompare";
      comment = "3D point cloud and mesh processing software";
      exec = "CloudCompare";
      terminal = false;
      categories = [
        "Graphics"
        "3DGraphics"
        "Viewer"
      ];
      keywords = [
        "3d"
        "processing"
      ];
      icon = "CloudCompare";
    })
    (makeDesktopItem {
      name = "ccViewer";
      desktopName = "CloudCompare Viewer";
      comment = "3D point cloud and mesh processing software";
      exec = "ccViewer";
      terminal = false;
      categories = [
        "Graphics"
        "3DGraphics"
        "Viewer"
      ];
      keywords = [
        "3d"
        "viewer"
      ];
      icon = "ccViewer";
    })
  ];

  meta = {
    description = "3D point cloud and mesh processing software";
    homepage = "https://cloudcompare.org";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [ nh2 ];
    mainProgram = "CloudCompare";
    platforms = with lib.platforms; linux; # only tested here; might work on others
  };
})
