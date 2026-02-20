{ config, pkgs, ... }:

{
  users.users.rexilone = {
    shell = pkgs.fish;
    isNormalUser = true;
    description = "rexilone";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" "libvirt-qemu" "libvirt-admin" ]; # kvm,libvirt,,   
    packages = with pkgs; [
    ];
  };
}
