#!/bin/sh

# Functions:

check_if_root() {

if [ $(id -u) != 0 ]; then
  echo
  echo "Error!"
  echo "This script should be run as root."
  exit 1
fi

}

check_writeable_rootfs() {

# TODO: Find a better way to do this, maybe.

# At present, we try and create a file on the CrOS rootfs to test if rootfs verification is disabled.

touch "/.this"  2> /dev/null

# If we couldn't create the file, rootfs verification likely still needs to be turned off.

if [ ! -e /.this ]; then
  echo
  echo "Error!"
  echo "Unable to modify system!"
  echo
  echo
  echo "In order to modify system files, the Chrome OS system partition needs to have been mounted writeable (i.e. rootfs verification disabled)."
  echo
  echo
  echo "You can disable rootfs verification by running the following command, then rebooting."
  echo
  echo
  echo
  echo
  echo "sudo /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --partitions $(( $(rootdev -s | sed -r 's/.*(.)$/\1/') - 1))"
  sleep 0.1
  echo
  echo
  echo
  echo
  echo "Alternatively, run the command below, then follow the prompt."
  echo
  echo
  echo "sudo /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification"
  sleep 0.1
  echo
  echo
  echo "Please run the "remove_rootfs_verification" command now, then reboot and run this script again."
  exit 1
fi

rm /.this

}

