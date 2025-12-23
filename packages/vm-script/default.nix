{ pkgs, perSystem, ... }:

pkgs.lib.makeOverridable (
  {
    name,
    cloudImage,
    hostSharePath,
  }:
  let
    cloudInitDisk = perSystem.self.cloud-init {
      inherit name;
    };

    # Working directory for this VM
    vmDir = "$HOME/.cache/nix-deb-vm/${name}";

    # Base QEMU args (shared between foreground and background)
    qemuBaseArgs = [
      "-name ${name}"
      "-smp 4"
      "-cpu host"
      "-enable-kvm"

      # Memory with shared backend for virtiofs
      "-m 4G"
      "-object memory-backend-memfd,id=mem,size=4G,share=on"
      "-numa node,memdev=mem"

      # Main disk (will be a copy of the cloud image)
      "-drive file=${vmDir}/disk.qcow2,if=virtio,format=qcow2"

      # Cloud-init seed disk
      "-drive file=${cloudInitDisk}/seed.img,if=virtio,format=raw,readonly=on"

      # 9P share for host files (repo)
      "-virtfs local,path=${hostSharePath},mount_tag=host_share,security_model=mapped-xattr,id=host_share"

      # virtiofs for /nix/store (read-only, shared via virtiofsd)
      "-chardev socket,id=nix_store,path=${vmDir}/virtiofsd.sock"
      "-device vhost-user-fs-pci,chardev=nix_store,tag=nix_store"

      # Networking with SSH port forward
      "-nic user,hostfwd=tcp:127.0.0.1:2222-:22"
    ];

    qemuBaseCmd = "${pkgs.qemu}/bin/qemu-system-x86_64 ${builtins.concatStringsSep " " qemuBaseArgs}";

    # Foreground: serial to stdio, interactive
    qemuFgCmd = "${qemuBaseCmd} -nographic -serial mon:stdio";

    # Background: no display, serial to file, daemonize
    qemuBgCmd = "${qemuBaseCmd} -display none -serial file:${vmDir}/serial.log -daemonize -pidfile ${vmDir}/qemu.pid";
  in
  pkgs.replaceVarsWith {
    name = "vm";
    src = ./vm.sh;
    isExecutable = true;
    dir = "bin";
    replacements = {
      inherit
        name
        cloudImage
        qemuFgCmd
        qemuBgCmd
        vmDir
        ;
      inherit (perSystem.self) vm-ssh-key;
      inherit (pkgs)
        qemu
        runtimeShell
        virtiofsd
        ;
    };
  }
)
