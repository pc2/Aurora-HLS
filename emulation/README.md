# Aurora Emulator based on ZMQ

This is a simple Aurora emulator based on ZMQ that allows emulation of desings using the Aurora cores on the CPU.


## Build

The following dependencies have to be installed:

- ZMQ
- CMake > 3.11

The following dependencies are downloaded automatically:

- hlslib
- cppzmq

optional dependencies:

- Vitis HLS (for the AXI stream and ap_int header files. Header-only repo will be used otherwise)

## How To

The emulator consist of two classes that communicate via TCP and are compatible with MPI:

- `AuroraEmuCore`: Emulated Aurora core that has to be connected to a `AuroraEmuSwitch` to route data.
- `AuroraEmuSwitch`: Used to connect `AuroraEmuCore`s and route the data to the specified destinations.

`hlslib::Stream` is used to emulate AXI streams.

```{c++}
// create AXI input and output streams for the aurora cores
hlslib::Stream<data_stream_t> in1("in1"), out1("out1"), in2("in2"),
    out2("out2");
// Create an aurora switch
auto s = AuroraEmuSwitch("127.0.0.1", 20000);
// create and connect core to switch and set own identifiers and 
// input and output streams
auto a1 = AuroraEmuCore("127.0.0.1", 20000, "a1", "a2", in1, out1);
```

The library is header only. To see how it can be used take a look into the `example` or `test` directories.
