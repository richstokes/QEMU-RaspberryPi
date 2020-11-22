#!/bin/bash
set -e
IMAGE="raspios.img" 
# DOWNLOAD="http://downloads.raspberrypi.org/raspbian/images/raspbian-2020-02-14/2020-02-13-raspbian-buster.zip"
DOWNLOAD="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2020-08-24/2020-08-20-raspios-buster-arm64-lite.zip"
KERNEL="kernel8.img"
DTB_FILE="bcm2710-rpi-3-b-plus.dtb"
SSH_PORT="8022" # Forward this port to port 22 inside the VM
DISK_SIZE="4G" # Size of SD card, must be multiple of 2

if uname -a | grep Darwin > /dev/null; then
    :
else
    echo "This script is designed to be run on MacOS 🍎"
    exit 1
fi

# Check qemu is installed, brew install if not
qemu-system-aarch64 -version > /dev/null || brew install qemu

# If image not exist, download
if [ -f "$IMAGE" ]; then
    echo "✅  $IMAGE exists"
else 
    echo "⏳  $IMAGE does not exist, downloading.."
    wget -q $DOWNLOAD -O raspbian.zip
    unzip raspbian.zip
    mv *raspios*.img $IMAGE
fi

# Extract from image if kernel files not exist
if [ -f "$KERNEL" ]; then
    echo "✅  $KERNEL exists"
    # :
else 
    echo "⏳  $KERNEL does not exist, extracting from $IMAGE.."
    hdiutil unmount /Volumes/boot > /dev/null 2>&1 || true
    hdiutil mount $IMAGE > /dev/null 2>&1

    # Extract kernel8 file
    cp /Volumes/boot/$KERNEL .
    hdiutil unmount /Volumes/boot > /dev/null 2>&1
fi

# Extract from image if dtb file not exist
if [ -f "$DTB_FILE" ]; then
    echo "✅  $DTB_FILE exists"
    # :
else 
    echo "⏳  $DTB_FILE does not exist, extracting from $IMAGE.."
    hdiutil unmount /Volumes/boot > /dev/null 2>&1 || true
    hdiutil mount $IMAGE > /dev/null

    # Extract dtb file
    cp /Volumes/boot/$DTB_FILE .
    hdiutil unmount /Volumes/boot > /dev/null
fi

# Set image file size
qemu-img resize $IMAGE $DISK_SIZE > /dev/null 2>&1 || true


# Run 
echo "👩🏽‍💻  Starting emulator.."
echo "👩🏽‍💻  SSH Forwarded via localhost:$SSH_PORT"
echo "👩🏽‍💻  You will need to install/enable SSHd before connecting."
echo "👩🏽‍💻  On first boot, you probably want to run 'sudo raspi-config --expand-rootfs' to get the full $DISK_SIZE disk space"
echo
sleep 2

qemu-system-aarch64 -m 1024 -M raspi3 -kernel "$KERNEL" \
-accel tcg,thread=multi \
-dtb "$DTB_FILE" -sd "$IMAGE" \
-append "console=ttyAMA0 root=/dev/mmcblk0p2 rw rootwait rootfstype=ext4" \
-nographic -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22
