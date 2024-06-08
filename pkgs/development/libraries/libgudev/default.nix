{ stdenv
, fetchurl
, pkgconfig
, udev
, eudev
, glib
, gobject-introspection
, gnome3
, enableSystemd ? (!stdenv.hostPlatform.isMusl) # systemd does not build with musl
}:

stdenv.mkDerivation rec {
  pname = "libgudev";
  version = "233";

  outputs = [ "out" "dev" ];

  src = fetchurl {
    url = "mirror://gnome/sources/${pname}/${stdenv.lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "00xvva04lgqamhnf277lg32phjn971wgpc9cxvgf5x13xdq4jz2q";
  };

  nativeBuildInputs = [ pkgconfig gobject-introspection ];
  buildInputs = [
    (if enableSystemd then udev else eudev)
    glib
  ];

  # There's a dependency cycle with umockdev and the tests fail to LD_PRELOAD anyway.
  configureFlags = [ "--disable-umockdev" ];

  passthru = {
    updateScript = gnome3.updateScript {
      packageName = pname;
      versionPolicy = "none";
    };
  };

  meta = with stdenv.lib; {
    homepage = https://wiki.gnome.org/Projects/libgudev;
    maintainers = [ maintainers.eelco ] ++ gnome3.maintainers;
    platforms = platforms.linux;
    license = licenses.lgpl2Plus;
  };
}
