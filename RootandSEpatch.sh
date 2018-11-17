#!/bin/sh

# Functions (part 1) (Create an unsquashed rootfs copy, add SuperSU & BusyBox, rename original rootfs to .bk, add symlink to R/W copy)

check_if_root() {

if [ $(id -u) != 0 ]; then
  echo
  echo "Error!"
  echo "This script should be run as root."
  exit 1
fi

}

check_writeable_rootfs() {

if [  -e /etc/aroc_writable_test ]; then
rm /etc/aroc_writable_test
fi

touch /etc/aroc_writable_test  2> /dev/null

  if [ ! -e /etc/aroc_writable_test ]; then
  echo "Error!"
  echo "Unable to modify system!"
  echo "You can disable rootfs verification by running the following command, then rebooting."
  echo "sudo /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --partitions $(( $(rootdev -s | sed -r 's/.*(.)$/\1/') - 1))"
  echo "Please run the "remove_rootfs_verification" command now, then reboot and run this script again."
  exit 1
fi

rm /etc/aroc_writable_test

}

detect_architecture() {
  
# TODO: Test/improve this function

#if [ -z "$ANDROID_ARCH" ]; then
    ARCH="`uname -m`"
#fi
case "$ARCH" in
x86 | i?86) ANDROID_ARCH="x86";;
x86_64 | amd64) ANDROID_ARCH="x86";;
armel) ANDROID_ARCH="armel";;
arm64 | aarch64) ANDROID_ARCH="armv7";;
arm*) ANDROID_ARCH="armv7";;
*) error 2 "Invalid architecture '$ARCH'.";;
esac

}

modify_cros_files() {
  
# Just changing two environment variables for Android here.
# In CrOS v70, the writeable container and debug flags have moved (again); they are now in "/usr/share/arc-setup/config.json"
# (Older versions of CrOS have/had Android envs in arc-setup-env).
# (Even older versions had envs in the .conf files.)

mkdir -p /usr/local/Backup

# As of CrOS v70, we need to modify the two values in /usr/share/arc-setup/config.json
if [ -e /usr/share/arc-setup/config.json ]; then

  mkdir -p /usr/local/Backup/arc-setup
  echo "Copying usr/share/arc-setup/config.json to /usr/local/Backup/arc-setup/config.json.old"

  cp -a /usr/share/arc-setup/config.json /usr/local/Backup/arc-setup/config.json.old
  cp -a /usr/share/arc-setup/config.json /usr/share/arc-setup/config.json.old

  echo "Setting '"ANDROID_DEBUGGABLE": true' and '"WRITABLE_MOUNT": true' in /usr/share/arc-setup/config.json"

  sed -i 's/"ANDROID_DEBUGGABLE": false/"ANDROID_DEBUGGABLE": true/g' /usr/share/arc-setup/config.json 2>/dev/null
  sed -i 's/"WRITABLE_MOUNT": false/"WRITABLE_MOUNT": true/g' /usr/share/arc-setup/config.json 2>/dev/null

fi

# In CrOS v6x, the two flags we want to change are within /etc/init/arc-setup-env

if [ -e /etc/init/arc-setup-env ]; then
  echo "Copying /etc/init/arc-setup-env to /usr/local/Backup"
  
  sleep 1

  echo "Setting 'export WRITABLE_MOUNT=1', 'export ANDROID_DEBUGGABLE=1' and (if variable exists) 'export SHARE_FONTS=0' in /etc/init/arc-setup-env"
  
  sed -i 's/export WRITABLE_MOUNT=0/export WRITABLE_MOUNT=1/g' /etc/init/arc-setup-env 2>/dev/null
  sed -i 's/export ANDROID_DEBUGGABLE=0/export ANDROID_DEBUGGABLE=1/g' /etc/init/arc-setup-env 2>/dev/null
  
# NOTE The below line (disabling shared fonts) is no longer needed as of recent CrOS versions.

  sed -i 's/export SHARE_FONTS=1/export SHARE_FONTS=0/g' /etc/init/arc-setup-env 2>/dev/null
  
 fi
 
 # In case we are running a really old version of CrOS somehow, support the original method:
 
 if [ -e /usr/share/arc-setup/config.json ] || [ -e /etc/init/arc-setup-env ]; then
 
  echo "Copying /etc/init/arc-setup.conf and /etc/init/arc-system-mount.conf to /usr/local/Backup"
  sleep 0.2
  echo "Setting 'env WRITABLE_MOUNT=1' in /etc/init/arc-setup.conf and/or /etc/init/arc-system-mount.conf"

  cp -a /etc/init/arc-system-mount.conf /usr/local/Backup/arc-system-mount.conf.old
  cp -a /etc/init/arc-system-mount.conf /etc/init/arc-system-mount.conf.old

  cp -a /etc/init/arc-setup.conf /usr/local/Backup/arc-setup.conf.old
  cp -a /etc/init/arc-setup.conf /etc/init/arc-setup.conf.old
  
  sed -i 's/env WRITABLE_MOUNT=0/env WRITABLE_MOUNT=1/g' /etc/init/arc-setup.conf
  sed -i 's/env WRITABLE_MOUNT=0/env WRITABLE_MOUNT=1/g' /etc/init/arc-system-mount.conf

  echo "Setting 'env ANDROID_DEBUGGABLE=1' in arc-setup.conf"

  sed -i 's/env ANDROID_DEBUGGABLE=0/env ANDROID_DEBUGGABLE=1/g' /etc/init/arc-setup.conf
fi

}

