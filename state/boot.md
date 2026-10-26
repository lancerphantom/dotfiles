# Boot state — captured 2026-10-26T10:17:27+05:30

REFERENCE ONLY. UUIDs belong to this disk. Read to understand the
layout; do not paste into a fresh install.

## bootctl status
```
System:
      Firmware: UEFI 2.70 (American Megatrends 5.17)
 Firmware Arch: x64
   Secure Boot: enabled (user)
  TPM2 Support: yes
  Measured UKI: no
   Measured OS: no
  Boot into FW: supported
 Platform Lang: en_US.UTF-8

Current Boot Loader:
        Product: systemd-boot 260.1-2-arch
       Features: ✓ Boot counting
                 ✓ Menu timeout control
                 ✓ One-shot menu timeout control
                 ✓ Default entry control
                 ✓ One-shot entry control
                 ✓ Support for XBOOTLDR partition
                 ✓ Support for passing random seed to OS
                 ✓ Load drop-in drivers
                 ✓ Support Type #1 sort-key field
                 ✓ Support @saved pseudo-entry
                 ✓ Support Type #1 devicetree field
                 ✓ Enroll SecureBoot keys
                 ✓ Retain SHIM protocols
                 ✓ Menu can be disabled
                 ✓ Multi-Profile UKIs are supported
                 ✓ Loader reports network boot URL
                 ✓ Support Type #1 uki field
                 ✓ Support Type #1 uki-url field
                 ✓ Loader reports active TPM2 PCR banks
                 ✗ Loader reports firmware keyboard layout
                 ✗ Loader measures SMBIOS information
      Partition: /dev/disk/by-partuuid/3769304c-c250-4146-bec2-a645c3cd14f7
         Loader: └─/boot//EFI/SYSTEMD/SYSTEMD-BOOTX64.EFI
  Current Entry: arch-lts.conf

Random Seed:
 System Token: set
       Exists: yes

Available Boot Loaders on ESP:
          ESP: /boot (/dev/disk/by-partuuid/3769304c-c250-4146-bec2-a645c3cd14f7)
         File: ├─/boot//EFI/systemd/systemd-bootx64.efi (systemd-boot 260.1-2-arch)
               └─/boot//EFI/BOOT/BOOTX64.EFI (systemd-boot 260.1-2-arch)

Boot Loaders Listed in EFI Variables:
        Title: Windows Boot Manager
           ID: 0x0000
       Status: active, boot-order
    Partition: /dev/disk/by-partuuid/3769304c-c250-4146-bec2-a645c3cd14f7
         File: └─/boot//EFI/SYSTEMD/SYSTEMD-BOOTX64.EFI

        Title: UEFI OS
           ID: 0x0002
       Status: active, boot-order
    Partition: /dev/disk/by-partuuid/3769304c-c250-4146-bec2-a645c3cd14f7
         File: └─/boot//EFI/BOOT/BOOTX64.EFI

        Title: Windows Boot Manager
           ID: 0x0004
       Status: active, boot-order
    Partition: /dev/disk/by-partuuid/3769304c-c250-4146-bec2-a645c3cd14f7
         File: └─/boot//EFI/MICROSOFT/BOOT/BOOTMGFW.EFI

        Title: Windows Boot Manager
           ID: 0x0005
       Status: active, boot-order
    Partition: /dev/disk/by-partuuid/f083aec2-8e96-4cfc-b917-99f576ee2eff
         File: └─/boot//EFI/MICROSOFT/BOOT/BOOTMGFW.EFI

Boot Loader Entry Locations:
          ESP: /boot (/dev/disk/by-partuuid/3769304c-c250-4146-bec2-a645c3cd14f7, $BOOT)
       config: /boot//loader/loader.conf
        token: arch

Default Boot Loader Entry:
         type: Boot Loader Specification Type #1 (.conf)
        title: Arch Linux (LTS)
           id: arch-lts.conf
       source: /boot//loader/entries/arch-lts.conf (on the EFI System Partition)
        linux: /boot//vmlinuz-linux-lts
       initrd: /boot//initramfs-linux-lts.img
      options: root=UUID=6ff4c1e0-b71e-4dd7-8ce9-1ea36409f164 acpi_enforce_resources=lax
```

