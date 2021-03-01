create_clock -period 5.333 -name clk_mgtref -waveform {0.000 2.667} [get_ports sso_p]

set_property PACKAGE_PIN J8 [get_ports sso_n]
set_property PACKAGE_PIN J9 [get_ports sso_p]

set_property PACKAGE_PIN T2 [get_ports {rxp[0]}]
set_property PACKAGE_PIN T1 [get_ports {rxn[0]}]
set_property PACKAGE_PIN R4 [get_ports {rxp[1]}]
set_property PACKAGE_PIN R3 [get_ports {rxn[1]}]
set_property PACKAGE_PIN P2 [get_ports {rxp[2]}]
set_property PACKAGE_PIN P1 [get_ports {rxn[2]}]
set_property PACKAGE_PIN M2 [get_ports {rxp[3]}]
set_property PACKAGE_PIN M1 [get_ports {rxn[3]}]
set_property PACKAGE_PIN K2 [get_ports {rxp[4]}]
set_property PACKAGE_PIN K1 [get_ports {rxn[4]}]
set_property PACKAGE_PIN H2 [get_ports {rxp[5]}]
set_property PACKAGE_PIN H1 [get_ports {rxn[5]}]
set_property PACKAGE_PIN F2 [get_ports {rxp[6]}]
set_property PACKAGE_PIN F1 [get_ports {rxn[6]}]
set_property PACKAGE_PIN D2 [get_ports {rxp[7]}]
set_property PACKAGE_PIN D1 [get_ports {rxn[7]}]

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

set_property IOSTANDARD LVCMOS18 [get_ports uart_tx]
set_property PACKAGE_PIN AW25 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS18 [get_ports uart_rx]
set_property PACKAGE_PIN BB21 [get_ports uart_rx]

set_property IOSTANDARD LVDS [get_ports synctrig_p]
set_property PACKAGE_PIN R32 [get_ports synctrig_p]
set_property PACKAGE_PIN P32 [get_ports synctrig_n]

# PMODE0_4
set_property IOSTANDARD LVCMOS18 [get_ports rstn]
set_property PACKAGE_PIN AV16 [get_ports rstn]

# PMODE0_3
set_property IOSTANDARD LVCMOS18 [get_ports sclk]
set_property PACKAGE_PIN AV15 [get_ports sclk]

# PMODE0_2
set_property IOSTANDARD LVCMOS18 [get_ports miso]
set_property PACKAGE_PIN AW15 [get_ports miso]

# PMODE0_1
set_property IOSTANDARD LVCMOS18 [get_ports mosi]
set_property PACKAGE_PIN AY15 [get_ports mosi]

# PMODE0_0
set_property IOSTANDARD LVCMOS18 [get_ports csn]
set_property PACKAGE_PIN AY14 [get_ports csn]

set_false_path -from [get_clocks rx_usrclk] -to [get_clocks clk_out1_clk_wiz_0]
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks rx_usrclk]
set_false_path -from [get_clocks clk_mgtref] -to [get_clocks clk_out1_clk_wiz_0]
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks clk_mgtref]
set_false_path -from [get_clocks rx_usrclk] -to [get_clocks clk_mgtref]
set_false_path -from [get_clocks clk_mgtref] -to [get_clocks rx_usrclk]

