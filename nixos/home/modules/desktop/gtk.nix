{ config, pkgs, ... }:

{
	gtk = {
		enable = true;
		cursorTheme = {
			package = pkgs.bibata-cursors;
			name = "Bibata-Modern-Ice";
		};
		iconTheme = {
			name = "Papirus-Dark";
			package = pkgs.papirus-icon-theme;
		};
	};
}
