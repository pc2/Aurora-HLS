add_wave {{/aurora_hls_nfc_tb/clk}} {{/aurora_hls_nfc_tb/rst_n}} {{/aurora_hls_nfc_tb/fifo_rx_prog_full}} {{/aurora_hls_nfc_tb/fifo_rx_prog_empty}} {{/aurora_hls_nfc_tb/s_axi_nfc_tready}} {{/aurora_hls_nfc_tb/s_axi_nfc_tdata}} {{/aurora_hls_nfc_tb/s_axi_nfc_tvalid}} 
add_wave {{/aurora_hls_nfc_tb/dut/current_state}} {{/aurora_hls_nfc_tb/dut/next_state}}

run 1200 ns