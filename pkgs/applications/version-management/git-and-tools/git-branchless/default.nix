{ lib, fetchFromGitHub

, coreutils
, git
, ncurses
, rustPlatform
, sqlite
}:

rustPlatform.buildRustPackage rec {
  pname = "git-branchless";
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "arxanas";
    repo = "git-branchless";
    rev = "v${version}";
    sha256 = "0pfiyb23ah1h6risrhjr8ky7b1k1f3yfc3z70s92q3czdlrk6k07";
  };

  cargoSha256 = "0gplx80xhpz8kwry7l4nv4rlj9z02jg0sgb6zy1y3vd9s2j5wals";

  buildInputs = [
    ncurses
    sqlite
  ];

  # Remove path hardcodes patching if they get fixed upstream, see:
  # https://github.com/arxanas/git-branchless/issues/26
  postPatch = ''
    # Inline test hardcodes `echo` location.
    sed -i -e "s|/bin/echo|${coreutils}/bin/echo|" ./src/commands/wrap.rs

    # Tests in general hardcode `git` location.
    sed -i -e "s|/usr/bin/git|${git}/bin/git|" ./src/testing.rs
  '';

  preCheck = ''
    # Tests require path to git.
    export PATH_TO_GIT=${git}/bin/git
  '';

  meta = with lib; {
    description = "A suite of tools to help you visualize, navigate, manipulate, and repair your commit history";
    homepage = "https://github.com/arxanas/git-branchless";
    license = licenses.asl20;
    maintainers = with maintainers; [ nh2 ];
  };
}
