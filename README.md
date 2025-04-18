# wheel-scripts

A collection of shell scripts for automating VM creation and setup for SPARCS development servers.

## Scripts Overview

### 1. create-vm.sh

Creates a new Ubuntu VM in Proxmox with customized configurations.

#### Requirements
- Proxmox VE environment
- `libguestfs-tools` (will be automatically installed if missing)
- Network bridge interface configured in Proxmox

#### Usage
```bash
./create-vm.sh --version=<22.04|24.10> --id=<vm_id> --bridge=<bridge_interface>
```

#### Arguments
- `--version`: Ubuntu version (22.04 or 24.10)
- `--id`: Unique VM ID (numeric)
- `--bridge`: Network bridge interface
- `--help`: Display help message

#### Example
```bash
./create-vm.sh --version=24.10 --id=100 --bridge=vInternal
```

### 2. setup-script.sh

Sets up a SPARCS development server with essential packages and configurations.

#### Features
- Updates APT sources to use KAIST mirror
- Installs basic development packages
- Configures SSH settings
- Installs AWS CLI
- Sets up Python environment
- Docker installation [Optional]

#### Usage
```bash
./setup-script.sh [--docker] [--help]
```

#### Arguments
- `--docker`: Install and configure Docker
- `--help`: Display help message

#### Example
```bash
./setup-script.sh --docker
```

### 3. run-script-vm.sh

Downloads and executes setup-script.sh in a specified VM.

#### Requirements
- Proxmox VE environment
- `jq` (will be automatically installed if missing)
- Target VM must be running and have network access

#### Usage
```bash
./run-script-vm.sh <VMID> [--docker]
```

#### Arguments
- `VMID`: The ID of the VM to run the script in
- `--docker`: Pass --docker flag to the setup script

#### Example
```bash
./run-script-vm.sh 100 --docker
```

## Workflow Example

1. Create a new VM:
```bash
./create-vm.sh --version=24.10 --id=100 --bridge=vInternal
```

2. Run the setup script in the newly created VM:
```bash
./run-script-vm.sh 100 --docker
```

This will create a new Ubuntu 24.10 VM with ID 100, then set it up as a SPARCS development server with Docker installed.

## Notes

- All scripts require root privileges to run
- VMs are created with UEFI boot and QEMU guest agent enabled
- Default VM specifications:
  - Memory: 2048 MB
  - Cores: 2
  - Disk Size: 10G