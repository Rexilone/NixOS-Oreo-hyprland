{ config, pkgs, ... }: {
	home.packages = with pkgs; [
		prismlauncher
		telegram-desktop
		vesktop
	];
	home = {
		enableNixpkgsReleaseCheck = false;
		stateVersion = "25.11";
	};

	programs.bash = {
		enable = true;
		shellAliases = {
			rebuild = "sudo nixos-rebuild switch";
		};
	};
}
