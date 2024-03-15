# Aurora Emulation Tests

Unit tests to check the functionality of the Aurora emulator.

## Build

The following dependencies have to be installed:

- Vitis HLS (for the AXI stream and ap_int header files)
- ZMQ
- CMake > 3.11

The following dependencies are downloaded automatically:

- hlslib
- google_test


To build with cmake:

    mkdir build
    cd build
    cmake ..
    make

To execute the example:

    ./aurora_emu_test