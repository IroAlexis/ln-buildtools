# Introduction

A set of scripts that make it easy to build Wine, DXVK and VKD3D-Proton from source code.


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

# Acknowledgements
* [TkG](https://github.com/Tk-Glitch)