create_image() {

# Creates a blank ext4 image.

# Make some working directories if they don't already exist.

mkdir -p /usr/local/Android_Images
mkdir -p /usr/local/Android_Images/Mounted
mkdir -p /usr/local/Android_Images/Original
echo
echo "Creating new Android system image at /usr/local/Android_Images/system.raw.expanded.img"

# Make the image.
# For arm, the unsquashed image needs to be at least~ 1GB (~800MB for Marshmallow).
# For x86, the unsquashed image needs to be at least ~1.4GB (~1GB for Marshmallow).

# Since the raw rootfs has increased in size lately, create a blank 2GB image, make it sparse so it takes only as much space on disk as required.

# If /usr/local/Android_Images/system.raw.expanded.img already exists, delete it.
rm -rf  /usr/local/Android_Images/system.raw.expanded.img

# Previous version of file creation used dd
# It's much faster if we use fallocate and starts off sparse, so uses only as much space on disk as necessary.

if [ $ANDROID_ARCH=armv7 ]; then
  cd /usr/local/Android_Images
#  dd if=/dev/zero of=system.raw.expanded.img count=2000000 bs=1024 status=progress
fallocate -l 1.7G  /usr/local/Android_Images/system.raw.expanded.img

  else

  if [ $ANDROID_ARCH=x86 ]; then
    cd /usr/local/Android_Images
#  dd if=/dev/zero of=system.raw.expanded.img count=2000000 bs=1024 status=progress
fallocate -l 2.2G  /usr/local/Android_Images/system.raw.expanded.img

   else
    echo "Error!"
    echo "Unable to detect correct architecture!"
    echo
    exit 1
  fi
#
fi

#fallocate -l 2G  /usr/local/Android_Images/system.raw.expanded.img
sleep 0.001
echo "Formatting system.raw.expanded.img as ext4 filesystem"
echo

# After we create an image with fallocate, mkfs.ext4 complains about the geometry/cylinders when we format it
# Here, we ignore this complaint, sending it 2>/dev/null

mkfs ext4 -F /usr/local/Android_Images/system.raw.expanded.img 2>/dev/null

}

download_busybox () {
  
# Since there doesn't appear to be a built-in zip uncompressor available on the command line, if we need to download SuperSU,
# we download BusyBox in order to unzip it. We will also install BusyBox into Android's system/xbin.

if [ ! -e /usr/local/bin/busybox ]; then
  echo "Downloading BusyBox"
  mkdir -p /tmp/aroc
  cd /tmp/aroc

  if [ $ANDROID_ARCH=armv7 ]; then
    curl https://busybox.net/downloads/binaries/1.26.2-defconfig-multiarch/busybox-armv6l -o busybox
  else
  
    if [ ANDROID_ARCH=x86 ]; then

# Commenting out the x64 version as most x64 systems still use a 32 bit Android container.
# So if we use the 32 bit BusyBox, copying it to Android will work.
#     curl https://busybox.net/downloads/binaries/1.26.2-defconfig-multiarch/busybox-x86_64 -o busybox
      curl https://busybox.net/downloads/binaries/1.26.2-defconfig-multiarch/busybox-i686 -o busybox

    else
      echo "Error!"
      echo "Unable to detect correct architecture!"
      echo
      exit 1
      echo
    fi
  
  fi

  echo "Moving BusyBox to /usr/local/bin"
  mkdir -p /usr/local/bin
  mv busybox /usr/local/bin/busybox
  chmod a+x /usr/local/bin/busybox

fi

}

download_supersu() {
	supersu_url="https://download.chainfire.eu/1220/SuperSU/SR5-SuperSU-v2.82-SR5-20171001224502.zip?retrieve_file=1"
	supersu_correct_size=6882992

	echo "Downloading SuperSU-v2.82-SR5"
	mkdir -p /tmp/aroc
	cd /tmp/aroc
	curl "$supersu_url" -o SuperSU.zip

	# Check filesize
	supersu_size=$(stat -c %s /tmp/aroc/SuperSU.zip)

	if [ "$supersu_size" = "$supersu_correct_size" ]; then
		echo "Unzipping SuperSU zip, and copying required directories to ~/Downloads."
		/usr/local/bin/busybox unzip SuperSU.zip
	else
		echo "Unexpected file size. Trying again..."
		curl "$supersu_url" -o SuperSU.zip
	fi

	# Check filesize again...
	supersu_size=$(stat -c %s /tmp/aroc/SuperSU.zip)

	if [ "$supersu_size" = "$supersu_correct_size" ]; then
		echo "Unzipping SuperSU zip, and copying required directories to ~/Downloads."
		/usr/local/bin/busybox unzip SuperSU.zip
	else
		echo "Unexpected file size again! You can manually download the SuperSU zip and extract its directories to ~/Downloads. Then run this script again."
		exit 1
	fi

# Copy the required files over to ~/Downloads

cp -r -a common /home/chronos/user/Downloads
  
if [ $ANDROID_ARCH=armv7 ]; then
  cp -r -a armv7 /home/chronos/user/Downloads
  else
    
  if [ $ANDROID_ARCH=x86 ]; then
    cp -r -a x86 /home/chronos/user/Downloads
    else
    echo "Error!"
    echo "Unable to detect correct architecture!"
    echo
    exit 1
    echo
  fi
  
fi

}

