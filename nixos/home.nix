{ config, pkgs, ... }: {
	home.packages = with pkgs; [
		prismlauncher
		telegram-desktop
		vesktop
		onlyoffice-desktopeditors
		yandex-music
		scrcpy
		android-tools
	    adwsteamgtk
		virt-manager
		qemu
	];
	home.pointerCursor = {
		gtk.enable = true;
		x11.enable = true;
		package = pkgs.bibata-cursors;
		name = "Bibata-Modern-Ice";
		size = 24;
	};

	gtk = {
		enable = true;
		cursorTheme = {
			package = pkgs.bibata-cursors;
			name = "Bibata-Modern-Ice";
		};
	};
	home = {
		enableNixpkgsReleaseCheck = false;
		stateVersion = "25.11";
	};

}
