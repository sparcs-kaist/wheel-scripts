#!/bin/bash
# shellcheck disable=SC2046,SC2086,SC2155
set -ex
mkdir -p /tmp/os-image
pushd /tmp/os-image || exit
#curl -LO https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
curl -LO https://ftp.kaist.ac.kr/ubuntu-cloud-image/jammy/current/jammy-server-cloudimg-amd64.img

export IMAGE_NAME_BASE=jammy-server-cloudimg-amd64
qemu-img convert -p -f qcow2 -O raw $IMAGE_NAME_BASE.img $IMAGE_NAME_BASE.raw

qemu-img resize -f raw "$IMAGE_NAME_BASE.raw" 3G
sudo sgdisk -e "$IMAGE_NAME_BASE.raw"
sudo parted "$IMAGE_NAME_BASE.raw" resizepart 1 3000MB

mkdir -p mnt

export ROOTFS=/dev/mapper/$(sudo kpartx -v -a $IMAGE_NAME_BASE.raw | grep "p1 " | cut -f 3 -d " ")
sudo e2fsck -f "$ROOTFS"
sudo resize2fs "$ROOTFS"

sudo mount $ROOTFS mnt
sudo mv mnt/etc/resolv.conf mnt/etc/resolv.conf.backup
cat >script <<EOF
#!/bin/bash
set -xe
echo "nameserver 1.1.1.1" > /etc/resolv.conf

export DEBIAN_FRONTEND=noninteractive

# Update source to ftp kaist
if [ -d /etc/apt/sources.list.d ]; then
  for file in /etc/apt/sources.list.d/*; do
    if grep -q "archive.ubuntu.com" "$file"; then
      sed -i "s/archive.ubuntu.com/ftp.kaist.ac.kr/g" "$file"
    fi
  done
fi
if [ -f /etc/apt/sources.list ]; then
  sed -i "s/archive.ubuntu.com/ftp.kaist.ac.kr/g" /etc/apt/sources.list
fi

# Install basic packages
apt-get update
apt-get full-upgrade -y
apt-get install -y git vim curl screen htop iftop ca-certificates nginx p7zip-full unzip zip qemu-guest-agent
# apt remove -y --purge --autoremove snapd pollinate 

# Update Default Editor
update-alternatives --set editor /usr/bin/vim.basic

# Clear Ubuntu default accounts
sudo sed -i 's|^ENV_PATH[[:space:]]*PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games|ENV_PATH\tPATH=/usr/local/bin:/usr/bin:/bin|' /etc/login.defs

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

# Setup awscli
#echo "=== Installing AWS CLI ==="
#curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
#unzip -qq awscliv2.zip
#./aws/install
#rm -rf aws awscliv2.zip



# Cleanup
apt clean all
history -c
exit
EOF

sudo mount --bind /dev mnt/dev 
sudo mount --bind /dev/pts mnt/dev/pts 
sudo mount --bind /proc mnt/proc 
sudo mount --bind /sys mnt/sys
sudo mount --bind /run mnt/run

sudo cp script mnt
sudo chmod +x mnt/script
sudo chroot mnt ./script
sudo mv mnt/etc/resolv.conf.backup mnt/etc/resolv.conf
sudo rm -f mnt/script

sudo umount mnt/run 
sudo umount mnt/sys 
sudo umount mnt/proc 
sudo umount mnt/dev/pts 
sudo umount mnt/dev 

sudo umount mnt
sudo kpartx -d $IMAGE_NAME_BASE.raw
# mv $IMAGE_NAME_BASE.raw ubuntu2204.raw
#cp $IMAGE_NAME_BASE.raw $IMAGE_NAME_BASE-custom$VFIO_CUSTOM_IMAGE-$(date "+%Y%m%d")-0.raw

#cp $IMAGE_NAME_BASE-custom$VFIO_CUSTOM_IMAGE-$(date "+%Y%m%d")-0.raw ../$IMAGE_NAME_BASE-custom$VFIO_CUSTOM_IMAGE-$(date "+%Y%m%d")-0.raw
# qemu-img convert -p -f raw -O qcow2 $IMAGE_NAME_BASE-custom$VFIO_CUSTOM_IMAGE-$(date "+%Y%m%d")-0.raw $IMAGE_NAME_BASE-custom$VFIO_CUSTOM_IMAGE-$(date "+%Y%m%d")-0.qcow2

qemu-img convert -p -f raw -O qcow2 $IMAGE_NAME_BASE.raw $IMAGE_NAME_BASE-$(date "+%Y%m%d-%H%M%S").qcow2 

rm -rf script jammy-server-cloudimg-amd64.img jammy-server-cloudimg-amd64.raw mnt
popd || exit