# The following two functions copy the (architecture-dependent) su binary to /system.
# For arm Chromebooks we need /armv7/su, but for Intel Chromebooks we need /x86/su.pie.

copy_su_armv7() {
  
echo "Copying su to system/xbin/su,daemonsu,sugote, and setting permissions and contexts"

cd $arc_system/xbin

  cp $SU_ARCHDIR/su $arc_system/xbin/su
  cp $SU_ARCHDIR/su $arc_system/xbin/daemonsu
  cp $SU_ARCHDIR/su $arc_system/xbin/sugote

  chmod 0755 $arc_system/xbin/su
  chmod 0755 $arc_system/xbin/daemonsu
  chmod 0755 $arc_system/xbin/sugote
  
  chown 655360 $arc_system/xbin/su
  chown 655360 $arc_system/xbin/daemonsu
  chown 655360 $arc_system/xbin/sugote
  
  chgrp 655360 $arc_system/xbin/su
  chgrp 655360 $arc_system/xbin/daemonsu
  chgrp 655360 $arc_system/xbin/sugote

  chcon u:object_r:system_file:s0 $arc_system/xbin/su
  chcon u:object_r:system_file:s0 $arc_system/xbin/daemonsu
  chcon u:object_r:zygote_exec:s0 $arc_system/xbin/sugote

sleep 0.2

echo "Creating directory system/bin/.ext/.su"

cd $arc_system/bin

  mkdir -p $arc_system/bin/.ext

echo "Copying su to system/bin/.ext/.su and setting permissions and contexts"

cd $arc_system/bin/.ext

  cp $SU_ARCHDIR/su $arc_system/bin/.ext/.su
  chmod 0755 $arc_system/bin/.ext/.su
  chcon u:object_r:system_file:s0 $arc_system/bin/.ext/.su
  chown 655360 $arc_system/bin/.ext/.su
  chgrp 655360 $arc_system/bin/.ext/.su

}

copy_su_x86() {

echo "Copying su to system/xbin/su,daemonsu,sugote, and setting permissions and contexts"

cd $arc_system/xbin

  cp $SU_ARCHDIR/su.pie $arc_system/xbin/su
  cp $SU_ARCHDIR/su.pie $arc_system/xbin/daemonsu
  cp $SU_ARCHDIR/su.pie $arc_system/xbin/sugote

  chmod 0755 $arc_system/xbin/su
  chmod 0755 $arc_system/xbin/daemonsu
  chmod 0755 $arc_system/xbin/sugote
  
  chown 655360 $arc_system/xbin/su
  chown 655360 $arc_system/xbin/daemonsu
  chown 655360 $arc_system/xbin/sugote
  
  chgrp 655360 $arc_system/xbin/su
  chgrp 655360 $arc_system/xbin/daemonsu
  chgrp 655360 $arc_system/xbin/sugote

  chcon u:object_r:system_file:s0 $arc_system/xbin/su
  chcon u:object_r:system_file:s0 $arc_system/xbin/daemonsu
  chcon u:object_r:zygote_exec:s0 $arc_system/xbin/sugote

sleep 0.2

echo "Creating directory system/bin/.ext/.su"

cd $arc_system/bin

  mkdir -p $arc_system/bin/.ext

echo "Copying su to system/bin/.ext/.su and setting permissions and contexts"

cd $arc_system/bin/.ext

  cp $SU_ARCHDIR/su.pie $arc_system/bin/.ext/.su
  chmod 0755 $arc_system/bin/.ext/.su
  chcon u:object_r:system_file:s0 $arc_system/bin/.ext/.su
  chown 655360 $arc_system/bin/.ext/.su
  chgrp 655360 $arc_system/bin/.ext/.su

}


copy_busybox()

{
   # If we downloaded Busybox earlier, we may as well copy it to /system/xbin (although we don't need to for the purpose of this script).
   
echo "Attempting to install BusyBox into Android container"

if [ -e /tmp/aroc/busybox ] ; then
  echo "Copying BusyBox to /system/xbin"
  cp  /tmp/aroc/busybox $arc_system/xbin
  chown 655360 $arc_system/xbin/busybox
  chgrp 655360 $arc_system/xbin/busybox
  chmod a+x $arc_system/xbin/busybox
  cd $arc_system/xbin/

  echo "Executing './busybox --install -s ../xbin'"
  ./busybox --install -s ../xbin
  echo "Replacing absolute symlinks created by 'busybox --install' with relative symlinks"
  find ../xbin -lname "*" -exec  sh -c 'ln -sfr busybox $0' {} \;

else

  if [ -e /usr/local/bin/busybox ] ; then
    cp  /usr/local/bin/busybox $arc_system/xbin
    chown 655360 $arc_system/xbin/busybox
    chgrp 655360 $arc_system/xbin/busybox
    chmod a+x $arc_system/xbin/busybox
    cd $arc_system/xbin/

    echo "Executing './busybox --install -s ../xbin'"
    ./busybox --install -s ../xbin
    echo "Replacing absolute symlinks created by 'busybox --install' with relative symlinks"
    find ../xbin -lname "*" -exec  sh -c 'ln -sfr busybox $0' {} \;
  fi

fi

}

