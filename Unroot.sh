#!/bin/sh

echo "Uninstall script for Android root on ChromeOS"

sleep 2

echo
echo "This script will attempt to restore the original Android system.raw.img, if a backup is present."

sleep 1

echo
echo "If the string 'env WRITABLE_MOUNT=1' is found in either /etc/init/arc-setup-env or /etc/init/arc-setup.conf and /etc/init/arc-system-mount.conf, the script will attempt to change it to 'env WRITABLE_MOUNT=0'"
echo "Similarly, 'env ANDROID_DEBUGGABLE=1' to 'env ANDROID_DEBUGGABLE=0'."
echo
echo "If a backup of /etc/selinux/arc/policy/policy.30 is found, the script will attempt to restore it."

sleep 1

echo
echo

mount -o remount,rw /

if [ ! -f /home/chronos/user/Downloads/system.raw.img ]; then

  if [ ! -f /opt/google/containers/android/system.raw.img.bk ]; then
    echo "Backup system.raw.img not found! Are you sure you want to continue?"
  fi
  
fi

sleep 2

local i
      for i in $(seq 5 -1 1); do
        echo -n "\rStarting in $i second(s) Press Ctrl+C now to cancel...  " >&2
        sleep 1
      done

echo
echo
echo
echo

umount -l /opt/google/containers/android/system.raw.img 2>/dev/null

if [ -L /opt/google/containers/android/system.raw.img ]; then

  if [ -f /opt/google/containers/android/system.raw.img.bk ]; then
    echo "Removing symlink"
    rm /opt/google/containers/android/system.raw.img
    echo "Moving original system.raw.img back to /opt/google/containers/android/system.raw.img"
    mv /opt/google/containers/android/system.raw.img.bk /opt/google/containers/android/system.raw.img
  else

    if [ -f /home/chronos/user/Downloads/system.raw.img ]; then
      echo "Backup not found in original directory!"
      #echo "Removing symlink"
      #rm /opt/google/containers/android/system.raw.img
      echo "Copying system.raw.img from 'Downloads' to /usr/local/Android_Images/system.raw.expanded.img"
      cp /home/chronos/user/Downloads/system.raw.img /usr/local/Android_Images/system.raw.expanded.img
    else
      echo "Backup not found! To properly revert to the unrooted Android system image it may be necessary to update & powerwash, or restore from USB"
    fi
  
  fi

fi

echo "Attempting to set 'env WRITABLE_MOUNT=0', 'env ANDROID_DEBUGGABLE=0' and to restore the original policy.30."

if [ -f /etc/init/arc-system-mount.conf.old ]; then
  cp -a /etc/init/arc-system-mount.conf.old /etc/init/arc-system-mount.conf
fi

if [ -f /etc/init/arc-ureadahead.conf.old ]; then
  cp -a /etc/init/arc-ureadahead.conf.old /etc/init/arc-ureadahead.conf
fi
  
if [ -f /etc/init/android-ureadahead.conf.old ]; then
  cp -a /etc/init/android-ureadahead.conf.old /etc/init/android-ureadahead.conf
fi

if [ -f /etc/selinux/arc/policy/policy.30.old ]; then
  cp -a /etc/selinux/arc/policy/policy.30.old /etc/selinux/arc/policy/policy.30
  else
  if [ -f /usr/local/Backup/policy.30.old ]; then
    cp -a /usr/local/Backup/policy.30.old /etc/selinux/arc/policy/policy.30
  fi
fi

sed -i 's/env WRITABLE_MOUNT=1/env WRITABLE_MOUNT=0/g' /etc/init/arc-setup.conf 2 > /dev/null
sed -i 's/env WRITABLE_MOUNT=1/env WRITABLE_MOUNT=0/g' /etc/init/arc-system-mount.conf 2 > /dev/null
sed -i 's/env ANDROID_DEBUGGABLE=1/env ANDROID_DEBUGGABLE=0/g' /etc/init/arc-setup.conf 2 > /dev/null

sed -i 's/env WRITABLE_MOUNT=1/env WRITABLE_MOUNT=0/g' /etc/init/arc-setup-env 2 > /dev/null
sed -i 's/env ANDROID_DEBUGGABLE=1/env ANDROID_DEBUGGABLE=0/g' /etc/init/arc-setup-env 2 > /dev/null

echo

if [ -d /usr/local/Android_Images/ ]; then
  echo "Unmounting /usr/local/Android_Images/*"
  cd /usr/local/Android_Images/
  umount -l /usr/local/Android_Images/* 2>/dev/null
#echo "Removing /usr/local/Android_Images/"
#cd ..
#rm  -r /usr/local/Android_Images/
fi
#echo "Remounting original system image"
#umount  -l /opt/google/containers/android/rootfs/root 2>/dev/null
#mount -o rw,loop,noexec,nosuid,nodev /opt/google/containers/android/system.raw.img /opt/google/containers/android/rootfs/root
echo "Done!"
echo "It is advisable to reboot now."
