{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot.loader = {
    efi = {
      efiSysMountPoint = "/boot";    
    };
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
      extraEntriesBeforeNixOS = false;
      useOSProber = true;
      extraEntries = ''
        menuentry "Reboot" {
          reboot
        }
        menuentry "PowerOff" {
          halt
        }
      '';
    };
  };
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;
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

  services.xserver.xkb = {
    layout = "ru";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lik = {
    isNormalUser = true;
    shell = pkgs.fish;
    description = "lik";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "lik";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  environment.loginShellInit = ''
  if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
  fi
  '';
#  services.xserver = {
#    enable = true;
#    
#    layout = "us,ru";
#    xkbOptions = "shift_alt_toggle";
#
#    displayManager.sddm = {
#      enable = true;
#      wayland.enable = true;
#    };
#
#  };


  gtk.iconCache.enable = true;
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    # system
    nftables
    #bluetooth
    bluez
    bluez-tools
    blueman
    # Hyprland
    neovim
    hyprland
    hyprlock
    hyprpaper
    hyprpicker
    hyprshot
    kitty
    waybar
    rofi
    nwg-look
    git
    curl
    fastfetch
    nemo
    # Applications
    firefox
    telegram-desktop
    vscode
    # decoration
    papirus-icon-theme
    graphite-gtk-theme
    bibata-cursors
    # shell
    fish
    #unstbr
    onlyoffice-bin
  ];

  
    fonts.packages = with pkgs; [
      font-awesome
      font-awesome_5
      jetbrains-mono
      dejavu_fonts
    ];

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };


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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
