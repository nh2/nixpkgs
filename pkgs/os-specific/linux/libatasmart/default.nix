{ stdenv, fetchurl, pkgconfig, buildPackages
, udev
, eudev
, enableSystemd ? (!stdenv.hostPlatform.isMusl) # systemd does not build with musl
}:

stdenv.mkDerivation rec {
  name = "libatasmart-0.19";

  src = fetchurl {
    url = "http://0pointer.de/public/${name}.tar.xz";
    sha256 = "138gvgdwk6h4ljrjsr09pxk1nrki4b155hqdzyr8mlk3bwsfmw31";
  };

  depsBuildBuild = [ buildPackages.stdenv.cc ];
  nativeBuildInputs = [ pkgconfig ];
  buildInputs = [
    (if enableSystemd then udev else eudev)
  ];

  meta = with stdenv.lib; {
    homepage = http://0pointer.de/blog/projects/being-smart.html;
    description = "Library for querying ATA SMART status";
    license = licenses.lgpl21;
    platforms = platforms.linux;
  };
}
