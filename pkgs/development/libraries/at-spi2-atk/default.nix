{ stdenv
, fetchurl

, meson
, ninja
, pkgconfig

, at-spi2-core
, atk
, dbus
, glib
, libxml2

, gnome3 # To pass updateScript
}:

stdenv.mkDerivation rec {
  pname = "at-spi2-atk";
  version = "2.34.0";

  src = fetchurl {
    url = "mirror://gnome/sources/${pname}/${stdenv.lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "00250s72ii8w6lb6ww61v49y9k4cswfj0hhawqlram7bl6b7x6is";
  };

  nativeBuildInputs = [ meson ninja pkgconfig ];
  buildInputs = [ at-spi2-core atk dbus glib libxml2 ];

  # TODO: Remove when https://github.com/GNOME/at-spi2-atk/pull/1 is available
  postPatch = ''
    substituteInPlace atk-adaptor/meson.build --replace 'shared_library' 'library'
  '';

  # For unknown reason, the package does not install `.a` files in subdirectories
  # to `lib`, but generates `atk-bridge-2.0.pc` containing
  # `-l` flags fro them, so we copy them file manually.
  postInstall = ''
    cp ./atk-adaptor/adaptors/libatk-bridge-adaptors.a $out/lib/libatk-bridge-adaptors.a
    cp ./droute/libdroute.a $out/lib/libdroute.a
  '';

  doCheck = false; # fails with "No test data file provided"

  passthru = {
    updateScript = gnome3.updateScript {
      packageName = pname;
    };
  };

  meta = with stdenv.lib; {
    description = "D-Bus bridge for Assistive Technology Service Provider Interface (AT-SPI) and Accessibility Toolkit (ATK)";
    homepage = https://gitlab.gnome.org/GNOME/at-spi2-atk;
    license = licenses.lgpl21Plus;
    maintainers = gnome3.maintainers;
    platforms = platforms.unix;
  };
}
