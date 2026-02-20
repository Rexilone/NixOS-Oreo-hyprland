{ config, pkgs, ... }:

{

  imports =
    [
      ./modules/apps/default.nix
      ./modules/desktop/cursor.nix
      ./modules/desktop/gtk.nix
    ];

	home = {
		enableNixpkgsReleaseCheck = false;
		stateVersion = "25.11";
	};

}

