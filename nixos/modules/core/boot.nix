{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot = {
    plymouth = {
      enable = true;
      theme = "breeze"; 
    };

    kernelParams = [ "quiet" "splash" "boot.shell_on_fail" "loglevel=3" "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3" ];
    # Использование systemd в initrd для более раннего запуска Plymouth
    initrd.systemd.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
}