modify_cros_files() {

# Just changing two/three environment variables for Android in /etc/init here.
# Recent versions of CrOS have Android envs in arc-setup-env.
# Older versions had envs in the .conf files

mkdir -p /usr/local/Backup

if [ -e /etc/init/arc-setup-env ]; then
  echo "Copying /etc/init/arc-setup-env to /usr/local/Backup"
  
  sleep 0.1

  echo "Setting 'export WRITABLE_MOUNT=1', 'export ANDROID_DEBUGGABLE=1' and (if variable exists) 'export SHARE_FONTS=0' in /etc/init/arc-setup-env"
  
  sed -i 's/export WRITABLE_MOUNT=0/export WRITABLE_MOUNT=1/g' /etc/init/arc-setup-env 2>/dev/null
  sed -i 's/export ANDROID_DEBUGGABLE=0/export ANDROID_DEBUGGABLE=1/g' /etc/init/arc-setup-env 2>/dev/null
  sed -i 's/export SHARE_FONTS=1/export SHARE_FONTS=0/g' /etc/init/arc-setup-env 2>/dev/null

else
  echo "Copying /etc/init/arc-setup.conf and /etc/init/arc-system-mount.conf to /usr/local/Backup"

  sleep 0.1

  echo "Setting 'env WRITABLE_MOUNT=1' in /etc/init/arc-setup.conf and /etc/init/arc-system-mount.conf"

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

create_image() {

# This creates a blank ext4 image, formats and converts to sparse.

# Make some working directories if they don't already exist.

mkdir -p /usr/local/Android_Images
mkdir -p /usr/local/Android_Images/Mounted
mkdir -p /usr/local/Android_Images/Original

echo "Creating new Android system image at /usr/local/Android_Images/system.raw.expanded.img"
echo
echo

# Make the image.
# For arm, the unsquashed image needs to be at least ~1.3GB (~800MB for Marshmallow).
# For x86, the unsquashed image needs to be at least ~1.8GB (~1GB for Marshmallow).
# And for x86-64 containers (e,g, PixelBook), it apparently needs to be somewhat larger still.

# Since the raw rootfs has increased in size lately, create a blank sparse 2GB image, which should takes only as much space on disk as required.

if [ $ANDROID_ARCH=armv7 ]; then
  cd /usr/local/Android_Images
  dd if=/dev/zero of=system.raw.expanded.img count=1800000 bs=1024 status=progress
  else

  if [ $ANDROID_ARCH=x86 ]; then
    cd /usr/local/Android_Images
    dd if=/dev/zero of=system.raw.expanded.img count=2200000 bs=1024 status=progress

    else
    echo "Error!"
    echo "Unable to detect correct architecture!"
    echo
    exit 1
  fi

fi

echo
echo "Formatting system.raw.expanded.img as ext4 filesystem"
echo

mkfs ext4 -F /usr/local/Android_Images/system.raw.expanded.img

echo "Converting system.raw.expanded.img to sparse image"

fallocate -d /usr/local/Android_Images/system.raw.expanded.img

}

download_busybox () {
  
# Since there doesn't appear to be a built-in zip uncompresser available on the command line, if we need to download SuperSU,
# we download BusyBox in order to unzip it. We could also install BusyBox in Android w/ its symlinks later, if we want.

if [ ! -e /usr/local/bin/busybox ]; then
  echo "Downloading BusyBox"
  mkdir -p /tmp/aroc
  cd /tmp/aroc

  if [ $ANDROID_ARCH=armv7 ]; then
   curl https://busybox.net/downloads/binaries/1.26.2-defconfig-multiarch/busybox-armv6l -o busybox
  else
  
   if [ ANDROID_ARCH=x86 ]; then

# Commenting out the x64 Intel version for now as most x64 systems still seem to use a 32 bit Android container.
# So if we use the 32 bit BusyBox here, copying it to Android should also work on all machines.
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

echo "Downloading SuperSU-v2.82-SR3"
mkdir -p /tmp/aroc
cd /tmp/aroc
curl https://download.chainfire.eu/1122/SuperSU/SR3-SuperSU-v2.82-SR3-20170813133244.zip?retrieve_file=1 -o SuperSU.zip

# Check filesize

supersu_size=$(stat -c %s /tmp/aroc/SuperSU.zip)

if [ $supersu_size = 6918737 ]; then
  echo "Unzipping SuperSU zip, and copying required directories to ~/Downloads."
  /usr/local/bin/busybox unzip SuperSU.zip
  else
  echo "Unexpected file size. Trying again..."
  curl https://download.chainfire.eu/1122/SuperSU/SR3-SuperSU-v2.82-SR3-20170813133244.zip?retrieve_file=1 -o SuperSU.zip
fi

# Check filesize again...

supersu_size=$(stat -c %s /tmp/aroc/SuperSU.zip)

if [ $supersu_size = 6918737 ]; then
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

# The following two functions simply copy the architecture-dependent su binary to /system.
# For arm Chromebooks we need /armv7/su, but for Intel Chromebooks we need /x86/su.pie 

copy_su_armv7() {
  
echo "Copying su to system/xbin/su,daemonsu,sugote, and setting permissions and contexts"

cd $system/xbin

  cp $SU_ARCHDIR/su $system/xbin/su
  cp $SU_ARCHDIR/su $system/xbin/daemonsu
  cp $SU_ARCHDIR/su $system/xbin/sugote

  chmod 0755 $system/xbin/su
  chmod 0755 $system/xbin/daemonsu
  chmod 0755 $system/xbin/sugote
  
  chown 655360 $system/xbin/su
  chown 655360 $system/xbin/daemonsu
  chown 655360 $system/xbin/sugote
  
  chgrp 655360 $system/xbin/su
  chgrp 655360 $system/xbin/daemonsu
  chgrp 655360 $system/xbin/sugote

  chcon u:object_r:system_file:s0 $system/xbin/su
  chcon u:object_r:system_file:s0 $system/xbin/daemonsu
  chcon u:object_r:zygote_exec:s0 $system/xbin/sugote

sleep 0.1

echo "Creating directory system/bin/.ext/.su"

cd $system/bin

  mkdir -p $system/bin/.ext

echo "Copying su to system/bin/.ext/.su and setting permissions and contexts"

cd $system/bin/.ext

  cp $SU_ARCHDIR/su $system/bin/.ext/.su
  chmod 0755 $system/bin/.ext/.su
  chcon u:object_r:system_file:s0 $system/bin/.ext/.su
  chown 655360 $system/bin/.ext/.su
  chgrp 655360 $system/bin/.ext/.su

sleep 0.1

}

copy_su_x86() {

echo "Copying su to system/xbin/su,daemonsu,sugote, and setting permissions and contexts"

cd $system/xbin

  cp $SU_ARCHDIR/su.pie $system/xbin/su
  cp $SU_ARCHDIR/su.pie $system/xbin/daemonsu
  cp $SU_ARCHDIR/su.pie $system/xbin/sugote

  chmod 0755 $system/xbin/su
  chmod 0755 $system/xbin/daemonsu
  chmod 0755 $system/xbin/sugote
  
  chown 655360 $system/xbin/su
  chown 655360 $system/xbin/daemonsu
  chown 655360 $system/xbin/sugote
  
  chgrp 655360 $system/xbin/su
  chgrp 655360 $system/xbin/daemonsu
  chgrp 655360 $system/xbin/sugote

  chcon u:object_r:system_file:s0 $system/xbin/su
  chcon u:object_r:system_file:s0 $system/xbin/daemonsu
  chcon u:object_r:zygote_exec:s0 $system/xbin/sugote

sleep 0.1

echo "Creating directory system/bin/.ext/.su"

cd $system/bin

  mkdir -p $system/bin/.ext

echo "Copying su to system/bin/.ext/.su and setting permissions and contexts"

cd $system/bin/.ext

  cp $SU_ARCHDIR/su.pie $system/bin/.ext/.su
  chmod 0755 $system/bin/.ext/.su
  chcon u:object_r:system_file:s0 $system/bin/.ext/.su
  chown 655360 $system/bin/.ext/.su
  chgrp 655360 $system/bin/.ext/.su

}

# Functions end

main() {

check_if_root

echo "Test Rooting scripts for Android on Chrome OS"
sleep 0.1
echo
echo "Version 0.25"
sleep 0.1
echo
echo "Unofficial scripts to copy SuperSU files to an Android system image on Chrome OS"
sleep 0.1
echo
echo "Part 1 of 2"
sleep 0.1
echo

echo "Be aware that modifying the system partition could cause automatic updates to fail (unlikely), may result in having to powerwash or restore from USB potentially causing loss of data! Please make sure important files are backed up."
echo 

# Remount the Chrome OS root drive as writeable

mount -o remount,rw / 2> /dev/null

check_writeable_rootfs

# Modify the two/three envs in /etc/init

modify_cros_files

# Make our new writeable Android rootfs image, symlink it in place of the original, and copy our files to it.

# First, check if symlink already exists.

if [ -L /opt/google/containers/android/system.raw.img ]; then
  echo "The file at /opt/google/containers/android/system.raw.img is already a symlink!"

# If the file is already a symlink, we need to check if a backup of the original system.raw.img exists

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

# In case the backup has been deleted from its usual place (e.g. to save space), check if one is present in ~/Downloads.

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

# Check if setenforce worked

SE=$(getenforce)
if SE="Permissive"
then

echo "SELinux successfully set to 'Permissive' temporarily"

echo "Copying Android system files"

mount -o loop,rw,sync /usr/local/Android_Images/system.raw.expanded.img /usr/local/Android_Images/Mounted

cp -a -r $ANDROID_ROOTFS/. /usr/local/Android_Images/Mounted

else

# In case we can't set SE Linux to 'Permissive', the following is a workaround to copy files with correct contexts in 'Enforcing' mode.

echo "Copying Android system files"

# We should be able to copy files/dirs in 'Enforcing' mode by mounting with -o fscontext.
# Directories mounted with special contexts:
    
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
# If we were copying files from the original Android rootfs, unmount it now we've finished.

if [  -f /opt/google/containers/android/system.raw.img ]; then
  umount -l /opt/google/containers/android/system.raw.img  > /dev/null 2>&1 || /bin/true
fi

# Unmount the new rootfs too, so we can mount it again without special context later.

umount -l /usr/local/Android_Images/system.raw.expanded.img 2>/dev/null

# The commented-out backup below seems unnecessary now, since we will mv the original file to *.bk in place,
# plus it takes up too much space, especially since the Nougat filesize increase.

# if [ -e /opt/google/containers/android/system.raw.img ]; then
  
#  if [ ! -L /opt/google/containers/android/system.raw.img ]; then
#    echo "Copying original rootfs image to /home/chronos/user/Downloads/system.raw.img as a backup."
#    cp -a /opt/google/containers/android/system.raw.img /home/chronos/user/Downloads/system.raw.img
#  fi
 
#fi

# If the original rootfs exists, before replacing it with a symlink, make a backup.
# In the event of errors, re-running the script, or post-powerwash, the original may be restored by reversing the 'mv' command.
# i.e. mv /opt/google/containers/android/system.raw.img.bk  /opt/google/containers/android/system.raw.img.

if [ -e /opt/google/containers/android/system.raw.img ]; then

  if [ ! -L /opt/google/containers/android/system.raw.img ]; then
    echo "Moving original rootfs image to /opt/google/containers/android/system.raw.img.bk"
    mv /opt/google/containers/android/system.raw.img  /opt/google/containers/android/system.raw.img.bk
    
# Make the symlink from the original pathname to our writeable rootfs image

    echo "Creating symlink to /usr/local/Android_Images/system.raw.expanded.img"
    ln  -s /usr/local/Android_Images/system.raw.expanded.img /opt/google/containers/android/system.raw.img
  fi
  
  else
  
  if [ -e /usr/local/Android_Images/system.raw.expanded.img ]; then
    echo "Creating symlink to /usr/local/Android_Images/system.raw.expanded.img"
    ln  -s /usr/local/Android_Images/system.raw.expanded.img /opt/google/containers/android/system.raw.img
  fi
  
fi
# Check if the SuperSU 'common directory' is already present in ~/Downloads. If not, we will try to download it (and unzip it with BusyBox).

if [ ! -e /home/chronos/user/Downloads/common ]; then
  echo "SuperSU files not found in ~/Downloads! Attempting to download BusyBox and SuperSU now..."
  mkdir -p /tmp/aroc
  cd /tmp/aroc
  
  download_busybox
  
  download_supersu
  
fi

sleep 0.1

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
              system=/usr/local/Android_Images/Mounted/system
              #system_original=/opt/google/containers/android/rootfs/root/system

#if [ $ANDROID_ARCH=armv7 ]; then
#              SU_ARCHDIR=/home/chronos/user/Downloads/armv7
#  else
#              SU_ARCHDIR=/home/chronos/user/Downloads/x86
#fi

# If we downloaded Busybox earlier, we may as well copy it to /system (although we don't need to).

if [ -e /tmp/aroc/busybox ]; then
  echo "Copying BusyBox to /system/xbin"
  cp  /tmp/aroc/busybox $system/xbin
  chown 655360 $system/xbin/busybox
  chgrp 655360 $system/xbin/busybox
  chmod a+x $system/xbin/busybox
fi

echo "Now placing SuperSU files. Locations as indicated by the SuperSU update-binary script."

sleep 0.1

echo

# Copy SuperSU files to $system
    
echo "Creating SuperSU directory in system/priv-app, copying SuperSU apk, and setting its permissions and contexts"

cd $system/priv-app
  mkdir -p $system/priv-app/SuperSU
  chown 655360 $system/priv-app/SuperSU
  chgrp 655360 $system/priv-app/SuperSU
  
cd $system/priv-app/SuperSU
  cp $common/Superuser.apk $system/priv-app/SuperSU/SuperSU.apk

  chmod 0644 $system/priv-app/SuperSU/SuperSU.apk
  chcon u:object_r:system_file:s0 $system/priv-app/SuperSU/SuperSU.apk
  chown 655360 $system/priv-app/SuperSU/SuperSU.apk
  chgrp 655360 $system/priv-app/SuperSU/SuperSU.apk

sleep 0.1

# For arm Chromebooks we need /armv7/su, but for for Intel Chromebooks we need /x86/su.pie

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

cd $system/xbin

  cp $SU_ARCHDIR/supolicy $system/xbin/supolicy

  chmod 0755 $system/xbin/supolicy
  chown 655360 $system/xbin/supolicy
  chgrp 655360 $system/xbin/supolicy
  chcon u:object_r:system_file:s0 $system/xbin/supolicy

cd $system/lib

  cp $SU_ARCHDIR/libsupol.so $system/lib/libsupol.so

  chmod 0644 $system/lib/libsupol.so
  chown 655360 $system/lib/libsupol.so
  chgrp 655360 $system/lib/libsupol.so
  chcon u:object_r:system_file:s0 $system/lib/libsupol.so
  
sleep 0.1

echo "Copying sh from system/bin/sh to system/xbin/sugote-mksh and setting permissions and contexts"

cd $system/bin

  cp $system/bin/sh ../xbin/sugote-mksh

cd $system/xbin

  chmod 0755 $system/xbin/sugote-mksh
  chcon u:object_r:system_file:s0 $system/xbin/sugote-mksh
  
# Hijacking app_process (below) worked on Marshmallow. Does not aooear to work on N.
# One approach that does work on Nougat: modifying init.*.rc instead.
  
#echo "Moving app_process32"

#cd $system/bin/

#  cp app_process32 $system/bin/app_process32_original
#  chmod 0755 $system/bin/app_process32_original
#  chcon u:object_r:zygote_exec:s0 $system/bin/app_process32_original

#  cp $system/bin/app_process32 $system/bin/app_process_init

#chmod 0755 $system/bin/app_process_init
#chcon u:object_r:system_file:s0 $system/bin/app_process_init

#sleep 1

#echo "Deleting original app_process, app_process32"

#  rm $system/bin/app_process
#  rm $system/bin/app_process32

#sleep 1

#echo "Symlinking app_process, app_process32 to system/xbin/daemonsu"

#cd $system/xbin

#  ln -s -r daemonsu ../bin/app_process
#  ln -s -r daemonsu ../bin/app_process32

#sleep 1

echo "Adding extra files system/etc/.installed_su_daemon and system/etc/install-recovery.sh"

cd $system/etc

  touch  $system/etc/.installed_su_daemon

  chmod 0644  $system/etc/.installed_su_daemon
  chcon u:object_r:system_file:s0  $system/etc/.installed_su_daemon

  cp $common/install-recovery.sh  $system/etc/install-recovery.sh
  
  chmod 0755  $system/etc/install-recovery.sh
  chown 655360 $system/etc/install-recovery.sh
  chgrp 655360 $system/etc/install-recovery.sh
  chcon u:object_r:toolbox_exec:s0  $system/etc/install-recovery.sh

echo "Symlinking system/bin/install-recovery.sh to system/etc/install-recovery.sh"

  ln -s -r install-recovery.sh ../bin/install-recovery.sh
  
echo "Adding system/bin/daemonsu-service.sh"

cp $common/install-recovery.sh  $system/bin/daemonsu-service.sh
  
chmod 0755  $system/bin/daemonsu-service.sh
chown 655360 $system/bin/daemonsu-service.sh
chgrp 657360 $system/bin/daemonsu-service.sh

chcon u:object_r:toolbox_exec:s0  $system/bin/daemonsu-service.sh

echo "Creating file init.super.rc in Android rootfs"

touch  $system/../init.super.rc

chmod 0750 $system/../init.super.rc
chown 655360 $system/../init.super.rc
chgrp 657360 $system/../init.super.rc

echo "Adding daemonsu service to init.super.rc"

echo "service daemonsu /system/bin/daemonsu-service.sh service
    class late_start
    user root
    seclabel u:r:supersu:s0
    oneshot" >>  $system/../init.super.rc
    
echo "Adding 'import /init.super.rc' to existing init.rc"

sed -i '7iimport /init.super.rc' $system/../init.rc

# SuperSU copying script ends

echo "Removing temporary files"
rm -rf /tmp/aroc
echo
echo "Done!"
echo
echo "Please check the output of this script for any errors."

sleep 0.1

echo
echo "Please reboot now, then run script 02SEPatch.sh."

}

main "$@"
