if status is-interactive
    set -g fish_greeting ""
    abbr -a ff 'fastfetch'
    abbr -a rebuild 'sudo nixos-rebuild switch --flake /etc/nixos'
end
