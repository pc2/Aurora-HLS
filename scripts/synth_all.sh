#!/usr/bin/bash
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -q fpgasynthesis
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --mail-type=ALL

source env.sh

./scripts/synth.sh

# enable clean rebuild without deleting *.out
mv ip_creation ip_creation_streaming
mv aurora_hls_0_project aurora_hls_0_project_streaming
mv aurora_hls_1_project aurora_hls_1_project_streaming
mv _x_aurora_hls_hw _x_aurora_hls_hw_streaming
mv aurora_hls_test_hw.xclbin aurora_hls_test_hw_streaming.xclbin
mv aurora_hls_test_hw.xclbin.link_summary aurora_hls_test_hw_streaming.xclbin.link_summary
mv aurora_hls_0.xo aurora_hls_0_streaming.xo
mv aurora_hls_1.xo aurora_hls_1_streaming.xo
mv aurora_hls_0.xml aurora_hls_0_streaming.xml
mv aurora_hls_1.xml aurora_hls_1_streaming.xml

rm rtl/aurora_hls_define.v
rm rtl/aurora_hls_0.v
rm rtl/aurora_hls_1.v
rm -rf .ipcache
rm -rf .Xil

./scripts/synth.sh USE_FRAMING=1