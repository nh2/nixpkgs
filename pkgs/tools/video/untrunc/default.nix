{ stdenv, gcc, ffmpeg, libui, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "untrunc";
  version = "2018.01.13";

  src = fetchFromGitHub {
    owner = "anthwlock";
    repo = "untrunc";
    rev = "d6f0790d7b6f757eb846fe1f64c7a2da9a72c2ae";
    sha256 = "0ncdn66a491a3vgjkp96sc5h4qyd8p7cbx1mminrl2742l45w70k";
  };

  buildInputs = [ gcc ffmpeg libui ];

  makeFlags = [
    "untrunc"
    # "untrunc-gui"
    "-j4"
  ];

  installPhase = ''
    mkdir -p "$out/bin"
    # cp untrunc untrunc-gui "$out/bin"
    cp untrunc "$out/bin"
  '';

  meta = with stdenv.lib; {
    description = "Restore a damaged (truncated) mp4, m4v, mov, 3gp video. Provided you have a similar not broken video";
    license = licenses.gpl2;
    homepage = "https://github.com/anthwlock/untrunc";
    maintainers = [ maintainers.earvstedt ];
  };
}
