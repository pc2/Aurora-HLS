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


##################################### Step 1: create vivado project and add design sources

# argv layout: <part> <instance> <src_dir> <build_dir> <interface_clock_id>
set part      [lindex $argv 0]
set instance  [lindex $argv 1]
set src_dir   [lindex $argv 2]
set build_dir [lindex $argv 3]
set interface_clock_id [lindex $argv 4]
if {$interface_clock_id ni {0 1}} {
    error "interface_clock_id must be 0 or 1"
}
set ip_root   ./aurora_flow_ip_${instance}
set ip_src    ${ip_root}/src

# create ip project with part name in command line argvs
create_project aurora_flow_${instance} ./aurora_flow_${instance} -part $part

# stage generated sources inside the IP root so package_project keeps relative
# paths for the packaged include file.
file mkdir ${ip_src}
file copy -force ${build_dir}/rtl/hw/aurora_flow_define.v ${ip_src}/aurora_flow_define.v

# add design sources into project
add_files -norecurse -fileset sources_1 \
       [list                                          \
              ${src_dir}/rtl/aurora_flow_control_s_axi.v \
              ${build_dir}/rtl/aurora_flow_${instance}.v \
              ${src_dir}/rtl/aurora_flow_io.v \
              ${src_dir}/rtl/aurora_flow_nfc.v \
              ${src_dir}/rtl/aurora_flow_reset.v \
              ${src_dir}/rtl/aurora_flow_configuration.v \
              ${src_dir}/rtl/aurora_flow_monitor.v \
              ${build_dir}/ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci \
              ${build_dir}/ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci \
              ${build_dir}/ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci \
              ${build_dir}/ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci \
              ${build_dir}/ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci \
       ]

add_files -norecurse -fileset constrs_1 \
       [list                                         \
              ${src_dir}/xdc/aurora_64b66b_${instance}.xdc \
       ]

# make `include "aurora_flow_define.v" resolve to the staged file in the IP root
set_property include_dirs [list ${ip_src}] [get_filesets sources_1]

update_compile_order -fileset sources_1

# create IP packaging project
ipx::package_project -root_dir ./aurora_flow_ip_${instance} -vendor xilinx.com -library user -taxonomy /UserIP -import_files -set_current true


# inference clock and reset signals
ipx::infer_bus_interface ap_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface ap_rst_n xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
if {$interface_clock_id == 1} {
    ipx::infer_bus_interface ap_clk_2 xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
    ipx::infer_bus_interface ap_rst_n_2 xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
}
# remove auto inferred clock interface init_clk, just treat it as a normal port
ipx::remove_bus_interface init_clk [ipx::current_core]

# AXI-Lite control stays on platform clock ID 0. The optional second clock is
# used only for the external AXI-Stream data path.
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]
if {$interface_clock_id == 1} {
    set data_clock ap_clk_2
} else {
    set data_clock ap_clk
}
foreach busif {rx_axis tx_axis} {
    ipx::associate_bus_interfaces -busif $busif -clock $data_clock \
        [ipx::current_core]
}
ipx::associate_bus_interfaces -clock ap_clk -reset ap_rst_n [ipx::current_core]
if {$interface_clock_id == 1} {
    ipx::associate_bus_interfaces -clock ap_clk_2 -reset ap_rst_n_2 \
        [ipx::current_core]
}

# create GT data port
ipx::add_bus_interface gt_port [ipx::current_core]
set_property interface_mode master                                    [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:gt_rtl:1.0    [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:gt:1.0                [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]

ipx::add_port_map GRX_P                                               [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]
set_property physical_name gt_rxp_in [ipx::get_port_maps GRX_P -of_objects [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]]

ipx::add_port_map GTX_N                                               [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]
set_property physical_name gt_txn_out [ipx::get_port_maps GTX_N -of_objects [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]]

ipx::add_port_map GRX_N                                               [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]
set_property physical_name gt_rxn_in [ipx::get_port_maps GRX_N -of_objects [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]]

ipx::add_port_map GTX_P                                               [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]
set_property physical_name gt_txp_out [ipx::get_port_maps GTX_P -of_objects [ipx::get_bus_interfaces gt_port -of_objects [ipx::current_core]]]

# create GT clock port
set gt_refclk_name "gt_refclk_${instance}"
ipx::add_bus_interface ${gt_refclk_name} [ipx::current_core]
set_property interface_mode slave                                            [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:diff_clock_rtl:1.0   [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:diff_clock:1.0               [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]

ipx::add_port_map CLK_P                                                      [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]
set_property physical_name ${gt_refclk_name}_p [ipx::get_port_maps CLK_P -of_objects [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]]

ipx::add_port_map CLK_N                                                      [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]
set_property physical_name ${gt_refclk_name}_n [ipx::get_port_maps CLK_N -of_objects [ipx::get_bus_interfaces ${gt_refclk_name} -of_objects [ipx::current_core]]]


# Set required property for Vitis kernel
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]

# Packaging Vivado IP
ipx::update_source_project_archive -component [ipx::current_core]
ipx::save_core [ipx::current_core]

# Generate Vitis Kernel from Vivado IP
package_xo -force \
           -xo_path ${build_dir}/aurora_flow_hw_${instance}.xo \
           -kernel_name aurora_flow_${instance} \
           -ctrl_protocol ap_ctrl_none \
           -ip_directory ./aurora_flow_ip_${instance} \
           -output_kernel_xml ${build_dir}/aurora_flow_hw_${instance}.xml
