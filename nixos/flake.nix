{
	description = "123";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
                nixvim.url = "github:nix-community/nixvim";
		zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
		home-manager = {
			url = "github:nix-community/home-manager/release-25.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		quickshell = {
      			url = "github:quickshell-mirror/quickshell";
      			inputs.nixpkgs.follows = "nixpkgs";
    		};
	};
	outputs = { self, nixpkgs, zapret-discord-youtube, nixvim, quickshell, ... }@inputs:
		let
			system = "x86_64-linux";
		in{
		nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
			inherit system;
			specialArgs = { inherit inputs system; };
			modules = [
			./configuration.nix

                        nixvim.nixosModules.nixvim
			{
          			environment.systemPackages = [
            			quickshell.packages.x86_64-linux.default
          			];
        		}
			zapret-discord-youtube.nixosModules.default
        		{
        			services.zapret-discord-youtube = {
        			enable = true;
        			config = "general(ALT11)";  # Или любой конфиг из папки configs (general, general(ALT), general (SIMPLE FAKE) и т.д.)
				listGeneral = [
				"osu.ppy.sh"
				"irc.ppy.sh"
				"cho.ppy.sh"
				"c.ppy.sh"
				"c1.ppy.sh"
				"c2.ppy.sh"
				"c3.ppy.sh"
				"c4.ppy.sh"
				"c5.ppy.sh"
				"c6.ppy.sh"
				"ce.ppy.sh"
				"a.ppy.sh"
				"s.ppy.sh"
				"i.ppy.sh"
				"b.ppy.sh"
				"assets.ppy.sh"
				"updates.ppy.sh"
				"spectator.ppy.sh"
				"lazer.ppy.sh"
				"spectator-ext.ppy.sh"
				"store.ppy.sh"
				"accounts.ppy.sh"
				"atuski.net"
				"old.ppy.sh"
				"dev.ppy.sh"
				"bm1.ppy.sh"
				"bm2.ppy.sh"
				"bm3.ppy.sh"
				"bm4.ppy.sh"
				"bm5.ppy.sh"
				"bm6.ppy.sh"
				"bm7.ppy.sh"
				"bm8.ppy.sh"
				"bm9.ppy.sh"
				"bm10.ppy.sh"
				"bm11.osu.ppy.sh"
				"bm11.ppy.sh"
				"bm12.ppy.sh"
				"bm13.ppy.sh"
				"tosu.app"
				"104.20.41.87"
				"104.17.147.22 bm4.ppy.sh"
				"104.17.147.22 bm5.ppy.sh"
				"104.17.147.22 bm6.ppy.sh"
				"104.17.147.22 bm7.ppy.sh"
				"104.17.147.22 bm10.ppy.sh"
				"45.40.145.4 bm4.ppy.sh"
				"45.40.145.4 bm5.ppy.sh"
				"45.40.145.4 bm6.ppy.sh"
				"45.40.145.4 bm7.ppy.sh"
				"45.40.145.4 bm10.ppy.sh"
				"2.58.104.1 bm4.ppy.sh"
				"2.58.104.1 bm5.ppy.sh"
				"2.58.104.1 bm6.ppy.sh"
				"2.58.104.1 bm7.ppy.sh"
				"2.58.104.1 bm10.ppy.sh"
				"2.58.104.1 m1.ppy.sh"
				"2.58.104.1 m2.ppy.sh"
				"2.58.104.1 m3.ppy.sh"
				"2.58.104.1 osu.ppy.sh"
				"2.58.104.1 notify.ppy.sh"
				"2.58.104.1 assets.ppy.sh"
				"2.58.104.1 a.ppy.sh"
				"2.58.104.1 b.ppy.sh"
				"2.58.104.1 c.ppy.sh"
				"2.58.104.1 i.ppy.sh"
				"2.58.104.1 s.ppy.sh"
				"2.58.104.1 auth.ppy.sh"
				"2.58.104.1 sentry.ppy.sh"
				"2.58.104.1 auth-files.ppy.sh"
				"77.223.98.115"
				"77.223.98.115 spectator.ppy.sh"
				"34.241.188.84"
				"12.129.209.68"
				"213.155.155.233"
				"182.162.134.1"
				"166.117.134.156"
				"166.117.114.163"
				"pp.huismetbenen.nl"
				];
        			};
        		}
			];
		};
	};
}

