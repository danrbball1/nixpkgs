{
  fetchFromGitHub,
  nodePackages,
  makeBinaryWrapper,
  nodejs,
  pnpm_10,
  python3,
  stdenv,
  cctools,
  lib,
  nixosTests,
  enableLocalIcons ? false,
}:
let
  dashboardIcons = fetchFromGitHub {
    owner = "homarr-labs";
    repo = "dashboard-icons";
    rev = "51a2ae7b101c520bcfb5b44e5ddc99e658bc1e21"; # Until 2025-01-06
    hash = "sha256-rKXeMAhHV0Ax7mVFyn6hIZXm5RFkbGakjugU0DG0jLM=";
  };

  installLocalIcons = ''
    mkdir -p $out/share/homepage/public/icons
    cp ${dashboardIcons}/png/* $out/share/homepage/public/icons
    cp ${dashboardIcons}/svg/* $out/share/homepage/public/icons
    cp ${dashboardIcons}/LICENSE $out/share/homepage/public/icons/
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "homepage-dashboard";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "gethomepage";
    repo = "homepage";
    tag = "v${finalAttrs.version}";
    hash = "sha256-B6hgQWAILfZNRFN4APX/3T2LcVj2FQPS/CAUdUA+drU=";
  };

  # This patch ensures that the cache implementation respects the env
  # variable `NIXPKGS_HOMEPAGE_CACHE_DIR`, which is set by default in the
  # wrapper below.
  # The patch is automatically generated by the `update.sh` script.
  patches = [ ./prerender_cache_path.patch ];

  pnpmDeps = pnpm_10.fetchDeps {
    inherit (finalAttrs)
      pname
      version
      src
      patches
      ;
    hash = "sha256-1WsiSG+dZVpd28bBjf3EYn95sxMCXsQPd27/otWW0nI=";
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs
    pnpm_10.configHook
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ cctools ];

  buildInputs = [
    nodePackages.node-gyp-build
  ];

  env.PYTHON = "${python3}/bin/python";

  buildPhase = ''
    runHook preBuild
    mkdir -p config
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share}
    cp -r .next/standalone $out/share/homepage/
    cp -r public $out/share/homepage/public
    chmod +x $out/share/homepage/server.js

    mkdir -p $out/share/homepage/.next
    cp -r .next/static $out/share/homepage/.next/static

    makeWrapper "${lib.getExe nodejs}" $out/bin/homepage \
      --set-default PORT 3000 \
      --set-default HOMEPAGE_CONFIG_DIR /var/lib/homepage-dashboard \
      --set-default NIXPKGS_HOMEPAGE_CACHE_DIR /var/cache/homepage-dashboard \
      --add-flags "$out/share/homepage/server.js"

    ${if enableLocalIcons then installLocalIcons else ""}

    runHook postInstall
  '';

  doDist = false;

  passthru = {
    tests = {
      inherit (nixosTests) homepage-dashboard;
    };
    updateScript = ./update.sh;
  };

  meta = {
    description = "Highly customisable dashboard with Docker and service API integrations";
    changelog = "https://github.com/gethomepage/homepage/releases/tag/v${finalAttrs.version}";
    mainProgram = "homepage";
    homepage = "https://gethomepage.dev";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ jnsgruk ];
    platforms = lib.platforms.all;
  };
})
