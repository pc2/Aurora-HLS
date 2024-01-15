#!/usr/bin/bash
ml fpga fpgainfo

fpgainfo | while read -r line; do
    if grep -q "xilinx" <<< $line; then
        if grep -q -v "RESERVED" <<< $line; then
            echo $line | cut -d ' ' -f 1
        fi
    fi
done