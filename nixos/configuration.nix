{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [
      inputs.home-manager.nixosModules.home-manager
      ./hardware-configuration.nix
      ./modules/nixvim.nix
      ./modules/bluetooth.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.rexilone = {
      imports = [ ./home.nix ];
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot = {
  # Включение Plymouth
    plymouth = {
      enable = true;
      # Выбор темы (например, стандартная nixos-breeze)
      theme = "breeze"; 
    };

    # Параметры ядра для "тихой" загрузки (скрывают текст логов)
    kernelParams = [ "quiet" "splash" "boot.shell_on_fail" "loglevel=3" "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3" ];
    # Использование systemd в initrd для более раннего запуска Plymouth
    initrd.systemd.enable = true;
  };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Yakutsk";

  i18n.defaultLocale = "ru_RU.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
  };

  users.users.rexilone = {
    shell = pkgs.fish;    
    isNormalUser = true;
    description = "rexilone";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default
    home-manager
    brightnessctl
    hyprshot
    hyprpicker
    hyprlock
    # da
    usbutils
    fastfetch
    pavucontrol
    nwg-look
    viewnior
    kitty
    btop
    swww
    rofi
    jq
    p7zip
    obs-studio
    # file
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    xfce.thunar-media-tags-plugin
    # для дисков / флешек
    ntfs3g
    udiskie
    gvfs
    # 123
    mpv
    git
    cava
    # bluetooth
    bluez
    bluez-tools
    blueman    
  ];

  security.polkit.enable = true; # для тунара шоб автомонтировал
  services.gvfs.enable = true; # для телефона монтирования

  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only # нахуй не нужен
    nerd-fonts.fira-code
    font-awesome
    jetbrains-mono
    liberation_ttf
    dejavu_fonts
    corefonts
    fira-code
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server
  };  

  programs.fish.enable = true;

  # services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;
  system.stateVersion = "25.11"; # Did you read the comment?

}