# Functions (Part 2 - for patching SE Linux)

sepolicy_patch() {

# The sepolicy_patch has some of the same logic as the main script.
# It copies su etc. to a temp. directory and then bind mounts it.
# This is so we can patch selinux without having to reboot the Chromebook first.

copy_su_armv7_temp() {
  
echo "Copying su to /opt/google/containers/android/rootfs/android-data/data/adb/su/bin/su, and setting permissions and contexts"

cd $arc_system_temp/bin

  cp $SU_ARCHDIR/su $arc_system_temp/bin/su
  cp $SU_ARCHDIR/su $arc_system_temp/bin/daemonsu
  cp $SU_ARCHDIR/su $arc_system_temp/bin/sugote

  chmod 0755 $arc_system_temp/bin/su
  chmod 0755 $arc_system_temp/bin/daemonsu
  chmod 0755 $arc_system_temp/bin/sugote
  
  chown 655360 $arc_system_temp/bin/su
  chown 655360 $arc_system_temp/bin/daemonsu
  chown 655360 $arc_system_temp/bin/sugote
  
  chgrp 655360 $arc_system_temp/bin/su
  chgrp 655360 $arc_system_temp/bin/daemonsu
  chgrp 655360 $arc_system_temp/bin/sugote

  chcon u:object_r:system_file:s0 $arc_system_temp/bin/su
  chcon u:object_r:system_file:s0 $arc_system_temp/bin/daemonsu
  chcon u:object_r:zygote_exec:s0 $arc_system_temp/bin/sugote
  
}

copy_su_x86_temp() {

echo "Copying su to /opt/google/containers/android/rootfs/android-data/data/adb/su/bin/su, and setting permissions and contexts"

cd $arc_system_temp/bin

  cp $SU_ARCHDIR/su.pie $arc_system_temp/bin/su
  cp $SU_ARCHDIR/su.pie $arc_system_temp/bin/daemonsu
  cp $SU_ARCHDIR/su.pie $arc_system_temp/bin/sugote

  chmod 0755 $arc_system_temp/bin/su
  chmod 0755 $arc_system_temp/bin/daemonsu
  chmod 0755 $arc_system_temp/bin/sugote
  
  chown 655360 $arc_system_temp/bin/su
  chown 655360 $arc_system_temp/bin/daemonsu
  chown 655360 $arc_system_temp/bin/sugote
  
  chgrp 655360 $arc_system_temp/bin/su
  chgrp 655360 $arc_system_temp/bin/daemonsu
  chgrp 655360 $arc_system_temp/bin/sugote

  chcon u:object_r:system_file:s0 $arc_system_temp/bin/su
  chcon u:object_r:system_file:s0 $arc_system_temp/bin/daemonsu
  chcon u:object_r:zygote_exec:s0 $arc_system_temp/bin/sugote

}

# Check if the SuperSU 'common directory' is already present in ~/Downloads. If it doesn't, we will try to download it (and unzip it with BusyBox).
if [ ! -e /home/chronos/user/Downloads/common ]; then
  echo "SuperSU files not found in ~/Downloads! Attempting to download BusyBox and SuperSU now..."
  mkdir -p /tmp/aroc
  cd /tmp/aroc
  
  download_busybox
  download_supersu
  
fi

echo "Creating temporary directory /opt/google/containers/android/rootfs/android-data/data/adb/su and subdirs"

mkdir -p /opt/google/containers/android/rootfs/android-data/data/adb/su
mkdir -p /opt/google/containers/android/rootfs/android-data/data/adb/su/bin
mkdir -p /opt/google/containers/android/rootfs/android-data/data/adb/su/lib
mkdir -p /opt/google/containers/android/rootfs/android-data/data/adb/su/xbin

setenforce 0

#echo "Copying contents of existing /system/xbin and /system/lib"
echo "Copying contents of existing Android /system/lib to /opt/google/containers/android/rootfs/android-data/data/adb/su/lib"

cp -a -r /opt/google/containers/android/rootfs/root/system/lib/. /opt/google/containers/android/rootfs/android-data/data/adb/su/lib/.
#cp -a -r /opt/google/containers/android/rootfs/root/system/xbin/. /opt/google/containers/android/rootfs/android-data/data/adb/su/xbin/.
echo "Copying contents of existing Android /sbin to /opt/google/containers/android/rootfs/android-data/data/adb/su/bin"

cp -a -r /opt/google/containers/android/rootfs/root/sbin/. /opt/google/containers/android/rootfs/android-data/data/adb/su/bin/.

# Set the right directory from which to copy the su binary.

case "$ANDROID_ARCH" in
armv7)
SU_ARCHDIR=/home/chronos/user/Downloads/armv7
;;
esac

case "$ANDROID_ARCH" in
x86)
SU_ARCHDIR=/home/chronos/user/Downloads/x86
;;
esac

# If su doesn't appear to be present, try to download it.

if [ ! -e $SU_ARCHDIR ]; then
  download_busybox
  download_supersu
fi

common=/home/chronos/user/Downloads/common
arc_system_temp=/opt/google/containers/android/rootfs/android-data/data/adb/su

