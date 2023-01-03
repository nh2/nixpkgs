{ lib
, buildPythonPackage
, fetchFromGitHub
, python
, pythonOlder
, runCommand
, writeText

# Python dependencies:
, numpy
, matplotlib
, scipy
, pandas
, astropy
# , poliastro # future versions will require this
}:

buildPythonPackage rec {
  pname = "amat";
  version = "2.2.3c";

  src = fetchFromGitHub {
    owner = "athulpg007";
    repo = "AMAT";
    rev = "v${version}";
    sha256 = "sha256-0raTKNMER7MrfC+jR9jcIxauNCLOPui/MOUpJ+9sZNA=";
  };

  # Guessed from https://github.com/athulpg007/AMAT/blob/v2.2.3c/setup.py#L33
  disabled = pythonOlder "3.3";

  propagatedBuildInputs = [
    numpy
    matplotlib
    scipy
    pandas
    astropy
    # poliastro # future versions will require this
  ];

  postInstall = ''
    cp -r atmdata/ interplanetary-data/ "${placeholder "out"}/lib/${python.libPrefix}/site-packages/AMAT/"
  '';

  # AMAT's own tests have issues with loading data files from `../atmdata`.
  # This can probably be fixed by changing the working directory of the test runner.
  # Once that is done, replace `checkPhase` by `postCheck` below instead of overriding
  # the whole `checkPhase`.
  doCheck = true;

  checkPhase = ''
    runHook preCheck

    echo "Running import test:"
    PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH" ${python}/bin/python ${./amat-data-file-load-test.py}

    runHook postCheck
  '';

  meta = with lib; {
    description = "Rapid mission analysis for aerocapture mission concepts to the planetary science community";
    homepage = "https://github.com/athulpg007/AMAT";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ nh2 ];
  };
}
