# aroc
Android Root on ChromeOS - Chrome OS shell scripts to make a R/W copy of the Android container and copy su therein.

#### Note: The scripts have been tested on CrOS versions 54 - 72. Issues have been encountered with these scripts on a few older Chrome OS builds, but on most CrOS versions, everything *should* work as expected.

### Prerequisites

A Chrome OS device which supports Android Apps, with storage space for a ~2GB file in /usr/local.
The device must be in Developer Mode, and in addition, the Chrome OS system partition needs to have been made writeable (rootfs verification disabled).

A straightforward way to disable rootfs verification should be with either of the following two shell commands, followed by a reboot. 

Either:

`sudo /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification`

(and follow the on-screen prompt)

Or:

`sudo /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --partitions $(( $(rootdev -s | sed -r 's/.*(.)$/\1/') - 1))`


### Instructions

The scripts should be run, as root, in the following order:

01Root.sh

Reboot

02SEPatch.sh

Reboot again

Then open Play Store, Root Checker, Ad-Away, etc, etc.

The scripts may either be downloaded and ran locally, or via curl or wget e.g. 

`curl -Ls https://raw.githubusercontent.com/nolirium/aroc/master/01Root.sh | sudo sh`

Reboot

`curl -Ls https://raw.githubusercontent.com/nolirium/aroc/master/02SEPatch.sh | sudo sh`

Reboot again

----

#### NOTE: For convenience, there is now also a combined script, which executes the commands in the first script, then bind mounts a couple of directories within the Android container, then executes the commands in the second script. With the combined script, it is necessary to reboot once only, after the script has completed. 

To run the combined script:

`curl -Ls https://raw.githubusercontent.com/nolirium/aroc/onescript/RootandSEpatch.sh | sudo sh`

----

### Descriptions

#### 01Root.sh

Creates the directory /usr/local/Android_Images, formats a ~ 2GB sparse ext4 filesystem image in /usr/local/Android_Images therein, and copies the files from the factory shipped squashfs Android rootfs image to the new, writeable, image. Modifies Chrome OS system files in /etc/init - either arc-setup-env or arc-system-mount.conf and arc-setup.conf (as required) - changing the debuggable and mount-as-read-only flags. Renames the original filesystem image to .bk & replaces it with a symlink to the newly-created image. Mounts the freshly created writeable Android rootfs image, and copies SuperSU files to the mounted image as specified in the SuperSU update-binary (if the directories from within the SuperSU installer zip are not present in ~/Downloads, the script will attempt to download them).


#### 02SEpatch.sh

Copies an SELinux policy file found at /etc/selinux/arc/policy/policy.30 to ~/Downloads, opens an Android shell and attempts to patch the policy with SuperSU's 'supolicy' tool. If patching is successful, overwrites the original policy.30 with the patched version, and overwrites /sepolicy in the Android container with the patched policy.  Backup copies of the original policy.30 and /sepolicy are saved in /usr/local/Backup

Following successful execution of the above, the Android instance should be rooted and fully working.


#### Unroot.sh

If a backup Android image is present in its original directory, attempts to remove the symlink and restores the backup. Failing this, if a backup is present in in ~/Downloads, attempts to replace the modified image with the backup. Also attempts to return the debuggable and mount-as-read-only flags to their original configuration, and copy back the original policy.30.

### Known issues

##### IMPORTANT NOTE:  If you need to restore the original Android system image (for instance after a powerwash, or if the script didn't complete successfully), the easiest way to do this is to run the following command (then reboot) :

`sudo mv /opt/google/containers/android/system.raw.img.bk /opt/google/containers/android/system.raw.img`

Further information: The current version of the script replaces the original Android system image with a symlink. 
 After a powerwash, the modified files may remain so, and /usr/local may be empty. In this case, in order to have a functioning Android subsystem, it will be necessary to either manually restore the backup as above, run the Unroot.sh script, force an update e.g. with a channel change, or restore from USB/SD.
 
 Similarly, in order to revert to the original (unrooted) Android system if required, it will be necessary to either manually restore the backup, run the Unroot.sh script, force an update e.g. with a channel change, or restore from USB/SD.
  
 Updating the su binary from within the SuperSU GUI app may not work.

 Certain mods eg. Xposed are not compatible currently.

The modified system image takes up a fair amount of space in /usr/local. Storing the image in certain other places doesn't seem to work, probably due to mount/login timings.

Updates to the OS may break the procedure, and at the least may necessitate redoing all or part of it. 

On some older CrOS versions, certain non-English fonts may break after rooting. This should no longer occur on the latest OS version.
