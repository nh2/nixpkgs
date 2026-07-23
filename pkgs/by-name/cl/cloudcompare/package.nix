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
  hidapi,
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

  # CloudCompare's 3DConnexion (3D mouse) support otherwise compiles a bundled
  # `hidapi` Git submodule and installs its `libhidapi-hidraw.so.0` next to the
  # executable, where it is not found at runtime (it is not on the RPATH).
  # We could move it to `lib/` so it's found, but nixpkgs has a general
  # desire to use its own packages unless an upstream software really
  # benefits from using its bundled ones.
  # So Instead, make it use nixpkgs' `hidapi`, which is API-compatible (CloudCompare
  # only uses long-stable hidapi functions).
  #
  # Unfortunately, the way CloudCompare's CMake is written, that isn't
  # as easy as it could be: By providing the `hidapi::hidapi`
  # CMake target via `find_package`; this makes CloudCompare's own
  # `if( NOT TARGET hidapi::hidapi )` guard skip building the submodule.
  # The manual install of the submodule's `.so` is dropped accordingly.
  # `GLOBAL` is required because imported targets created by `find_package` are
  # otherwise only visible in the directory that created them, whereas this
  # subdirectory links `hidapi` into the `CCAppCommon` target that is defined in
  # its parent directory. That cross-directory linking is also why the file sets
  # CMake policy `CMP0079` ("`target_link_libraries()` allows use with targets in
  # other directories").
  # Note that the search patterns below deliberately carry no leading
  # indentation, because that file indents with tabs.
  #
  # If we find this to complex to maintain, moving CloudCompare's `.so` to `lib/`
  # is probably the next best option.
  postPatch = ''
    substituteInPlace libs/CCAppCommon/devices/3dConnexion/CMakeLists.txt \
      --replace-fail \
        'if( NOT TARGET hidapi::hidapi )' \
        'find_package( hidapi REQUIRED GLOBAL )
        if( NOT TARGET hidapi::hidapi )' \
      --replace-fail \
        'set( HIDAPI_LIB ''${HIDAPI_BINARY_DIR}/src/linux/libhidapi-hidraw.so.0.16.0 )' \
        '# hidapi comes from nixpkgs (see `postPatch`); nothing to install.' \
      --replace-fail \
        'install( FILES ''${HIDAPI_LIB} DESTINATION ''${CLOUDCOMPARE_DEST_FOLDER} RENAME "libhidapi-hidraw.so.0")' \
        '# hidapi comes from nixpkgs (see `postPatch`); nothing to install.'
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
    hidapi # for the 3DConnexion (3D mouse) device support; see `postPatch`
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
