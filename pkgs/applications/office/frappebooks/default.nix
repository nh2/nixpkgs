{ appimageTools, fetchurl, lib }:

let
  pname = "frappebooks";
  version = "0.0.3-beta.12";
in
appimageTools.wrapType2 rec {
  name = "${pname}-${version}-binary";

  src = fetchurl {
    url = "https://github.com/frappe/books/releases/download/v${version}/Frappe-Books-${version}.AppImage";
    sha256 = "05lmpdlfwpn222q5jm1fyib7zl4wdchibawsv7rk3jniyhkxb0lx";
  };

  profile = ''
    export LC_ALL=C.UTF-8
  '';

  multiPkgs = null; # no 32bit needed
  extraPkgs = p: (appimageTools.defaultFhsEnvArgs.multiPkgs p);

  # Strip version from binary name.
  extraInstallCommands = "mv $out/bin/${name} $out/bin/${pname}";

  meta = with lib; {
    description = "Free Desktop book-keeping software for small-businesses and freelancers.";
    homepage = "https://frappebooks.com";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
}
