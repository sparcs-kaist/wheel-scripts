#!/bin/bash

# SPARCS Dev server setup tool
# Originally written by DoyunShin(Roul)

# Function to display usage instructions and exit
print_usage_and_exit() {
  echo "========================================"
  echo "           SPARCS Dev Setup Script      "
  echo "========================================"
  echo "Usage  : $0 [--docker] [--help]"
  echo "Example: $0 --docker"
  echo "----------------------------------------"
  echo "Arguments:"
  echo "  --docker : Install and configure Docker"
  echo "  --help   : Display this help message"
  echo "========================================"
  exit 1
}

# Parse arguments
INSTALL_DOCKER=false

for arg in "$@"; do
  case $arg in
    --docker)
      INSTALL_DOCKER=true
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

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Clear the screen
clear

# Show the configuration
echo "=== Setup Configuration ==="
echo "----------------------------------------"
echo "Install Docker: ${INSTALL_DOCKER}"
echo "----------------------------------------"

echo "This is a script to setup SPARCS Dev server."
echo "If you are not willing to setup SPARCS Dev server, please exit this script."
echo

# Update apt source list
echo "=== Updating APT Sources ==="
# if /etc/apt/sources.list.d/ is exists, then replace the source
if [ -d /etc/apt/sources.list.d ]; then
  for file in /etc/apt/sources.list.d/*; do
    if grep -q "archive.ubuntu.com" "$file"; then
      sed -i "s/archive.ubuntu.com/ftp.kaist.ac.kr/g" "$file"
    fi
  done
fi
# if /etc/apt/sources.list is exists, then replace the source
if [ -f /etc/apt/sources.list ]; then
  sed -i "s/archive.ubuntu.com/ftp.kaist.ac.kr/g" /etc/apt/sources.list
fi

# Install basic packages
echo "=== Installing Basic Packages ==="
apt-get update
apt-get install -y git vim curl screen htop iftop ca-certificates nginx p7zip-full unzip zip

# Setup default editor
echo "=== Configuring Default Editor ==="
update-alternatives --set editor /usr/bin/vim.basic

# Setup docker-ce
if $INSTALL_DOCKER; then
  echo "=== Installing Docker ==="
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update

  apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker.socket
fi

# Setup sshd
echo "=== Configuring SSH ==="
printf "PermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Setup awscli
echo "=== Installing AWS CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -qq awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Setup python
echo "=== Configuring Python ==="
rm /usr/lib/python3.12/EXTERNALLY-MANAGED
curl https://bootstrap.pypa.io/get-pip.py | python3
python3 -m pip install -U pip wheel setuptools
python3 -m pip install -U certbot certbot-nginx
