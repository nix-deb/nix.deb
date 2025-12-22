{ pkgs }:

let
  # Generate an SSH keypair for VM access
  sshKeyPair = pkgs.runCommand "vm-ssh-key" {} ''
    mkdir -p $out
    ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f $out/id_ed25519 -N "" -C "nix-deb-vm"
  '';

  # Cloud-init configuration for first boot
  mkCloudInit = { name, family, codename }: let
    # Packages to install in the VM
    packages = [
      "build-essential"
      "clang"
      "lld"
      "cmake"
      "ninja-build"
      "meson"
      "pkg-config"
      "autoconf"
      "automake"
      "libtool"
      "bison"
      "flex"
      "gettext"
      "git"
      "curl"
      "wget"
      "ca-certificates"
    ];

    userData = pkgs.writeText "user-data" ''
#cloud-config
hostname: ${name}
users:
  - name: root
    ssh_authorized_keys:
      - ${builtins.readFile "${sshKeyPair}/id_ed25519.pub"}

package_update: true
packages:
  - build-essential
  - clang
  - lld
  - cmake
  - ninja-build
  - meson
  - pkg-config
  - autoconf
  - automake
  - libtool
  - bison
  - flex
  - gettext
  - git
  - curl
  - wget
  - ca-certificates

mounts:
  - [ host_share, /mnt/host, 9p, "trans=virtio,version=9p2000.L,msize=104857600", "0", "0" ]

runcmd:
  - mkdir -p /mnt/host
  - mount -a
  - echo "VM ready" > /var/run/vm-ready
    '';

    metaData = pkgs.writeText "meta-data" ''
      instance-id: ${name}
      local-hostname: ${name}
    '';

  in pkgs.runCommand "cloud-init-${name}" {
    nativeBuildInputs = [ pkgs.cloud-utils ];
  } ''
    mkdir -p $out
    cloud-localds $out/seed.img ${userData} ${metaData}
  '';

  # Create the VM wrapper script
  mkVmScript = { name, cloudImage, hostSharePath, cloudInitDisk }:
    let
      # Working directory for this VM
      vmDir = "$HOME/.cache/nix-deb-vm/${name}";

      # Base QEMU args (shared between foreground and background)
      qemuBaseArgs = [
        "-name ${name}"
        "-m 4G"
        "-smp 4"
        "-cpu host"
        "-enable-kvm"

        # Main disk (will be a copy of the cloud image)
        "-drive file=${vmDir}/disk.qcow2,if=virtio,format=qcow2"

        # Cloud-init seed disk
        "-drive file=${cloudInitDisk}/seed.img,if=virtio,format=raw,readonly=on"

        # 9P share for host files
        "-virtfs local,path=${hostSharePath},mount_tag=host_share,security_model=mapped-xattr,id=host_share"

        # Networking with SSH port forward
        "-nic user,hostfwd=tcp:127.0.0.1:2222-:22"
      ];

      qemuBaseCmd = "${pkgs.qemu}/bin/qemu-system-x86_64 ${builtins.concatStringsSep " " qemuBaseArgs}";

      # Foreground: serial to stdio, interactive
      qemuFgCmd = "${qemuBaseCmd} -nographic -serial mon:stdio";

      # Background: no display, serial to file, daemonize
      qemuBgCmd = "${qemuBaseCmd} -display none -serial file:${vmDir}/serial.log -daemonize -pidfile ${vmDir}/qemu.pid";

    in pkgs.writeShellScriptBin "vm" ''
      set -euo pipefail

      VM_DIR="${vmDir}"
      SSH_KEY="${sshKeyPair}/id_ed25519"
      SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $SSH_KEY"

      # Base image from Nix store
      BASE_IMAGE="${cloudImage}"

      # Initialize VM directory with a fresh copy of the base image
      init_vm() {
        mkdir -p "$VM_DIR"

        if [[ ! -f "$VM_DIR/disk.qcow2" ]]; then
          echo "Creating VM disk from base image..."
          # Create a CoW overlay on top of the read-only Nix store image
          ${pkgs.qemu}/bin/qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$VM_DIR/disk.qcow2" 20G
        fi
      }

      # Wait for SSH to be available
      wait_for_ssh() {
        echo "Waiting for SSH..."
        for i in $(seq 1 60); do
          if ssh $SSH_OPTS -p 2222 -o ConnectTimeout=2 root@127.0.0.1 true 2>/dev/null; then
            echo "SSH ready!"
            return 0
          fi
          sleep 2
        done
        echo "Timeout waiting for SSH"
        return 1
      }

      case "''${1:-help}" in
        run)
          init_vm
          echo "Starting VM ${name}..."
          echo "Press Ctrl-A X to exit QEMU"
          echo ""
          ${qemuFgCmd}
          ;;

        run-bg)
          init_vm
          echo "Starting VM ${name} in background..."
          ${qemuBgCmd}
          wait_for_ssh
          echo "VM running (PID: $(cat "$VM_DIR/qemu.pid"))"
          echo "Serial log: $VM_DIR/serial.log"
          ;;

        exec)
          shift
          ssh $SSH_OPTS -p 2222 root@127.0.0.1 "$@"
          ;;

        ssh)
          ssh $SSH_OPTS -p 2222 root@127.0.0.1
          ;;

        snapshot)
          snapshot_name="''${2:-snapshot}"
          echo "Creating snapshot: $snapshot_name"
          ${pkgs.qemu}/bin/qemu-img snapshot -c "$snapshot_name" "$VM_DIR/disk.qcow2"
          echo "Snapshot created"
          ;;

        restore)
          snapshot_name="''${2:-snapshot}"
          echo "Restoring snapshot: $snapshot_name"
          ${pkgs.qemu}/bin/qemu-img snapshot -a "$snapshot_name" "$VM_DIR/disk.qcow2"
          echo "Snapshot restored"
          ;;

        snapshots)
          echo "Available snapshots:"
          ${pkgs.qemu}/bin/qemu-img snapshot -l "$VM_DIR/disk.qcow2"
          ;;

        stop)
          if [[ -f "$VM_DIR/qemu.pid" ]]; then
            kill "$(cat "$VM_DIR/qemu.pid")" 2>/dev/null || true
            rm -f "$VM_DIR/qemu.pid"
            echo "VM stopped"
          else
            echo "No running VM found (no PID file)"
          fi
          ;;

        reset)
          echo "Removing VM disk (will recreate from base image)..."
          rm -f "$VM_DIR/disk.qcow2"
          echo "Done. Run 'vm run' to start fresh."
          ;;

        status)
          if [[ -f "$VM_DIR/qemu.pid" ]] && kill -0 "$(cat "$VM_DIR/qemu.pid")" 2>/dev/null; then
            echo "VM is running (PID: $(cat "$VM_DIR/qemu.pid"))"
          else
            echo "VM is not running"
          fi
          ;;

        tools)
          # Gather tool versions and output as Markdown
          ssh $SSH_OPTS -p 2222 root@127.0.0.1 'bash -s' <<'TOOLS_SCRIPT'
