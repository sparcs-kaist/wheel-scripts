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
      sed -i "s/archive.ubuntu.com/ftp-cache.sparcs.org/g" "$file"
    fi
  done
fi
# if /etc/apt/sources.list is exists, then replace the source
if [ -f /etc/apt/sources.list ]; then
  sed -i "s/archive.ubuntu.com/ftp-cache.sparcs.org/g" /etc/apt/sources.list
fi

# Install basic packages
echo "=== Installing Basic Packages ==="
apt update
apt install -y git vim curl screen htop iftop ca-certificates nginx p7zip-full unzip zip qemu-guest-agent resolvconf

# Set nameserver to 1.1.1.1
echo "=== Set nameserver to 1.1.1.1 ==="
mv /etc/resolv.conf /etc/resolv.conf.backup
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# Setup default editor
echo "=== Configuring Default Editor ==="
update-alternatives --set editor /usr/bin/vim.basic

# Clear Ubuntu default accounts
sed -i 's|^ENV_PATH[[:space:]]*PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games|ENV_PATH\tPATH=/usr/local/bin:/usr/bin:/bin|' /etc/login.defs

names=(
  "lp" "mail" "games" "dialout" "fax" "news" "uucp" "proxy" "voice"
  "sasl" "plugdev" "users" "cdrom" "floppy" "tape" "audio"
  "dip" "irc" "src" "list" "gnats" "swtpm" "input" "staff" "backup"
  "sgx" "rdma"
)
for name in "\${names[@]}"; do
  # Check if the user exists and remove if it does
  if /usr/bin/id -u "\$name" &>/dev/null; then
    echo "Removing user: \$name"
    /usr/sbin/userdel -f "\$name"
  fi
  # Check if the group exists and remove if it does
  if /usr/bin/getent group "\$name" &>/dev/null; then
    echo "Removing group: \$name"
    /usr/sbin/groupdel -f "\$name"
  fi
   sed -i "/\$name/d"  /usr/lib/sysusers.d/basic.conf
done

# Disable ssh root login
printf "PermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Setting timezone to KST
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
echo "Asia/Seoul" | tee /etc/timezone
dpkg-reconfigure tzdata

# Setup docker-ce
if $INSTALL_DOCKER; then
  echo "=== Installing Docker ==="
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt remove $pkg; done
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update

  apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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

# Cleanup
apt clean all
history -c
exit