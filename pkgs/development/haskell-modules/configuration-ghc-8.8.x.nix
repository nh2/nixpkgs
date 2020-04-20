{ pkgs, haskellLib }:

with haskellLib;

self: super: {

  # This compiler version needs llvm 7.x.
  llvmPackages = pkgs.llvmPackages_7;

  # Disable GHC 8.8.x core libraries.
  array = null;
  base = null;
  binary = null;
  bytestring = null;
  Cabal = null;
  containers = null;
  deepseq = null;
  directory = null;
  filepath = null;
  ghc-boot = null;
  ghc-boot-th = null;
  ghc-compact = null;
  ghc-heap = null;
  ghc-prim = null;
  ghci = null;
  haskeline = null;
  hpc = null;
  integer-gmp = null;
  libiserv = null;
  mtl = null;
  parsec = null;
  pretty = null;
  process = null;
  rts = null;
  stm = null;
  template-haskell = null;
  terminfo = null;
  text = null;
  time = null;
  transformers = null;
  unix = null;
  xhtml = null;

  # These builds need Cabal 3.2.x.
  cabal2spec = super.cabal2spec.override { Cabal = self.Cabal_3_2_0_0; };
  cabal-install = super.cabal-install.overrideScope (self: super: { Cabal = self.Cabal_3_2_0_0; });

  # Ignore overly restrictive upper version bounds.
  aeson-diff = doJailbreak super.aeson-diff;
  async = doJailbreak super.async;
  ChasingBottoms = doJailbreak super.ChasingBottoms;
  chell = doJailbreak super.chell;
  cryptohash-sha256 = doJailbreak super.cryptohash-sha256;
  Diff = dontCheck super.Diff;
  doctest = doJailbreak super.doctest;
  hashable = doJailbreak super.hashable;
  hashable-time = doJailbreak super.hashable-time;
  hledger-lib = doJailbreak super.hledger-lib;  # base >=4.8 && <4.13, easytest >=0.2.1 && <0.3
  integer-logarithms = doJailbreak super.integer-logarithms;
  lucid = doJailbreak super.lucid;
  parallel = doJailbreak super.parallel;
  quickcheck-instances = doJailbreak super.quickcheck-instances;
  setlocale = doJailbreak super.setlocale;
  split = doJailbreak super.split;
  system-fileio = doJailbreak super.system-fileio;
  tasty-expected-failure = doJailbreak super.tasty-expected-failure;
  tasty-hedgehog = doJailbreak super.tasty-hedgehog;
  test-framework = doJailbreak super.test-framework;
  th-expand-syns = doJailbreak super.th-expand-syns;
  # TODO: remove when upstream accepts https://github.com/snapframework/io-streams-haproxy/pull/17
  io-streams-haproxy = doJailbreak super.io-streams-haproxy; # base >=4.5 && <4.13
  snap-server = doJailbreak super.snap-server;
  xmobar = doJailbreak super.xmobar;
  exact-pi = doJailbreak super.exact-pi;
  time-compat = doJailbreak super.time-compat;
  http-media = doJailbreak super.http-media;
  servant-server = doJailbreak super.servant-server;
  foundation = dontCheck super.foundation;
  vault = dontHaddock super.vault;

  # https://github.com/snapframework/snap-core/issues/288
  snap-core = overrideCabal super.snap-core (drv: { prePatch = "substituteInPlace src/Snap/Internal/Core.hs --replace 'fail   = Fail.fail' ''"; });

  # Upstream ships a broken Setup.hs file.
  csv = overrideCabal super.csv (drv: { prePatch = "rm Setup.hs"; });

  # https://github.com/kowainik/relude/issues/241
  relude = dontCheck super.relude;

  # The tests for semver-range need to be updated for the MonadFail change in
  # ghc-8.8:
  # https://github.com/adnelson/semver-range/issues/15
  semver-range = dontCheck super.semver-range;

  # The current version 2.14.2 does not compile with ghc-8.8.x or newer because
  # of issues with Cabal 3.x.
  darcs = dontDistribute super.darcs;

  # Only 0.7 is compatible with ghc 8.7 https://hackage.haskell.org/package/apply-refact/changelog
  apply-refact = super.apply-refact_0_7_0_0;

  pantry_0_2_0_0 = appendPatches (dontCheck super.pantry_0_2_0_0) [
    # pantry-0.2.0.0 doesn't build with ghc-8.8, but there is a PR adding support.
    # https://github.com/commercialhaskell/pantry/pull/6
    # Currently stack-2.1.3.1 requires pantry-0.2.0.0, but when a newer version of
    # stack is released, it will probably use the newer pantry version, so we
    # can completely get rid of pantry-0.2.0.0.
    (pkgs.fetchpatch {
      url = "https://github.com/commercialhaskell/pantry/pull/6.diff";
      sha256 = "0aml06jshpjh3aiscs5av7y33m3d6s6x5pzdvh7pky476izfg87k";
      excludes = [
        ".azure/azure-linux-template.yml"
        ".azure/azure-osx-template.yml"
        ".azure/azure-windows-template.yml"
        "package.yaml"
        "pantry.cabal"
        "stack-lts-11.yaml"
        "stack-lts-12.yaml"
        "stack-nightly.yaml"
        "stack-windows.yaml"
        "stack.yaml"
      ];
    })
  ];

}
