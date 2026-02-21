{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [
      inputs.home-manager.nixosModules.home-manager
      ./hardware-configuration.nix

      ./modules/programs/kdeconnect.nix
      ./modules/programs/appimage.nix
      ./modules/programs/hyprland.nix
      ./modules/programs/firefox.nix
      ./modules/programs/nixvim.nix
      ./modules/programs/steam.nix

      ./modules/services/pipewire.nix
      ./modules/services/printing.nix

      ./modules/core/timezone.nix
      ./modules/core/locale.nix
      ./modules/core/keymap.nix
      ./modules/core/hosts.nix
      ./modules/core/user.nix
      ./modules/core/boot.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.rexilone = {
      imports = [ ./home/home.nix ];
    };
  };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
#  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
#  services.displayManager.gdm.enable = true;
#  services.desktopManager.gnome.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    home-manager
    brightnessctl
    hyprshot
    hyprpicker
    hyprlock
    # da
    usbutils
    playerctl
    fastfetch
    pavucontrol
    nwg-look
    viewnior
    kitty
    btop
    swww
    rofi
    tree
    jq
    socat
    p7zip
    obs-studio
    # file
    thunar
    thunar-archive-plugin
    thunar-volman
    thunar-media-tags-plugin
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
    # не на гит
      (pkgs.ciscoPacketTracer8.override {
      packetTracerSource = ./CiscoPacketTracer_820_Ubuntu_64bit.deb;
    })
    libdbusmenu-gtk3
    libdbusmenu
    wireplumber
  ];

  environment.sessionVariables = {
    GTK_MODULES = lib.mkForce ""; # Очистим, т.к. appmenu-gtk-module недоступен
  };

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
    # для ios
    inter
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "ciscoPacketTracer8-8.2.2"
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  virtualisation.libvirtd.enable = true; # виртуализация для кему
  
  programs.fish.enable = true;
  programs.firejail.enable = true;
  system.stateVersion = "25.11"; # Did you read the comment?

}