echo "# Build Environment: $(hostname)"
echo ""
echo "## System"
echo ""
echo "| Component | Version |"
echo "|-----------|---------|"
echo "| Distro | $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \") |"
echo "| Kernel | $(uname -r) |"
echo "| glibc | $(ldd --version | head -1 | awk '{print $NF}') |"
echo "| Architecture | $(uname -m) |"
echo ""
echo "## Compilers & Build Tools"
echo ""
echo "| Tool | Version |"
echo "|------|---------|"
if command -v clang &>/dev/null; then
  echo "| clang | $(clang --version | head -1 | sed 's/.*version //' | awk '{print $1}') |"
fi
if command -v clang++ &>/dev/null; then
  echo "| clang++ | $(clang++ --version | head -1 | sed 's/.*version //' | awk '{print $1}') |"
fi
if command -v gcc &>/dev/null; then
  echo "| gcc | $(gcc --version | head -1 | awk '{print $NF}') |"
fi
if command -v g++ &>/dev/null; then
  echo "| g++ | $(g++ --version | head -1 | awk '{print $NF}') |"
fi
if command -v ld.lld &>/dev/null; then
  echo "| lld | $(ld.lld --version | head -1 | awk '{print $3}') |"
fi
if command -v make &>/dev/null; then
  echo "| make | $(make --version | head -1 | awk '{print $NF}') |"
fi
if command -v cmake &>/dev/null; then
  echo "| cmake | $(cmake --version | head -1 | awk '{print $NF}') |"
fi
if command -v meson &>/dev/null; then
  echo "| meson | $(meson --version) |"
fi
if command -v ninja &>/dev/null; then
  echo "| ninja | $(ninja --version) |"
fi
if command -v autoconf &>/dev/null; then
  echo "| autoconf | $(autoconf --version | head -1 | awk '{print $NF}') |"
fi
if command -v automake &>/dev/null; then
  echo "| automake | $(automake --version | head -1 | awk '{print $NF}') |"
fi
if command -v libtoolize &>/dev/null; then
  echo "| libtool | $(libtoolize --version | head -1 | awk '{print $NF}') |"
fi
if command -v pkg-config &>/dev/null; then
  echo "| pkg-config | $(pkg-config --version) |"
fi
echo ""
echo "## Other Tools"
echo ""
echo "| Tool | Version |"
echo "|------|---------|"
if command -v git &>/dev/null; then
  echo "| git | $(git --version | awk '{print $3}') |"
fi
if command -v curl &>/dev/null; then
  echo "| curl | $(curl --version | head -1 | awk '{print $2}') |"
fi
if command -v wget &>/dev/null; then
  echo "| wget | $(wget --version | head -1 | awk '{print $3}') |"
fi
if command -v bison &>/dev/null; then
  echo "| bison | $(bison --version | head -1 | awk '{print $NF}') |"
fi
if command -v flex &>/dev/null; then
  echo "| flex | $(flex --version | awk '{print $2}') |"
fi
TOOLS_SCRIPT
          ;;

        help|*)
          echo "Usage: vm <command> [args]"
          echo ""
          echo "Commands:"
          echo "  run         Start VM in foreground (Ctrl-A X to exit)"
          echo "  run-bg      Start VM in background"
          echo "  exec CMD    Execute command in VM via SSH"
          echo "  ssh         Open interactive SSH session"
          echo "  snapshot [NAME]   Create a snapshot (default: 'snapshot')"
          echo "  restore [NAME]    Restore to snapshot (default: 'snapshot')"
          echo "  snapshots   List available snapshots"
          echo "  stop        Stop background VM"
          echo "  reset       Remove VM disk (recreate from base on next run)"
          echo "  status      Check if VM is running"
          echo "  tools       Show installed build tools (Markdown)"
          echo "  help        Show this help"
          ;;
      esac
    '';

  # Main function to create a development VM
  mkDevVm = { name, family, codename, version, cloudImage, hostSharePath }:
    let
      cloudInitDisk = mkCloudInit { inherit name family codename; };
    in mkVmScript {
      inherit name cloudImage hostSharePath cloudInitDisk;
    };

in {
  inherit mkDevVm sshKeyPair;
}
