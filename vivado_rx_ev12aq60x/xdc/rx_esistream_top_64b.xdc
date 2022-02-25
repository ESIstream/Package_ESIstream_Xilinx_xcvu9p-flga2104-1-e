create_clock -period 5.000 -name clk_mgtref -waveform {0.000 2.500} [get_ports sso_p]
create_clock -period 5.000 -name clk_mgtref2 -waveform {0.000 2.500} [get_ports sso2_p]

set_property PACKAGE_PIN AK39 [get_ports sso_n]
set_property PACKAGE_PIN AK38 [get_ports sso_p]

set_property PACKAGE_PIN V39 [get_ports sso2_n]
set_property PACKAGE_PIN V38 [get_ports sso2_p]

set_property PACKAGE_PIN AR45 [get_ports {rxp[0]}]
set_property PACKAGE_PIN AR46 [get_ports {rxn[0]}]
set_property PACKAGE_PIN AN45 [get_ports {rxp[1]}]
set_property PACKAGE_PIN AN46 [get_ports {rxn[1]}]
set_property PACKAGE_PIN AL45 [get_ports {rxp[2]}]
set_property PACKAGE_PIN AL46 [get_ports {rxn[2]}]
set_property PACKAGE_PIN AJ45 [get_ports {rxp[3]}]
set_property PACKAGE_PIN AJ46 [get_ports {rxn[3]}]
set_property PACKAGE_PIN W45 [get_ports {rxp[4]}]
set_property PACKAGE_PIN W46 [get_ports {rxn[4]}]
set_property PACKAGE_PIN U45 [get_ports {rxp[5]}]
set_property PACKAGE_PIN U46 [get_ports {rxn[5]}]
set_property PACKAGE_PIN R45 [get_ports {rxp[6]}]
set_property PACKAGE_PIN R46 [get_ports {rxn[6]}]
set_property PACKAGE_PIN N45 [get_ports {rxp[7]}]
set_property PACKAGE_PIN N46 [get_ports {rxn[7]}]

# PL system clock:
set_property IOSTANDARD LVDS [get_ports CLK_125MHZ_P]
set_property PACKAGE_PIN AY24 [get_ports CLK_125MHZ_P]
set_property PACKAGE_PIN AY23 [get_ports CLK_125MHZ_N]
create_clock -period 8.000 -name CLK_125MHZ_P [get_ports CLK_125MHZ_P]

set_property IOSTANDARD LVCMOS12 [get_ports {gpio_dip_sw[*]}]
set_property PACKAGE_PIN B17 [get_ports {gpio_dip_sw[1]}]
set_property PACKAGE_PIN G16 [get_ports {gpio_dip_sw[2]}]
set_property PACKAGE_PIN J16 [get_ports {gpio_dip_sw[3]}]
set_property PACKAGE_PIN D21 [get_ports {gpio_dip_sw[4]}]

set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_n]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_w]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_s]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_e]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_c]
set_property PACKAGE_PIN BB24 [get_ports gpio_sw_n]
set_property PACKAGE_PIN BF22 [get_ports gpio_sw_w]
set_property PACKAGE_PIN BE22 [get_ports gpio_sw_s]
set_property PACKAGE_PIN BE23 [get_ports gpio_sw_e]
set_property PACKAGE_PIN BD23 [get_ports gpio_sw_c]

set_property IOSTANDARD LVCMOS12 [get_ports {gpio_led[*]}]
set_property PACKAGE_PIN AT32 [get_ports {gpio_led[0]}]
set_property PACKAGE_PIN AV34 [get_ports {gpio_led[1]}]
set_property PACKAGE_PIN AY30 [get_ports {gpio_led[2]}]
set_property PACKAGE_PIN BB32 [get_ports {gpio_led[3]}]
set_property PACKAGE_PIN BF32 [get_ports {gpio_led[4]}]
set_property PACKAGE_PIN AU37 [get_ports {gpio_led[5]}]
set_property PACKAGE_PIN AV36 [get_ports {gpio_led[6]}]
set_property PACKAGE_PIN BA37 [get_ports {gpio_led[7]}]


set_property IOSTANDARD LVCMOS18 [get_ports {m2c_cfg[*]}]
set_property PACKAGE_PIN N34 [get_ports {m2c_cfg[1]}]
set_property PACKAGE_PIN N35 [get_ports {m2c_cfg[2]}]
set_property PACKAGE_PIN Y34 [get_ports {m2c_cfg[3]}]
set_property PACKAGE_PIN W34 [get_ports {m2c_cfg[4]}]

set_property IOSTANDARD LVCMOS18 [get_ports {c2m_led[*]}]
set_property PACKAGE_PIN AG32 [get_ports {c2m_led[1]}]
set_property PACKAGE_PIN AG33 [get_ports {c2m_led[2]}]
set_property PACKAGE_PIN N33 [get_ports {c2m_led[3]}]
set_property PACKAGE_PIN M33 [get_ports {c2m_led[4]}]

