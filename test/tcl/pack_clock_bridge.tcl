#
# Copyright 2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# argv: <part> <src_dir> <build_dir>
set part      [lindex $argv 0]
set src_dir   [lindex $argv 1]
set build_dir [lindex $argv 2]

set ip_root ./aurora_flow_clock_bridge_ip
set ip_src  ${ip_root}/src

create_project aurora_flow_clock_bridge ./aurora_flow_clock_bridge -part $part

file mkdir ${ip_src}
file copy -force \
    ${build_dir}/rtl/clock_bridge/aurora_flow_clock_bridge_define.vh \
    ${ip_src}/aurora_flow_clock_bridge_define.vh

# aurora_flow_io.v is shared with the real AuroraFlow kernel and normally
# includes its generic generated header.  Stage a bridge-specific copy so the
# system-link project's common IP source directory cannot bind it to another
# kernel's aurora_flow_define.v.
set io_input [open ${src_dir}/rtl/aurora_flow_io.v r]
set io_source [read $io_input]
close $io_input
set generic_include {`include "aurora_flow_define.v"}
set bridge_include {`include "aurora_flow_clock_bridge_define.vh"}
set staged_io_source [string map [list $generic_include $bridge_include] $io_source]
if {$staged_io_source eq $io_source} {
    error "failed to replace the AuroraFlow header include in aurora_flow_io.v"
}
set io_output [open ${ip_src}/aurora_flow_clock_bridge_io.v w]
puts -nonewline $io_output $staged_io_source
close $io_output

add_files -norecurse -fileset sources_1 [list \
    ${ip_src}/aurora_flow_clock_bridge_define.vh \
    ${ip_src}/aurora_flow_clock_bridge_io.v \
    ${src_dir}/test/rtl/aurora_flow_clock_bridge.v \
    ${build_dir}/ip_creation/axis_data_fifo_clock_bridge_rx/axis_data_fifo_clock_bridge_rx.xci \
    ${build_dir}/ip_creation/axis_data_fifo_clock_bridge_tx/axis_data_fifo_clock_bridge_tx.xci \
    ${build_dir}/ip_creation/axis_dwidth_converter_clock_bridge_rx/axis_dwidth_converter_clock_bridge_rx.xci \
    ${build_dir}/ip_creation/axis_dwidth_converter_clock_bridge_tx/axis_dwidth_converter_clock_bridge_tx.xci \
]

set_property file_type {Verilog Header} \
    [get_files ${ip_src}/aurora_flow_clock_bridge_define.vh]
set_property include_dirs [list ${ip_src}] [get_filesets sources_1]
set_property top aurora_flow_clock_bridge [get_filesets sources_1]
update_compile_order -fileset sources_1

ipx::package_project \
    -root_dir ${ip_root} \
    -vendor xilinx.com \
    -library user \
    -taxonomy /UserIP \
    -import_files \
    -set_current true

ipx::infer_bus_interface ap_clk xilinx.com:signal:clock_rtl:1.0 \
    [ipx::current_core]
ipx::infer_bus_interface ap_rst_n xilinx.com:signal:reset_rtl:1.0 \
    [ipx::current_core]
ipx::infer_bus_interface ap_clk_2 xilinx.com:signal:clock_rtl:1.0 \
    [ipx::current_core]
ipx::infer_bus_interface ap_rst_n_2 xilinx.com:signal:reset_rtl:1.0 \
    [ipx::current_core]

foreach busif {hls_tx hls_rx aurora_tx aurora_rx} {
    if {[llength [ipx::get_bus_interfaces ${busif} \
            -of_objects [ipx::current_core]]] != 1} {
        error "failed to infer required AXI-Stream interface ${busif}"
    }
}

foreach busif {hls_tx hls_rx} {
    ipx::associate_bus_interfaces -busif ${busif} -clock ap_clk \
        [ipx::current_core]
}
foreach busif {aurora_tx aurora_rx} {
    ipx::associate_bus_interfaces -busif ${busif} -clock ap_clk_2 \
        [ipx::current_core]
}
# The link configuration owns the concrete 300/400 MHz clock values. Remove
# Vivado's inferred interface frequencies so they cannot conflict with those
# values while Vitis connects the kernels.
foreach busif {hls_tx hls_rx aurora_tx aurora_rx} {
    set axis_interface [ipx::get_bus_interfaces ${busif} \
        -of_objects [ipx::current_core]]
    if {[llength [ipx::get_bus_parameters FREQ_HZ \
            -of_objects $axis_interface]] != 0} {
        ipx::remove_bus_parameter FREQ_HZ $axis_interface
    }
}
ipx::associate_bus_interfaces -clock ap_clk -reset ap_rst_n \
    [ipx::current_core]
ipx::associate_bus_interfaces -clock ap_clk_2 -reset ap_rst_n_2 \
    [ipx::current_core]

set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]

ipx::update_source_project_archive -component [ipx::current_core]
ipx::save_core [ipx::current_core]

package_xo -force \
    -xo_path ${build_dir}/aurora_flow_clock_bridge.xo \
    -kernel_name aurora_flow_clock_bridge \
    -ctrl_protocol ap_ctrl_none \
    -ip_directory ${ip_root} \
    -output_kernel_xml ${build_dir}/aurora_flow_clock_bridge.xml
