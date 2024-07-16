{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "consul-alerts";
  version = "0.6.2";

  src = fetchFromGitHub {
    rev = "v${version}";
    owner = "EventStore";
    repo = "consul-alerts";
    sha256 = "sha256-0/GrqC0kxXj+VNhisVHnj2MVgZVRD4U/9RHtvSJI9eY=";
  };

  vendorHash = "sha256-ZINEN9DSNQJiupLpI5I2QjggN2/BsVcgUjHM3C2Szc4=";

  # The `consul-alerts` test requires a running consul instance,
  # otherwise the tests fail.
  doCheck = false;

  meta = {
    mainProgram = "consul-alerts";
    description = "Highly available daemon for sending notifications and reminders based on Consul health checks";
    homepage = "https://github.com/EventStore/consul-alerts";
    # As per README
    platforms = lib.platforms.linux ++ lib.platforms.freebsd ++ lib.platforms.darwin;
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ nh2 ];
  };
}