set_property IOSTANDARD LVCMOS18 [get_ports spare_8_uart_tx]
set_property PACKAGE_PIN AP35 [get_ports spare_8_uart_tx]
set_property IOSTANDARD LVCMOS18 [get_ports spare_9_uart_rx]
set_property PACKAGE_PIN AH31 [get_ports spare_9_uart_rx]

set_property IOSTANDARD LVCMOS18 [get_ports {spare[*]}]
set_property PACKAGE_PIN AJ31 [get_ports {spare[1]}]
set_property PACKAGE_PIN AH34 [get_ports {spare[2]}]
set_property PACKAGE_PIN AP37 [get_ports {spare[3]}]
set_property PACKAGE_PIN AP36 [get_ports {spare[4]}]
set_property PACKAGE_PIN AH35 [get_ports {spare[5]}]
set_property PACKAGE_PIN AJ33 [get_ports {spare[6]}]
set_property PACKAGE_PIN AT35 [get_ports {spare[7]}]

set_property IOSTANDARD LVCMOS18 [get_ports fpga_ref_clk]
set_property PACKAGE_PIN AL35 [get_ports fpga_ref_clk]

set_property IOSTANDARD LVCMOS18 [get_ports ref_sel_ext]
set_property PACKAGE_PIN AT39 [get_ports ref_sel_ext]

set_property IOSTANDARD LVCMOS18 [get_ports ref_sel]
set_property PACKAGE_PIN AT40 [get_ports ref_sel]

set_property IOSTANDARD LVCMOS18 [get_ports clk_sel]
set_property PACKAGE_PIN AK29 [get_ports clk_sel]

set_property IOSTANDARD LVCMOS18 [get_ports synco_sel]
set_property PACKAGE_PIN AK30 [get_ports synco_sel]

set_property IOSTANDARD LVCMOS18 [get_ports sync_sel]
set_property PACKAGE_PIN AH33 [get_ports sync_sel]

set_property IOSTANDARD LVCMOS18 [get_ports hmc1031_d1]
set_property PACKAGE_PIN AP38 [get_ports hmc1031_d1]

set_property IOSTANDARD LVCMOS18 [get_ports hmc1031_d0]
set_property PACKAGE_PIN AR38 [get_ports hmc1031_d0]

set_property IOSTANDARD LVCMOS18 [get_ports pll_muxout]
set_property PACKAGE_PIN AG34 [get_ports pll_muxout]

set_property IOSTANDARD LVDS [get_ports clkoutB_p]
set_property PACKAGE_PIN R34 [get_ports clkoutB_p]
set_property PACKAGE_PIN P34 [get_ports clkoutB_n]

set_property IOSTANDARD LVCMOS18 [get_ports rstn]
set_property PACKAGE_PIN AR35 [get_ports rstn]

set_property IOSTANDARD LVCMOS18 [get_ports adc_sclk]
set_property PACKAGE_PIN AL30 [get_ports adc_sclk]

set_property IOSTANDARD LVCMOS18 [get_ports adc_cs_u]
set_property PACKAGE_PIN AK33 [get_ports adc_cs_u]

set_property IOSTANDARD LVCMOS18 [get_ports adc_mosi]
set_property PACKAGE_PIN AJ36 [get_ports adc_mosi]

set_property IOSTANDARD LVCMOS18 [get_ports adc_miso]
set_property PACKAGE_PIN AJ35 [get_ports adc_miso]

set_property IOSTANDARD LVCMOS18 [get_ports csn_pll]
set_property PACKAGE_PIN AJ30 [get_ports csn_pll]

set_property IOSTANDARD LVCMOS18 [get_ports sclk]
set_property PACKAGE_PIN AG31 [get_ports sclk]

set_property IOSTANDARD LVCMOS18 [get_ports miso]
set_property PACKAGE_PIN AT36 [get_ports miso]

set_property IOSTANDARD LVCMOS18 [get_ports mosi]
set_property PACKAGE_PIN M32 [get_ports mosi]

set_property IOSTANDARD LVCMOS18 [get_ports csn]
set_property PACKAGE_PIN N32 [get_ports csn]

set_property IOSTANDARD LVDS [get_ports synctrig_p]
set_property PACKAGE_PIN AR37 [get_ports synctrig_p]
set_property PACKAGE_PIN AT37 [get_ports synctrig_n]

set_property IOSTANDARD LVDS [get_ports synco_p]
set_property PACKAGE_PIN M36 [get_ports synco_p]
set_property PACKAGE_PIN L36 [get_ports synco_n]

#set_false_path -from [get_clocks rx_usrclk] -to [get_clocks clk_out1_clk_wiz_0]
#set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks rx_usrclk]
set_false_path -from [get_clocks rxoutclk_out[3]] -to [get_clocks clk_out1_clk_wiz_0]
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks rxoutclk_out[3]]
set_false_path -from [get_clocks clk_mgtref] -to [get_clocks clk_out1_clk_wiz_0]
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks clk_mgtref]
set_false_path -from [get_clocks clk_mgtref2] -to [get_clocks clk_out1_clk_wiz_0]
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks clk_mgtref2]
