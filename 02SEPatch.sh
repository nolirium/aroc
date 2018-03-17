#!/bin/sh -e

echo "Test Rooting scripts for Android on Chrome OS"
sleep 0.1
echo
echo "Version 0.25"
sleep 0.1
echo
echo "Unofficial scripts to copy SuperSU files to an Android system image on Chrome OS"
sleep 0.1
echo
echo "Part 2 of 2"
sleep 0.1
echo
echo "There is an SE Linux policy file located at /etc/selinux/arc/policy/policy.30, which can be patched with SuperSU's patching tool."
sleep 0.1
echo
echo "This script assists with the process."
sleep 0.1

if [ ! -e /opt/google/containers/android/rootfs/root/system/xbin/su ]; then
  echo
  echo
  echo "Checking for the presence of SuperSU..."
  sleep 1
  echo
  echo "Error!"
  echo "SU binary not found! Unable to continue."
  echo
  echo "You may need to retry script 01Root.sh and check its output for any errors. If you ran script 01Root.sh without rebooting, you do need to reboot before running this script."
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
  sleep 0.1
  echo
  echo
  
# Testing out sending the command via printf
  
  printf 'su -c supolicy --file /var/run/arc/sdcard/default/emulated/0/Download/policy.30 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out --sdk=25 \n su -c "chmod 0644 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out"' | android-sh
  
# Old version, requiring manual copy and paste, is commented out below.
  
#  echo "Copy and paste the following two su commands into the Android shell."
#  echo "Hit Enter after each one."
#  echo "If SuperSU is present, the first command should patch the file and display a message indicating this."
#  echo
#  echo "NOTE: If you are still running Android 6.0.1 (Marshmallow), change --sdk=25 to --sdk=23 at to the end of the first command."
#  sleep 2
#  echo
#  echo
#  echo
#  echo
#  echo "su -c "supolicy --file /var/run/arc/sdcard/default/emulated/0/Download/policy.30 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out --sdk=25""
#  echo
#  echo
#  echo "su -c "chmod 0644 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out""
#  echo
#  echo
#  echo
#  echo
#  echo "After copy/pasting the commands, leave the Android shell by typing:"
#  echo
#  echo "exit"
#  echo
#
#android-sh

  if [ -e /home/chronos/user/Downloads/policy.30_out ]; then
    echo
    echo "Overwriting policy.30"
    echo "Copying patched policy from /home/chronos/user/Downloads/policy.30_out to /etc/selinux/arc/policy/policy.30"
    cp -a /home/chronos/user/Downloads/policy.30_out /etc/selinux/arc/policy/policy.30
    echo "Setting SE Linux to 'Permissive' temporarily"
    setenforce 0
    echo "Copying Android /sepolicy to /usr/local/Backup/sepolicy.old"
    cp -a /opt/google/containers/android/rootfs/root/sepolicy /usr/local/Backup/sepolicy.old
    echo "Overwriting Android /sepolicy with patched policy.30"
    cp -a /home/chronos/user/Downloads/policy.30_out /opt/google/containers/android/rootfs/root/sepolicy
    echo "Setting permissions and context for /sepolicy"
    chown 655360  /opt/google/containers/android/rootfs/root/sepolicy
    chgrp 655360  /opt/google/containers/android/rootfs/root/sepolicy
    chcon  u:object_r:rootfs:s0 /opt/google/containers/android/rootfs/root/sepolicy

    sleep 0.1
    echo "Done!"
    echo "Please reboot now"
    else
    echo
    echo "Error!"
    echo "Patched SE policy file not found! Unable to complete the procedure."
    echo
    echo "You may need to retry script 01Root.sh and check its output for any errors."
    exit 1
  fi

fi
