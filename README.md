# QEMU builder helper repository

This repository helps in building QEMU and its dependencies. The Kalray KVX
port makes use of a Kalray specific dependency called LAO. A simple Makefile is
provided to perform the necessary steps for you.

## Requirements

Some dependencies must be installed on your system for QEMU to build. Also
ninja is recommended to build QEMU but `make` can be used as well. The LAO
library uses the CMake build system. On a Debian/Ubuntu-like system, you can
install the following packages:

```
apt install git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja cmake
```

## Customizing the installation

By default, QEMU will be installed in a local prefix (`./prefix`) in this
repository. You can change that by giving another prefix to the make command
(see bellow) or by editing the Makefile (e.g., if you wish to install it to
`/usr/local`).

## Building QEMU

Start by initializing the two submodules

```sh
$ git submodule update --init
```

Then simply run `make`.

```sh
$ make -j$(($(nproc) + 1))
```

To specify another installation prefix:

```sh
$ make -j$(($(nproc) + 1)) PREFIX=/some/path
```

At the end, you should have a `qemu-system-kvx` symbolic link pointing to the
QEMU executable in the prefix QEMU was installed in.
