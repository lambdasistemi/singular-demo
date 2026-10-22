# What the pay-by-name scenario builds with Nix: the sink validator (its unit tests and its compiled blueprint, and a variant
# for the tests) and the tools that apply it, bundled into single files that run with the machine's own node.
# Nothing is fetched while building except by hash: the Aiken standard library and the npm packages.
{ pkgs }:
let
  # The Aiken standard library the validator is written against. Aiken does not fetch it in the sandbox; it is put
  # where Aiken looks for packages (build/packages), as the Singular project does for its own validators.
  stdlib = pkgs.fetchFromGitHub {
    owner = "aiken-lang";
    repo = "stdlib";
    rev = "v2.2.0";
    hash = "sha256-BDaM+JdswlPasHsI03rLl4OR7u5HsbAd3/VFaoiDTh4=";
  };
  packagesToml = pkgs.writeText "packages.toml" ''
    [[packages]]
    name = "aiken-lang/stdlib"
    version = "v2.2.0"
    source = "github"
  '';
  stage = ''
    export HOME=$TMPDIR
    mkdir -p build/packages
    cp ${packagesToml} build/packages/packages.toml
    cp -r ${stdlib} build/packages/aiken-lang-stdlib
    chmod -R u+w build
  '';
  onchain = pkgs.lib.cleanSource ./onchain;

  # The blueprint of the validator, with the labels of its checks kept in the script (the default build leaves them out).
  # `patch` changes the source first: the variant without check 6 is made that way.
  blueprint =
    {
      name,
      patch ? "",
    }:
    pkgs.stdenv.mkDerivation {
      inherit name;
      src = onchain;
      nativeBuildInputs = [ pkgs.aiken ];
      dontConfigure = true;
      buildPhase = ''
        ${stage}
        ${patch}
        aiken build -t verbose
      '';
      installPhase = ''
        cp plutus.json $out
      '';
    };

  sink = blueprint { name = "pay-by-name-sink-blueprint"; };

  # Only the tests use this one: the same validator without check 6, to show that the check is not vacuous.
  variant = blueprint {
    name = "pay-by-name-sink-variant-blueprint";
    patch = ''
      substituteInPlace validators/sink.ak \
        --replace-fail 'Script(_) -> fail @"sink-foreign-script"' 'Script(_) -> acc'
    '';
  };

  # The unit tests of the validator, among them the ones that show each label.
  aikenCheck =
    pkgs.runCommand "pay-by-name-aiken-check"
      {
        src = onchain;
        nativeBuildInputs = [ pkgs.aiken ];
      }
      ''
        cp -r $src onchain
        chmod -R u+w onchain
        cd onchain
        ${stage}
        aiken check
        touch $out
      '';

  # sink-tools.cjs (the tools of the story) and controls.cjs (the controls that only the tests run): each one file,
  # with the compiled validator inside, that runs with `node` alone.
  tools = pkgs.buildNpmPackage {
    pname = "pay-by-name-tools";
    version = "0.0.0";
    src = pkgs.lib.cleanSource ./offchain;
    npmDepsHash = "sha256-zyKdFKB1j8+h/Wz6Uhs4MoeL/gblA1w2GN4TQpBpOmY=";
    npmFlags = [ "--ignore-scripts" ];
    nativeBuildInputs = [ pkgs.esbuild ];
    dontNpmBuild = true;
    dontNpmInstall = true;
    buildPhase = ''
      runHook preBuild
      # the three WebAssembly packages, with their bytes inside the script
      node inline-wasm.mjs node_modules wasm
      # the validators as text, where the tools look for them
      {
        printf 'export const embeddedSinkBlueprint = '
        node -p 'JSON.stringify(require("fs").readFileSync(process.argv[1], "utf8"))' ${sink}
        printf ';\nexport const embeddedVariantBlueprint = '
        node -p 'JSON.stringify(require("fs").readFileSync(process.argv[1], "utf8"))' ${variant}
        printf ';\n'
      } > embedded.mjs
      for entry in sink-tools controls; do
        esbuild $entry.mjs --bundle --platform=node --format=cjs --target=node18 --minify --legal-comments=none \
          --alias:@lucid-evolution/cml=$PWD/wasm/cml.cjs \
          --alias:@lucid-evolution/uplc=$PWD/wasm/uplc.cjs \
          --alias:@emurgo/cardano-message-signing-nodejs=$PWD/wasm/message-signing.cjs \
          --outfile=$entry.cjs
      done
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp sink-tools.cjs controls.cjs $out/
      runHook postInstall
    '';
  };
in
{
  inherit
    sink
    variant
    aikenCheck
    tools
    ;
}
