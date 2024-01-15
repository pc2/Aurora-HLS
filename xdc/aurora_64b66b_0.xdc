create_clock  -name gt_refclk0_in -period 6.206	 [get_ports gt_refclk_0_p]
set_clock_groups -asynchronous -group [get_clocks gt_refclk0_in -include_generated_clocks]
