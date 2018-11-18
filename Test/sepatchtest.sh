#!/bin/sh

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
  
  printf 'su -c supolicy --file /var/run/arc/sdcard/default/emulated/0/Download/policy.30 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out --sdk=25 \n su -c "chmod 0644 /var/run/arc/sdcard/default/emulated/0/Download/policy.30_out"' | android-sh
  

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
    exit 1
  fi

