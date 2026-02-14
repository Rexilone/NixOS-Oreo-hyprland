{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [
      inputs.home-manager.nixosModules.home-manager
      ./hardware-configuration.nix
      ./modules/nixvim.nix
      ./modules/hyprland.nix
      ./modules/zsh.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.rexilone = {
      imports = [ ./home.nix ];
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot = {
    plymouth = {
      enable = true;
      theme = "breeze"; 
    };

    # Параметры ядра для "тихой" загрузки (скрывают текст логов)
    kernelParams = [ "quiet" "splash" "boot.shell_on_fail" "loglevel=3" "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3" ];
    # Использование systemd в initrd для более раннего запуска Plymouth
    initrd.systemd.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Yakutsk";

  # Select internationalisation properties.
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

  # Enable the X11 windowing system.
#  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
#  services.displayManager.gdm.enable = true;
#  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:caps_toggle";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.rexilone = {
    shell = pkgs.fish;
    isNormalUser = true;
    description = "rexilone";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" "libvirt-qemu" "libvirt-admin" ]; # kvm,libvirt,,   
    packages = with pkgs; [
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
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
    jq
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
    programs.steam = {
	enable = true;
	remotePlay.openFirewall = true; 
	dedicatedServer.openFirewall = true; 
    };  

  virtualisation.libvirtd.enable = true; # виртуализация для кему
  
  programs.fish.enable = true;

  system.stateVersion = "25.11"; # Did you read the comment?

}
