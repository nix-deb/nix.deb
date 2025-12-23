#!@runtimeShell@
set -euo pipefail

VM_DIR="@vmDir@"
SSH_KEY="@vm-ssh-key@/id_ed25519"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $SSH_KEY"
VIRTIOFSD_SOCKET="$VM_DIR/virtiofsd.sock"
VIRTIOFSD_PID_FILE="$VM_DIR/virtiofsd.pid"

# Base image from Nix store
BASE_IMAGE="@cloudImage@"

# Initialize VM directory with a fresh copy of the base image
init_vm() {
  mkdir -p "$VM_DIR"

  if [[ ! -f "$VM_DIR/disk.qcow2" ]]; then
    echo "Creating VM disk from base image..."
    # Create a CoW overlay on top of the read-only Nix store image
    @qemu@/bin/qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$VM_DIR/disk.qcow2" 20G
  fi
}

# Clean up virtiofsd daemon
cleanup_virtiofsd() {
  if [[ -f "$VIRTIOFSD_PID_FILE" ]]; then
    kill "$(cat "$VIRTIOFSD_PID_FILE")" 2>/dev/null || true
    rm -f "$VIRTIOFSD_PID_FILE"
  fi
  rm -f "$VIRTIOFSD_SOCKET"
}

# Start virtiofsd daemon for /nix/store
start_virtiofsd() {
  cleanup_virtiofsd  # Clean up any stale processes/sockets
  echo "Starting virtiofsd for /nix/store..."
  @virtiofsd@/bin/virtiofsd \
    --socket-path "$VIRTIOFSD_SOCKET" \
    --shared-dir /nix/store \
    --sandbox none &
  echo $! > "$VIRTIOFSD_PID_FILE"
  # Wait for socket to be created
  for i in $(seq 1 50); do
    [[ -S "$VIRTIOFSD_SOCKET" ]] && return 0
    sleep 0.1
  done
  echo "Error: virtiofsd socket not created"
  return 1
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

case "${1:-help}" in
  run)
    init_vm
    start_virtiofsd
    trap cleanup_virtiofsd EXIT
    echo "Starting VM @name@..."
    echo "Press Ctrl-A X to exit QEMU"
    echo ""
    @qemuFgCmd@
    ;;

  run-bg)
    init_vm
    start_virtiofsd
    echo "Starting VM @name@ in background..."
    @qemuBgCmd@
    wait_for_ssh
    echo "VM running (QEMU PID: $(cat "$VM_DIR/qemu.pid"), virtiofsd PID: $(cat "$VIRTIOFSD_PID_FILE"))"
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
    snapshot_name="${2:-snapshot}"
    echo "Creating snapshot: $snapshot_name"
    @qemu@/bin/qemu-img snapshot -c "$snapshot_name" "$VM_DIR/disk.qcow2"
    echo "Snapshot created"
    ;;

  restore)
    snapshot_name="${2:-snapshot}"
    echo "Restoring snapshot: $snapshot_name"
    @qemu@/bin/qemu-img snapshot -a "$snapshot_name" "$VM_DIR/disk.qcow2"
    echo "Snapshot restored"
    ;;

  snapshots)
    echo "Available snapshots:"
    @qemu@/bin/qemu-img snapshot -l "$VM_DIR/disk.qcow2"
    ;;

  stop)
    if [[ -f "$VM_DIR/qemu.pid" ]]; then
      kill "$(cat "$VM_DIR/qemu.pid")" 2>/dev/null || true
      rm -f "$VM_DIR/qemu.pid"
    fi
    cleanup_virtiofsd
    echo "VM stopped"
    ;;

  reset)
    echo "Removing VM disk (will recreate from base image)..."
    rm -f "$VM_DIR/disk.qcow2"
    echo "Done. Run 'vm run' to start fresh."
    ;;

  status)
    if [[ -f "$VM_DIR/qemu.pid" ]] && kill -0 "$(cat "$VM_DIR/qemu.pid")" 2>/dev/null; then
      echo "QEMU: running (PID: $(cat "$VM_DIR/qemu.pid"))"
    else
      echo "QEMU: not running"
    fi
    if [[ -f "$VIRTIOFSD_PID_FILE" ]] && kill -0 "$(cat "$VIRTIOFSD_PID_FILE")" 2>/dev/null; then
      echo "virtiofsd: running (PID: $(cat "$VIRTIOFSD_PID_FILE"))"
    else
      echo "virtiofsd: not running"
    fi
    ;;

  tools)
    # Run shared tools script from host repo
    ssh $SSH_OPTS -p 2222 root@127.0.0.1 'bash /mnt/host/scripts/tools.sh'
    ;;

  help|*)
    echo "Usage: vm <command> [args]"
    echo ""
    echo "Commands:"
    echo "  run               Start VM in foreground (Ctrl-A X to exit)"
    echo "  run-bg            Start VM in background"
    echo "  exec CMD          Execute command in VM via SSH"
    echo "  ssh               Open interactive SSH session"
    echo "  snapshot [NAME]   Create a snapshot (default: 'snapshot')"
    echo "  restore [NAME]    Restore to snapshot (default: 'snapshot')"
    echo "  snapshots         List available snapshots"
    echo "  stop              Stop background VM"
    echo "  reset             Remove VM disk (recreate from base on next run)"
    echo "  status            Check if VM is running"
    echo "  tools             Show installed build tools (Markdown)"
    echo "  help              Show this help"
    ;;
esac
