#
# Copyright 2022 Xilinx, Inc.
#           2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
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
#

# hw_emu variant: GT transceiver replaced with DPI-C pipe stub

##################################### Step 1: create vivado project and add design sources

# argv layout: <part> <instance> <src_dir> <build_dir> <clock_count> <interface_clock_id>
set part      [lindex $argv 0]
set instance  [lindex $argv 1]
set src_dir   [lindex $argv 2]
set build_dir [lindex $argv 3]
set clock_count [lindex $argv 4]
set interface_clock_id [lindex $argv 5]
if {$clock_count ni {1 2}} {
    error "clock_count must be 1 or 2"
}
if {$interface_clock_id ni {0 1}} {
    error "interface_clock_id must be 0 or 1"
}
if {$clock_count == 1 && $interface_clock_id != 0} {
    error "interface_clock_id 1 requires clock_count 2"
}
set ip_root   ./aurora_flow_ip_${instance}
set ip_src    ${ip_root}/src

create_project aurora_flow_${instance} ./aurora_flow_${instance} -part $part

file mkdir ${ip_src}
file copy -force ${build_dir}/rtl/hw_emu/aurora_flow_define.v ${ip_src}/aurora_flow_define.v
file copy -force ${build_dir}/rtl/hw_emu/aurora_flow_${instance}.v \
    ${ip_src}/aurora_flow_${instance}.v

add_files -norecurse -fileset sources_1 \
       [list                                          \
              ${ip_src}/aurora_flow_define.v \
              ${src_dir}/rtl/aurora_flow_control_s_axi.v \
              ${ip_src}/aurora_flow_${instance}.v \
              ${src_dir}/rtl/aurora_flow_io.v \
              ${src_dir}/rtl/aurora_flow_nfc.v \
              ${src_dir}/rtl/aurora_flow_configuration.v \
              ${src_dir}/rtl/aurora_flow_monitor.v \
              ${src_dir}/rtl/aurora_flow_gt_stub.sv \
              ${build_dir}/ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci \
              ${build_dir}/ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci \
              ${build_dir}/ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci \
              ${build_dir}/ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci \
]

# make `include "aurora_flow_define.v" resolve to the hw_emu variant
set_property file_type {Verilog Header} \
    [get_files ${ip_src}/aurora_flow_define.v]
set_property include_dirs [list ${ip_src}] [get_filesets sources_1]
set_property top aurora_flow_${instance} [get_filesets sources_1]

update_compile_order -fileset sources_1

ipx::package_project -root_dir ./aurora_flow_ip_${instance} -vendor xilinx.com -library user -taxonomy /UserIP -import_files -set_current true

set required_clock_ports {ap_clk ap_rst_n}
if {$clock_count == 2} {
    lappend required_clock_ports ap_clk_2 ap_rst_n_2
}
foreach port $required_clock_ports {
    if {[llength [ipx::get_ports $port -of_objects [ipx::current_core]]] != 1} {
        error "top module aurora_flow_${instance} is missing required port $port"
    }
}

# Infer clock and reset interfaces.
ipx::infer_bus_interface ap_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface ap_rst_n xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

if {$clock_count == 2} {
    # Vitis 2023.2 two-clock RTL-kernel convention. These exact port names map
    # to scalable clock ID 1 and its reset.
    ipx::infer_bus_interface ap_clk_2 xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
    ipx::infer_bus_interface ap_rst_n_2 xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
}

ipx::associate_bus_interfaces -clock ap_clk -reset ap_rst_n [ipx::current_core]
if {$interface_clock_id == 1} {
    set interface_clock ap_clk_2
    set interface_reset ap_rst_n_2
} else {
    set interface_clock ap_clk
    set interface_reset ap_rst_n
}

# Vitis' kernel AXI-Lite control interconnect is on clock ID 0 and does not
# insert a clock converter for an RTL kernel control port. Keep control there;
# the AXI-Stream interfaces and emulated data path can share clock ID 1 with the
# surrounding application data path.
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk \
    [ipx::current_core]
foreach busif {rx_axis tx_axis} {
    ipx::associate_bus_interfaces -busif $busif -clock $interface_clock \
        [ipx::current_core]
    # Leave the interface frequency to the Vitis linker. Otherwise Vivado's
    # inferred 100 MHz value can conflict with the selected scalable clock.
    set axis_interface [ipx::get_bus_interfaces $busif \
        -of_objects [ipx::current_core]]
    if {[llength [ipx::get_bus_parameters FREQ_HZ \
            -of_objects $axis_interface]] != 0} {
        ipx::remove_bus_parameter FREQ_HZ $axis_interface
    }
}
if {$interface_clock_id == 1} {
    ipx::associate_bus_interfaces -clock ap_clk_2 -reset $interface_reset \
        [ipx::current_core]
}

# No GT ports or refclk for hw_emu

# Set required property for Vitis kernel
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]

# Packaging Vivado IP
ipx::update_source_project_archive -component [ipx::current_core]
ipx::save_core [ipx::current_core]

# Generate Vitis Kernel from Vivado IP
package_xo -force \
           -xo_path ${build_dir}/aurora_flow_hw_emu_${instance}.xo \
           -kernel_name aurora_flow_${instance} \
           -ctrl_protocol ap_ctrl_none \
           -ip_directory ./aurora_flow_ip_${instance} \
           -output_kernel_xml ${build_dir}/aurora_flow_hw_emu_${instance}.xml
