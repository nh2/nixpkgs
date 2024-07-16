{
  lib,
  buildPythonPackage,
  fetchPypi,
  requests,
  pytest,
}:

buildPythonPackage rec {
  pname = "py-consul";
  version = "1.5.1";
  format = "setuptools";

  src = fetchPypi {
    pname = "py_consul";
    inherit version;
    sha256 = "sha256-5nuBqEt9S640KX7K+C4GTdoyhq6nhNpDBVrUTO+EGK8=";
  };

  buildInputs = [
    requests
    pytest
  ];

  # Tests are now distributed (the original package doesn't, see
  # https://github.com/cablehead/python-consul/issues/133). But these tests
  # still require a running consul service, so we disable checks.
  doCheck = false;

  meta = {
    description = "Python client for Consul (https://www.consul.io/)";
    homepage = "https://github.com/criteo/py-consul";
    license = lib.licenses.mit;
  };
}
