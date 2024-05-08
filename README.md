# Introduction

A set of scripts that make it easy to build Wine, DXVK and VKD3D-Proton from source code.

Based on [wine-tkg-git](https://github.com/Frogging-Family/wine-tkg-git)


# Wine
## Enable Damavand
```
export WINE_D3D_CONFIG="renderer=vulkan;VideoPciVendorID=0xc0de"
```

## Enable winewayland
```reg
[HKEY_CURRENT_USER\\Software\\Wine\\Drivers]
"Graphics"="wayland,x11"
```

## Enable fastsync
For enable fastsync, you need load NTsync module. For that you have to check if `ntsync.h` is present in `/usr/include/linux/ntsync.h` and/or `/usr/lib/modules/<kernel-linux>/build/include/uapi/linux/` then:
* Load ntsync module at boot: `echo "ntsync" >/etc/modules-load.d/ntsync.conf`
* Install udev rule for ntsync: `echo "KERNEL==\"ntsync\", MODE=\"0644\"" > /etc/udev/rules.d/ntsync.rules`
* Reboot and verify if device `ntsync` is loading in `/dev`


# Acknowledgements
* [TkG](https://github.com/Tk-Glitch)