# For arm Chromebooks we need armv7/su, but for Intel we need x86/su.pie

case "$ANDROID_ARCH" in
armv7)
copy_su_armv7_temp
;;
esac

case "$ANDROID_ARCH" in
x86)
copy_su_x86_temp
;;
esac

echo "Copying supolicy to su/bin, libsupol to su/lib and setting permissions and contexts"

cd $arc_system_temp/bin

  cp $SU_ARCHDIR/supolicy $arc_system_temp/bin/supolicy

  chmod 0755 $arc_system_temp/bin/supolicy
  chown 655360 $arc_system_temp/bin/supolicy
  chgrp 655360 $arc_system_temp/bin/supolicy
  chcon u:object_r:system_file:s0 $arc_system_temp/bin/supolicy

cd $arc_system_temp/lib

  cp $SU_ARCHDIR/libsupol.so $arc_system_temp/lib/libsupol.so

  chmod 0644 $arc_system_temp/lib/libsupol.so
  chown 655360 $arc_system_temp/lib/libsupol.so
  chgrp 655360 $arc_system_temp/lib/libsupol.so
  chcon u:object_r:system_file:s0 $arc_system_temp/lib/libsupol.so
  
#echo "Temporarily bind mounting su/xbin and su/lib within the Android container."

echo "Attempting to bind mount temp dir /data/adb/su/bin to /sbin within the Android container."
printf "mount -o bind /data/adb/su/bin /sbin " | android-sh
echo "Attempting to bind mount temp dir /data/adb/su/lib to /system/lib within the Android container."
printf "mount -o bind /data/adb/su/lib /system/lib"  | android-sh

echo
echo "Any Android apps currently running may stop working now and may not function correctly until this script has completed and the system has been rebooted."

if [ ! -e /opt/google/containers/android/rootfs/android-data/data/adb/su/bin/su ]; then
  echo
  echo
  echo "Checking for the presence of SuperSU..."
  sleep 0.2
  echo
  echo "Error!"
  echo "SU binary not found! Unable to continue."
  echo
  exit 1

else
  echo
  if [ ! -e /etc/selinux/arc/policy/policy.30.old ]; then
    echo "Copying original policy.30 to /etc/selinux/arc/policy/policy.30.old"
    cp /etc/selinux/arc/policy/policy.30 /etc/selinux/arc/policy/policy.30.old
  fi
  if [ ! -e /usr/local/Backup/policy.30.old ]; then
    mkdir -p /usr/local/Backup
    echo "Copying original policy.30 to /usr/local/Backup/policy.30.old"
    cp /etc/selinux/arc/policy/policy.30 /usr/local/Backup/policy.30.old
  fi
  
  echo "Copying policy.30 to /home/chronos/user/Downloads/policy.30 to allow Android access to the file".

  cp -a /etc/selinux/arc/policy/policy.30 /home/chronos/user/Downloads/policy.30
  
  echo
  echo "Opening an Android shell and attempting to patch policy_30."
  sleep 0.2
  echo

  printf 'su -c supolicy --file /var/run/arc/sdcard/default/emulated/0/Download/policy.30 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out --sdk=25 \n su -c "chmod 0644 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out"' | android-sh
  
  if [ -e /home/chronos/user/Downloads/policy.30_out ]; then
    echo
    echo "Overwriting policy.30"
    echo "Copying patched policy from /home/chronos/user/Downloads/policy.30_out to /etc/selinux/arc/policy/policy.30"
    cp -a /home/chronos/user/Downloads/policy.30_out /etc/selinux/arc/policy/policy.30
    
    sleep 0.2
    echo "SE Linux policy patching completed!"
    
    echo "Rebooting the Android container"
    printf "reboot" | android-sh 2>/dev/null
    else
    echo
    echo "Error!"
    echo "Patched SE policy file not found! Unable to complete the procedure."
    echo
    echo "You may need to try running the separate patching script after a reboot."
    echo "Removing temporary directory /opt/google/containers/android/rootfs/android-data/data/adb/su"
    rm -rf /opt/google/containers/android/rootfs/android-data/data/adb/su
    exit 1
  fi

fi

echo
echo "Copying Android /sepolicy to /usr/local/Backup/sepolicy.old"
cp -a /usr/local/Android_Images/Mounted/sepolicy /usr/local/Backup/sepolicy.old
echo "Overwriting Android /sepolicy with patched policy.30"
cp -a /home/chronos/user/Downloads/policy.30_out /usr/local/Android_Images/Mounted/sepolicy
echo "Setting permissions and context for /sepolicy"
chown 655360  /usr/local/Android_Images/Mounted/sepolicy
chgrp 655360  /usr/local/Android_Images/Mounted/sepolicy
chcon  u:object_r:rootfs:s0 /usr/local/Android_Images/Mounted/sepolicy
echo "Removing temporary directory /opt/google/containers/android/rootfs/android-data/data/adb/su"
rm -rf /opt/google/containers/android/rootfs/android-data/data/adb/su

echo "Done!"

}

# Functions end

