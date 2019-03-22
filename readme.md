How to build
------

A C++ compiler that supports C++14 is required to build. For example:
- gcc >= 6.2
- clang >= 3.4

First download ispc:

    https://sourceforge.net/projects/ispcmirror/files/v1.10.0/ispc-v1.10.0-linux.tar.gz/download

Then extract it, add the `/bin` folder to the path, and do the following:

```
    mkdir build
    cd build
    cmake ..
    make
```
