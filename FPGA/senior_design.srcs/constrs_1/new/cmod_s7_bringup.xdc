## Cmod S7-25 stand-alone bring-up (Digilent onboard I/O + PIO headers).
## Carrier/gateway pin map in Docs/fabric_slop.md may differ once the PCB lands.
## Part: xc7s25csga225-1

## 12 MHz oscillator
set_property -dict { PACKAGE_PIN M9 IOSTANDARD LVCMOS33 } [get_ports { clk_12m }]
create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.666} [get_ports { clk_12m }]

## Buttons: btn_rst (D2), btn_clear (D1)
set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports { btn_rst }]
set_property -dict { PACKAGE_PIN D1 IOSTANDARD LVCMOS33 } [get_ports { btn_clear }]

## Status LEDs = per-port kill[3:0]
set_property -dict { PACKAGE_PIN E2 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## RGB (active-low): red = any kill
set_property -dict { PACKAGE_PIN F1 IOSTANDARD LVCMOS33 } [get_ports { led_b }]
set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 } [get_ports { led_g }]
set_property -dict { PACKAGE_PIN F2 IOSTANDARD LVCMOS33 } [get_ports { led_r }]

## SPI slave on Pmod JA (MCU optional for bring-up)
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports { spi_sck }]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }]

## Port taps + kill outs on PIO (breadboard / carrier adapter)
## pN_dp_tap / pN_dm_tap / pN_mux_en_n / pN_efuse_en
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports { p0_dp_tap }]
set_property -dict { PACKAGE_PIN M4  IOSTANDARD LVCMOS33 } [get_ports { p0_dm_tap }]
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { p0_mux_en_n }]
set_property -dict { PACKAGE_PIN N2  IOSTANDARD LVCMOS33 } [get_ports { p0_efuse_en }]

set_property -dict { PACKAGE_PIN M2  IOSTANDARD LVCMOS33 } [get_ports { p1_dp_tap }]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports { p1_dm_tap }]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports { p1_mux_en_n }]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports { p1_efuse_en }]

set_property -dict { PACKAGE_PIN N1  IOSTANDARD LVCMOS33 } [get_ports { p2_dp_tap }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { p2_dm_tap }]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { p2_mux_en_n }]
set_property -dict { PACKAGE_PIN N13 IOSTANDARD LVCMOS33 } [get_ports { p2_efuse_en }]

set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { p3_dp_tap }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { p3_dm_tap }]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { p3_mux_en_n }]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { p3_efuse_en }]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