main() {

check_if_root

echo "Rooting scripts for Android on Chrome OS"
sleep 0.02
echo
echo "Version 0.26"
sleep 0.02
echo
echo "Unofficial scripts to copy SuperSU files to an Android system image on Chrome OS"
sleep 0.02
echo
echo "Be aware that modifying the system partition could cause automatic updates to fail (unlikely), may result in having to powerwash or restore from USB potentially causing loss of data! Please make sure important files are backed up."
sleep 0.02
echo

check_writeable_rootfs

# Remount the Chrome OS root drive as writeable

mount -o remount,rw / 2> /dev/null

# Modify the two/three envs in /etc/init

modify_cros_files

# Make a new writeable Android rootfs image, symlink it in place of the original, and copy our files to it.

# First, check if symlink already exists.

if [ -L /opt/google/containers/android/system.raw.img ]; then

  echo
  echo "WARNING: The file at /opt/google/containers/android/system.raw.img is already a symlink!"
  sleep 2
  echo
  echo "Should Android apps fail to load after this, restore the original container from backup and reboot before trying again."
  sleep 0.2
  echo "You can usually restore the original (stock) Android container from the backup by entering the following (all one line):"
  sleep 0.2
  echo
  echo "sudo mv /opt/google/containers/android/system.raw.img.bk /opt/google/containers/android/system.raw.img"
  sleep 0.2
  echo
  echo "Press Ctrl+C to cancel, if you want to do this now."
  sleep 3
  echo

# If the file is already a symlink, we need to check if a backup of the original system.raw.img exists.

  if [ ! -f /home/chronos/user/Downloads/system.raw.img ]; then
  
    if [ ! -f /opt/google/containers/android/system.raw.img.bk ]; then
      echo
      echo "Error!"
      echo "System.raw.img not found"
      echo
      exit 1
    fi
      
  fi
  
  echo "Removing symlink"
  rm -rf /opt/google/containers/android/system.raw.img
fi
  
if [ ! -e /opt/google/containers/android/system.raw.img ]; then

  if [ -f /opt/google/containers/android/system.raw.img.bk ]; then
    echo "Using /opt/google/containers/android/system.raw.img.bk"
  else
  
    if [ -f /home/chronos/user/Downloads/system.raw.img ]; then
      echo "Using /home/chronos/user/Downloads/system.raw.img"
    else
      echo
      echo "Error!"
      echo "System.raw.img not found"
      echo
      exit 1
    fi

  fi

fi

# Unmount any previous instances

umount -l /usr/local/Android_Images/system.raw.expanded.img 2>/dev/null
umount -l /usr/local/Android_Images/system.raw.expanded.img 2>/dev/null
umount -l /usr/local/Android_Images/Original 2>/dev/null
umount -l /usr/local/Android_Images/Mounted 2>/dev/null

detect_architecture

create_image

echo "Mounting system.raw.expanded.img"

if [ -e /opt/google/containers/android/system.raw.img ]; then
    
  if [ -L /opt/google/containers/android/system.raw.img ]; then
    
    if [ -e /opt/google/containers/android/system.raw.img.bk ]; then
      umount -l /usr/local/Android_Images/Original 2>/dev/null
      mount -o loop,rw,sync /opt/google/containers/android/system.raw.img.bk /usr/local/Android_Images/Original 2>/dev/null
    else
  
      if [ -e /home/chronos/user/Downloads/system.raw.img ]; then
        umount -l /usr/local/Android_Images/Original 2>/dev/null
        mount -o loop,rw,sync /home/chronos/user/Downloads/system.raw.img /usr/local/Android_Images/Original 2>/dev/null
      else
        echo
        echo "Error!"
        echo "System.raw.img not found"
        echo
        exit 1
      fi
        
    fi
    
  fi
    
fi
  
if [ ! -L /opt/google/containers/android/system.raw.img ]; then

  if [ -e /opt/google/containers/android/system.raw.img ]; then
    umount -l /usr/local/Android_Images/Original 2>/dev/null
    mount -o loop,rw,sync /opt/google/containers/android/system.raw.img /usr/local/Android_Images/Original 2>/dev/null
  else
  
    if [ -e /opt/google/containers/android/system.raw.img.bk ]; then
      umount -l /usr/local/Android_Images/Original 2>/dev/null
      mount -o loop,rw,sync /opt/google/containers/android/system.raw.img.bk /usr/local/Android_Images/Original 2>/dev/null
    else
      
      if [ -e /home/chronos/user/Downloads/system.raw.img ]; then
        echo "Mounting /home/chronos/user/Downloads/system.raw.img and copying files"
        umount -l /usr/local/Android_Images/Original 2>/dev/null
        mount -o loop,rw,sync /home/chronos/user/Downloads/system.raw.img /usr/local/Android_Images/Original 2>/dev/null
      else
        echo
        echo "Error!"
        echo "System.raw.img not found"
        echo
        exit 1
      fi
      
    fi
      
  fi
    
fi
        #ORIGINAL_ANDROID_ROOTFS=/opt/google/containers/android/rootfs/root
        ANDROID_ROOTFS=/usr/local/Android_Images/Original

# We want to set SELinux to 'Permissive' so we can copy rootfs files with their original contexts without encountering errors.
# At one point, the ability to 'setenforce' was removed in an OS update. (it was later restored in another update).

setenforce 0

# Check if it worked

SE=$(getenforce)

if SE="Permissive"; then

echo "SELinux successfully set to 'Permissive' temporarily"

echo "Copying Android system files"

mount -o loop,rw,sync /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/. /usr/local/Android_Images/Mounted
else

# In case we can't set SE Linux to 'Permissive', the following is a workaround to copy files with correct contexts in 'Enforcing' mode.

echo "Copying Android system files"

# We should be able to copy files/dirs, preserving original contexts, despite being in 'Enforcing' mode if we mount with -o fscontext.
# Directories to mount with special contexts:
    
          #u:object_r:cgroup:s0 acct
          #u:object_r:device:s0 dev
          #u:object_r:tmpfs:s0 mnt
          #u:object_r:oemfs:s0 oem
          #u:object_r:sysfs:s0 sys

mount -o loop,rw,sync,fscontext=u:object_r:cgroup:s0 /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/acct /usr/local/Android_Images/Mounted/acct

umount -l /usr/local/Android_Images/Mounted

mount -o loop,rw,sync,fscontext=u:object_r:device:s0 /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/dev /usr/local/Android_Images/Mounted/dev

umount -l /usr/local/Android_Images/Mounted

mount -o loop,rw,sync,fscontext=u:object_r:tmpfs:s0 system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/mnt /usr/local/Android_Images/Mounted/mnt

umount -l /usr/local/Android_Images/Mounted

mount -o loop,rw,sync,fscontext=u:object_r:oemfs:s0 /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/oem /usr/local/Android_Images/Mounted/oem

umount -l /usr/local/Android_Images/Mounted

mount -o loop,rw,sync,fscontext=u:object_r:sysfs:s0 /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/sys /usr/local/Android_Images/Mounted/sys

umount -l /usr/local/Android_Images/Mounted

mount -o loop,rw,sync /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/storage /usr/local/Android_Images/Mounted/storage

umount -l /usr/local/Android_Images/Mounted

# Copying rootfs files

mount -o loop,rw,sync,fscontext=u:object_r:rootfs:s0 /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/. /usr/local/Android_Images/Mounted

fi
# If we were copying files from the original Android rootfs, unmount it now we've finished..
if [  -f /opt/google/containers/android/system.raw.img ]; then
  umount -l /opt/google/containers/android/system.raw.img  > /dev/null 2>&1 || /bin/true
fi

# Unmount the new rootfs too, so we can mount it again without special context later
umount -l /usr/local/Android_Images/system.raw.expanded.img 2>/dev/null


# If the original rootfs exists, before replacing it with a symlink, make a backup.
# In the event of errors, re-running the script, or post-powerwash, the original may be restored by reversing the 'mv' command.
# i.e. mv /opt/google/containers/android/system.raw.img.bk  /opt/google/containers/android/system.raw.img.

if [ -e /opt/google/containers/android/system.raw.img ]; then

  if [ ! -L /opt/google/containers/android/system.raw.img ]; then
    echo "Moving original Android rootfs image to /opt/google/containers/android/system.raw.img.bk"
    mv /opt/google/containers/android/system.raw.img  /opt/google/containers/android/system.raw.img.bk
# Make the symlink from the original pathname to our writeable rootfs image
    echo "Replacing original Android rootfs image path with symlink to /usr/local/Android_Images/system.raw.expanded.img"
    ln  -s /usr/local/Android_Images/system.raw.expanded.img /opt/google/containers/android/system.raw.img
  fi
  
  else
  
  if [ -e /usr/local/Android_Images/system.raw.expanded.img ]; then
    echo "Creating symlink to /usr/local/Android_Images/system.raw.expanded.img at original Android rootfs image file path"
    ln  -s /usr/local/Android_Images/system.raw.expanded.img /opt/google/containers/android/system.raw.img
  fi
  
fi
# Check if the SuperSU 'common directory' is already present in ~/Downloads. If it doesn't, we will try to download it (and unzip it with BusyBox).
if [ ! -e /home/chronos/user/Downloads/common ]; then
  echo "SuperSU files not found in ~/Downloads! Attempting to download BusyBox and SuperSU now..."
  mkdir -p /tmp/aroc
  cd /tmp/aroc
  
  download_busybox
  download_supersu
fi

cd /usr/local/Android_Images
mkdir -p /usr/local/Android_Images/Mounted

# Mount our new Android rootfs

mount -o loop,rw,sync /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted 2>/dev/null

# Set the right directory from which to copy the su binary.

case "$ANDROID_ARCH" in
armv7)
SU_ARCHDIR=/home/chronos/user/Downloads/armv7
;;
esac

