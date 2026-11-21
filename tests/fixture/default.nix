{ pkgs }:
{
  src = ./.;
  version = "0.0.0";
  vendorHash = "sha256-vCGTOsjo38KFNjtvhKrc8pt9Q3pRi8+yqwNoJSMF0J8=";
  postInstall = ''
    install -Dm444 ${pkgs.writeText "greeting" "hello\n"} $out/share/goda-fixture/greeting
  '';
}
