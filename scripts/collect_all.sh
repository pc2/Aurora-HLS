#!/usr/bin/bash

source env.sh

make clean

base_path=`pwd`

for mode in 0 1; do
    for width in 32; do
        path=${base_path}_${mode}_${width}
        cp ${path}/aurora_hls_test_hw.xclbin ${base_path}/aurora_hls_test_hw_${mode}_${width}.xclbin
    done
done