case "$ANDROID_ARCH" in
x86)
SU_ARCHDIR=/home/chronos/user/Downloads/x86
;;
esac
# In case the above doesn't exist, try to download it.

if [ ! -e $SU_ARCHDIR ]; then
  download_busybox
  download_supersu
fi
              common=/home/chronos/user/Downloads/common
              arc_system=/usr/local/Android_Images/Mounted/system
              #arc_system_original=/opt/google/containers/android/rootfs/root/system

echo "Now placing SuperSU files. Locations as indicated by the SuperSU update-binary script."
sleep 0.2
echo

# Copying SuperSU files to $arc_system
    
echo "Creating SuperSU directory in system/priv-app, copying SuperSU apk, and setting its permissions and contexts"

cd $arc_system/priv-app
  mkdir -p $arc_system/priv-app/SuperSU
  chown 655360 $arc_system/priv-app/SuperSU
  chgrp 655360 $arc_system/priv-app/SuperSU
  
cd $arc_system/priv-app/SuperSU
  cp $common/Superuser.apk $arc_system/priv-app/SuperSU/SuperSU.apk

  chmod 0644 $arc_system/priv-app/SuperSU/SuperSU.apk
  chcon u:object_r:system_file:s0 $arc_system/priv-app/SuperSU/SuperSU.apk
  chown 655360 $arc_system/priv-app/SuperSU/SuperSU.apk
  chgrp 655360 $arc_system/priv-app/SuperSU/SuperSU.apk

