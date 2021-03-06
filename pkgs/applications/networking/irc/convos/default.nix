{ stdenv, fetchFromGitHub, perl, perlPackages, makeWrapper, shortenPerlShebang }:

with stdenv.lib;

perlPackages.buildPerlPackage rec {
  pname = "convos";
  version = "4.22";

  src = fetchFromGitHub rec {
    owner = "Nordaaker";
    repo = pname;
    rev = version;
    sha256 = "0a5wq88ncbn7kwcw3z4wdl1wxmx5vq5a7crb1bvbvskgwwy8zfx8";
  };

  nativeBuildInputs = [ makeWrapper ]
    ++ optional stdenv.isDarwin [ shortenPerlShebang ];
  
  buildInputs = with perlPackages; [
    CryptEksblowfish FileHomeDir FileReadBackwards
    IOSocketSSL IRCUtils JSONValidator LinkEmbedder ModuleInstall
    Mojolicious MojoliciousPluginOpenAPI MojoliciousPluginWebpack
    ParseIRC TextMarkdown TimePiece UnicodeUTF8
    CpanelJSONXS EV
  ];

  checkInputs = with perlPackages; [ TestDeep TestMore ];

  postPatch = ''
    patchShebangs script/convos
  '';

  # A test fails since gethostbyaddr(127.0.0.1) fails to resolve to localhost in
  # the sandbox, we replace the this out from a substitution expression
  #
  # Module::Install is a runtime dependency not covered by the tests, so we add
  # a test for it.
  #
  preCheck = ''
    substituteInPlace t/web-register-open-to-public.t \
      --replace '!127.0.0.1!' '!localhost!'

    echo "use Test::More tests => 1;require_ok('Module::Install')" \
      > t/00_nixpkgs_module_install.t
  '';

  # Convos expects to find assets in both auto/share/dist/Convos, and $MOJO_HOME
  # which is set to $out
  #
  postInstall = ''
    AUTO_SHARE_PATH=$out/${perl.libPrefix}/auto/share/dist/Convos
    mkdir -p $AUTO_SHARE_PATH
    cp -vR public assets $AUTO_SHARE_PATH/
    ln -s $AUTO_SHARE_PATH/public/asset $out/asset
    cp -vR templates $out/templates
    cp cpanfile $out/cpanfile
  '' + optionalString stdenv.isDarwin ''
    shortenPerlShebang $out/bin/convos
  '' + ''
    wrapProgram $out/bin/convos --set MOJO_HOME $out
  '';

  passthru.tests = nixosTests.convos;

  meta = {
    homepage = "https://convos.chat";
    description = "Convos is the simplest way to use IRC in your browser";
    license = stdenv.lib.licenses.artistic2;
    maintainers = with maintainers; [ sgo ];
  };
}
