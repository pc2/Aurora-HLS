# Aurora Emu Example

Minimal example to show how to use the Aurora emulator.
We send a vector to a kernel on a remote FPGA using Aurora and add calculate the sum with another vector.
The result is sent back to the local kernel.

This example code consists of two HLS kernels:

- `remote_vadd`: Retrieves data from the aurora core and adds data from a local vector to it. Writes the results back to the aurora core.
- `collector`: read data from a local vector and write it to the aurora core. Read data back from the aurora core and write it into a result vector.

## Build

The following dependencies have to be installed:

- Vitis HLS (for the AXI stream and ap_int header files)
- ZMQ
- CMake > 3.11

To build with cmake:

    mkdir build
    cd build
    cmake ..
    make

To execute the example:

    ./aurora_emu_example
