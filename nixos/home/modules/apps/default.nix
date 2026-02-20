{ config, pkgs, ... }:

{
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
}

