{ stdenv, fetchurl, llvmPackages_7_zapcc, clangStdenv }:

(llvmPackages_7_zapcc.stdenv).mkDerivation rec {
  pname = "hello";
  version = "2.10";

  src = fetchurl {
    url = "mirror://gnu/hello/${pname}-${version}.tar.gz";
    sha256 = "0ssi1wpaf7plaswqqjwigppsg5fyh99vdlb9kzl7c9lng89ndq1i";
  };

  preConfigure = ''
    echo '#include <stddef.h>' >> test.c
    echo 'int main(int argc, char const *argv[]) { puts("hello world"); return 0; }' >> test.c

    type clang

    clang test.c

    ls -lah a.out
    ./a.out
  '';

  doCheck = true;

  meta = with stdenv.lib; {
    description = "A program that produces a familiar, friendly greeting";
    longDescription = ''
      GNU Hello is a program that prints "Hello, world!" when you run it.
      It is fully customizable.
    '';
    homepage = https://www.gnu.org/software/hello/manual/;
    changelog = "https://git.savannah.gnu.org/cgit/hello.git/plain/NEWS?h=v${version}";
    license = licenses.gpl3Plus;
    maintainers = [ maintainers.eelco ];
    platforms = platforms.all;
  };
}
