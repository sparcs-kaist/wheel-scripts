#!/bin/bash

# Function to display usage instructions and exit
print_usage_and_exit() {
  echo "========================================"
  echo "           VM Creation Script           "
  echo "========================================"
  echo "Usage  : $0 --distro=<ubuntu|debian> --version=<22.04|24.10|10|12> --id=<vm_id> --bridge=<bridge_interface>"
  echo "Example: $0 --distro=debian --version=12 --id=100 --bridge=vInternal"
  echo "----------------------------------------"
  echo "Arguments:"
  echo "  --distro=<ubuntu|debian> : Distribution (ubuntu or debian)"
  echo "  --version=<22.04|24.10|10|12> : Version (Ubuntu: 22.04, 24.10; Debian: 10, 12)"
  echo "  --id=<vm_id>            : Unique VM ID (numeric)"
  echo "  --bridge=<bridge>       : Network bridge interface"
  echo "  --help                  : Display this help message"
  echo "========================================"
  exit 1
}

# Check if no arguments provided
if [[ $# -eq 0 ]]; then
  print_usage_and_exit
fi

# Parse arguments
for arg in "$@"; do
  case $arg in
    --distro=*)
      DISTRO="${arg#*=}"
      if [[ "$DISTRO" != "ubuntu" && "$DISTRO" != "debian" ]]; then
        echo "Error: Invalid distro. Allowed values are ubuntu or debian."
        exit 1
      fi
      ;;
    --version=*)
      VERSION="${arg#*=}"
      if [[ "$DISTRO" == "ubuntu" && "$VERSION" != "22.04" && "$VERSION" != "24.10" ]]; then
        echo "Error: Invalid Ubuntu version. Allowed values are 22.04 or 24.10."
        exit 1
      elif [[ "$DISTRO" == "debian" && "$VERSION" != "10" && "$VERSION" != "12" ]]; then
        echo "Error: Invalid Debian version. Allowed values are 10 or 12."
        exit 1
      fi
      ;;
    --id=*)
      VM_ID="${arg#*=}"
      if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
        echo "Error: VM ID must be a numeric value."
        exit 1
      fi
      ;;
    --bridge=*)
      BRIDGE_INTERFACE="${arg#*=}"
      ;;
    --help)
      print_usage_and_exit
      ;;
    *)
      echo "Error: Unknown argument '$arg'"
      exit 1
      ;;
  esac
done

# Validate required arguments
missing_args=()

if [[ -z "$DISTRO" ]]; then
  missing_args+=("DISTRO")
fi

if [[ -z "$VERSION" ]]; then
  missing_args+=("VERSION")
fi

if [[ -z "$VM_ID" ]]; then
  missing_args+=("VM_ID")
fi

if [[ -z "$BRIDGE_INTERFACE" ]]; then
  missing_args+=("BRIDGE_INTERFACE")
fi

if [[ ${#missing_args[@]} -gt 0 ]]; then
  echo "Error: Missing required arguments: ${missing_args[*]}"
  exit 1
fi

# Parse bridge interface argument
BRIDGE_INTERFACES=$(brctl show | awk 'NR>1 {print $1}' | sort -u)
if echo "${BRIDGE_INTERFACES}" | grep -qw "$BRIDGE_INTERFACE"; then
  BRIDGE_INTERFACE="$BRIDGE_INTERFACE"
else
  echo "Error: '${BRIDGE_INTERFACE}' is not a valid bridge interface."
  exit 1
fi

# Check if virt-customize is installed
if ! command -v virt-customize &> /dev/null; then
  echo "virt-customize could not be found. Installing libguestfs-tools..."
  apt-get update && apt-get install -y libguestfs-tools
fi

# Variables
if [[ "$DISTRO" == "ubuntu" ]]; then
  CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/releases/${VERSION}/release/ubuntu-${VERSION}-server-cloudimg-amd64.img"
  IMAGE_NAME="ubuntu-${VERSION//./}-cloudimg.qcow2"
  VM_NAME="template-ubuntu-${VERSION}-VM"
elif [[ "$DISTRO" == "debian" ]]; then
  if [[ "$VERSION" == "10" ]]; then
    CLOUD_IMAGE_URL="https://cdimage.debian.org/cdimage/cloud/buster/latest/debian-${VERSION}-genericcloud-amd64.qcow2"
  elif [[ "$VERSION" == "12" ]]; then
    CLOUD_IMAGE_URL="https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-${VERSION}-genericcloud-amd64.qcow2"
  else
    echo "Error: Unsupported Debian version."
    exit 1
  fi
  IMAGE_NAME="debian-${VERSION}-cloudimg.qcow2"
  VM_NAME="template-debian-${VERSION}-VM"
fi

VM_STORAGE=$(hostname)
EFI_STORAGE="local"
MEMORY=2048
CORES=2
DISK_SIZE=10G

# Clear the screen
clear

# Show the configuration
echo "=== VM Configuration ==="
echo "----------------------------------------"
echo "VM ID              : ${VM_ID}"
echo "VM Name            : ${VM_NAME}"
echo "VM Storage         : ${VM_STORAGE}"
echo "VM Bridge Interface: ${BRIDGE_INTERFACE}"
echo "Memory             : ${MEMORY} MB"
echo "Cores              : ${CORES}"
echo "Disk Size          : ${DISK_SIZE}"
echo "Distro             : ${DISTRO}"
echo "Version            : ${VERSION}"
echo "Cloud Image URL    : ${CLOUD_IMAGE_URL}"
echo "Image Name         : ${IMAGE_NAME}"
echo "EFI Storage        : ${EFI_STORAGE}"
echo "----------------------------------------"

# Download Cloud Image
echo "=== Downloading Cloud Image ==="
wget -O ${IMAGE_NAME} ${CLOUD_IMAGE_URL}

# Customize the image
echo "=== Customizing the image... ==="
virt-customize -a ${IMAGE_NAME} --install qemu-guest-agent

# Import the image to Proxmox
echo "=== Importing image to Proxmox storage... ==="
qm create ${VM_ID} --name ${VM_NAME} --memory ${MEMORY} --cores ${CORES}
qm importdisk ${VM_ID} ${IMAGE_NAME} ${VM_STORAGE}
qm set ${VM_ID} --scsihw virtio-scsi-pci --scsi0 "${VM_STORAGE}:${VM_ID}/vm-${VM_ID}-disk-0.raw"
qm set ${VM_ID} --efidisk0 ${EFI_STORAGE}:0,format=qcow2
qm set ${VM_ID} --boot c --bootdisk scsi0
qm set ${VM_ID} --net0 virtio,bridge=${BRIDGE_INTERFACE}
qm set ${VM_ID} --scsi1 ${VM_STORAGE}:cloudinit

# Cloud-init configuration
echo "=== Configuring Cloud-Init... ==="
qm set ${VM_ID} --ipconfig0 ip=dhcp
qm set ${VM_ID} --ciupgrade 0

# Resize disk
echo "=== Resizing disk... ==="
qm resize ${VM_ID} scsi0 ${DISK_SIZE}

# Enable qemu agent
echo "=== Enabling QEMU agent... ==="
qm set ${VM_ID} --agent 1

# Cleanup
echo "=== Cleaning up... ==="
rm -f ${IMAGE_NAME}

echo "VM ${VM_NAME} with ID ${VM_ID} created successfully!"