sleep 0.2

# For arm Chromebooks we need /armv7/su, but for for Intel we need /x86/su.pie

case "$ANDROID_ARCH" in
armv7)
copy_su_armv7
;;
esac

case "$ANDROID_ARCH" in
x86)
copy_su_x86
;;
esac

echo "Copying supolicy to system/xbin, libsupol to system/lib and setting permissions and contexts"

cd $arc_system/xbin

  cp $SU_ARCHDIR/supolicy $arc_system/xbin/supolicy

  chmod 0755 $arc_system/xbin/supolicy
  chown 655360 $arc_system/xbin/supolicy
  chgrp 655360 $arc_system/xbin/supolicy
  chcon u:object_r:system_file:s0 $arc_system/xbin/supolicy

cd $arc_system/lib

  cp $SU_ARCHDIR/libsupol.so $arc_system/lib/libsupol.so

  chmod 0644 $arc_system/lib/libsupol.so
  chown 655360 $arc_system/lib/libsupol.so
  chgrp 655360 $arc_system/lib/libsupol.so
  chcon u:object_r:system_file:s0 $arc_system/lib/libsupol.so
  
sleep 0.2

echo "Copying sh from system/bin/sh to system/xbin/sugote-mksh and setting permissions and contexts"

cd $arc_system/bin

  cp $arc_system/bin/sh ../xbin/sugote-mksh

cd $arc_system/xbin

  chmod 0755 $arc_system/xbin/sugote-mksh
  chcon u:object_r:system_file:s0 $arc_system/xbin/sugote-mksh
  
echo "Adding extra files system/etc/.installed_su_daemon and system/etc/install-recovery.sh"

cd $arc_system/etc

  touch  $arc_system/etc/.installed_su_daemon

  chmod 0644  $arc_system/etc/.installed_su_daemon
  chcon u:object_r:system_file:s0  $arc_system/etc/.installed_su_daemon

  cp $common/install-recovery.sh  $arc_system/etc/install-recovery.sh
  
  chmod 0755  $arc_system/etc/install-recovery.sh
  chown 655360 $arc_system/etc/install-recovery.sh
  chgrp 655360 $arc_system/etc/install-recovery.sh
  chcon u:object_r:toolbox_exec:s0  $arc_system/etc/install-recovery.sh

echo "Symlinking system/bin/install-recovery.sh to system/etc/install-recovery.sh"

  ln -s -r install-recovery.sh ../bin/install-recovery.sh
  
echo "Adding system/bin/daemonsu-service.sh"

cp $common/install-recovery.sh  $arc_system/bin/daemonsu-service.sh
  
chmod 0755  $arc_system/bin/daemonsu-service.sh
chown 655360 $arc_system/bin/daemonsu-service.sh
chgrp 657360 $arc_system/bin/daemonsu-service.sh

chcon u:object_r:toolbox_exec:s0  $arc_system/bin/daemonsu-service.sh

echo "Creating file init.super.rc in Android rootfs"

touch  $arc_system/../init.super.rc

chmod 0750 $arc_system/../init.super.rc
chown 655360 $arc_system/../init.super.rc
chgrp 657360 $arc_system/../init.super.rc

echo "Adding daemonsu service to init.super.rc"

echo "service daemonsu /system/bin/daemonsu-service.sh service
    class late_start
    user root
    seclabel u:r:supersu:s0
    oneshot" >>  $arc_system/../init.super.rc
    
echo "Adding 'import /init.super.rc' to existing init.rc"

sed -i '7iimport /init.super.rc' $arc_system/../init.rc

# SuperSU copying script ends

# In recent CrOS versions (v70+), for a writable /system, currently it also seems to be necessary to edit init.rc (to switch 'ro' to 'rw')

echo "Substituting '|mount rootfs rootfs / remount bind rw' for '|mount rootfs rootfs / remount bind ro' in existing init.rc"
echo "A backup of init.rc will be stored as init.rc.old"

sed -i.old 's|mount rootfs rootfs / remount bind ro|mount rootfs rootfs / remount bind rw|g' $arc_system/../init.rc

copy_busybox

echo

if  [ -d /opt/google/containers/android/rootfs/root/system ]; then

  echo "Now attempting to patch SE Linux."
  echo "If there is a problem with the next part of the script, run the separate patching script from GitHub after a reboot."
  echo
  
  sepolicy_patch

  echo "Removing temporary directory /tmp/aroc"
  rm -rf /tmp/aroc
  else
  echo "ERROR: No running Android system found. Unable to patch sepolicy."
fi

echo
echo "Please check the output of this script for any errors."
echo
echo "You will need to reboot the Chromebook in order to properly re-mount the new rooted Android container."
echo "Please do so now"

}

main "$@"
