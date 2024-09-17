#!/usr/bin/bash

source env.sh

make clean

framing_path=`pwd`
streaming_path="${framing_path}_streaming"
rm -rf ${streaming_path}
cp -r ${framing_path} ${streaming_path}

cd ${streaming_path}
sbatch ./scripts/synth.sh

cd ${framing_path}
sbatch ./scripts/synth.sh USE_FRAMING=1
