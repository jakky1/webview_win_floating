# Building `webview_win_floating` on Linux

When using this package on Linux, there are a few important points to note.

The following instructions use the `Ubuntu Linux 25.0.4` environment as an example.

## DON't install Flutter SDK via apt / snap

When compiling an app that uses the webkit2gtk package, this Flutter SDK on `apt` will link to a newer version of glibc than the one on the system, which causes the following error message:
```
[ +189 ms] -- Checking for module 'webkit2gtk-4.1'
[   +6 ms] --   Package 'libsoup-3.0' requires 'glib-2.0 >= 2.69.1' but version of glib-2.0 is 2.64.6
```

So,
- Please uninstall the Flutter SDK installed by `apt-get` on the system.
- Download the [Flutter SDK](https://docs.flutter.dev/install/archive) from the official Flutter website, and set the environment variables.
  - set `PATH` environment to `<FlutterSDK>/bin`:
```bash
# add the following line to the end of `~/.bashrc`
FLUTTER_SDK_PATH=~/flutter  # for example
PATH=$PATH:$FLUTTER_SDK_PATH/bin
```


## Install building tools

For developers:
```
sudo apt install cmake ninja-build clang libstdc++-dev
```

## Install webkit2gtk

For developers:
```
sudo apt install libwebkit2gtk-4.1-dev
```

For people who use your app:
```
sudo apt install libwebkit2gtk-4.1
```

## Support video playback / Youtube

For developers and users, to install `gstreamer`:
```
sudo apt install gstreamer1.0-libav gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
```

### Hardware-acceleration for video playback

I believe that when installing the Ubuntu operating system, the installer automatically installs the corresponding packages based on your hardware configuration.

If you think hardware acceleration is not working, you might refer to the following list of packages.

For NVIDIA graphic card:
```
sudo apt install gstreamer1.0-vaapi nvidia-vaapi-driver
```

For AMD graphic card:
```
sudo apt install gstreamer1.0-vdpau vdpau-driver-all mesa-vdpau-drivers libvdpau-va-gl1
```

For Intel graphic card:
```
sudo apt install gstreamer1.0-vaapi
```