## boot entries
```
         type: Boot Loader Specification Type #1 (.conf)
        title: Arch Linux (LTS) (default) (selected)
           id: arch-lts.conf
       source: /boot//loader/entries/arch-lts.conf (on the EFI System Partition)
        linux: /boot//vmlinuz-linux-lts
       initrd: /boot//initramfs-linux-lts.img
      options: root=UUID=6ff4c1e0-b71e-4dd7-8ce9-1ea36409f164 acpi_enforce_resources=lax

         type: Automatic
        title: Windows Boot Manager
           id: auto-windows
       source: /sys/firmware/efi/efivars/LoaderEntries-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f (on the EFI System Partition)

         type: Automatic
        title: Reboot Into Firmware Interface
           id: auto-reboot-to-firmware-setup
       source: /sys/firmware/efi/efivars/LoaderEntries-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f (on the EFI System Partition)
```

## loader.conf
```
default arch-lts.conf
timeout 10
console-mode 0
```

## entries/
### arch-lts.conf
```
title Arch Linux (LTS)
linux /vmlinuz-linux-lts
initrd /initramfs-linux-lts.img
options root=UUID=6ff4c1e0-b71e-4dd7-8ce9-1ea36409f164 acpi_enforce_resources=lax
```

## secure boot
```
Installed:	✓ sbctl is installed
Owner GUID:	1f534610-d063-4219-bee6-1236bbded1b6
Setup Mode:	✓ Disabled
Secure Boot:	✓ Enabled
Vendor Keys:	microsoft

signed files:
```

## block devices
```
NAME        FSTYPE    FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sda                                                                                   
├─sda1                                                                                
├─sda2      BitLocker 2           35d4fbfc-af02-4909-9379-dcd09c0fc822                
└─sda3      ntfs                  F4EE1C05EE1BBEB4                                    
sdb                                                                                   
└─sdb1      ext4      1.0         c70b22b8-c90e-4f37-9cab-30b503f912af                
zram0       swap      1     zram0 b2f96faa-2280-49a2-9d33-e436ee763fff                [SWAP]
nvme0n1                                                                               
├─nvme0n1p1 vfat      FAT32       3341-F873                             688.6M    33% /boot
├─nvme0n1p2 ext4      1.0         6ff4c1e0-b71e-4dd7-8ce9-1ea36409f164    9.7G    75% /
└─nvme0n1p3 ext4      1.0         fe10fac0-c6cc-4d21-9711-8f8d020059aa  265.2G    65% /home
```

## mounts
```
TARGET  SOURCE         FSTYPE OPTIONS
/       /dev/nvme0n1p2 ext4   rw,relatime
├─/boot /dev/nvme0n1p1 vfat   rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro
└─/home /dev/nvme0n1p3 ext4   rw,relatime
```

## disk usage
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2   49G   37G  9.7G  80% /
devtmpfs        7.6G     0  7.6G   0% /dev
tmpfs           7.8G   37M  7.8G   1% /dev/shm
efivarfs        128K   53K   71K  43% /sys/firmware/efi/efivars
tmpfs           3.2G  1.9M  3.2G   1% /run
none            1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
none            1.0M     0  1.0M   0% /run/credentials/systemd-resolved.service
tmpfs           7.8G   24M  7.8G   1% /tmp
/dev/nvme0n1p1 1022M  334M  689M  33% /boot
/dev/nvme0n1p3  888G  578G  266G  69% /home
tmpfs           1.6G  124K  1.6G   1% /run/user/1000
none            1.0M  4.0K 1020K   1% /run/credentials/libvirtd.service
```

## fstab
```
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>

# /dev/nvme0n1p2
UUID=6ff4c1e0-b71e-4dd7-8ce9-1ea36409f164       /               ext4            rw,relatime     0 1

# /dev/nvme0n1p1
UUID=3341-F873          /boot           vfat            rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro   0 2

# /dev/nvme0n1p3
UUID=fe10fac0-c6cc-4d21-9711-8f8d020059aa       /home           ext4            rw,relatime     0 2


```

## mkinitcpio.conf
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block filesystems fsck)
```

## kernels
```
linux-lts 6.18.57-2
```

## dkms
```
nvidia/580.178.04, 6.18.57-2-lts, x86_64: installed
vboxhost/7.2.22_OSE, 6.18.57-2-lts, x86_64: installed
```
