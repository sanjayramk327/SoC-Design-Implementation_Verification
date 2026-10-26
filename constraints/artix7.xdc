## ==============================================================================
## MorphoSoC Constraints for Xilinx Artix-7 FPGA (Basys3 / Nexys4 / Arty A7)
## Target: XC7A35T / XC7A100T
## ==============================================================================

## Clock signal (100 MHz Master Oscillator)
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Active-low Reset Button (CPU Reset)
set_property PACKAGE_PIN V17 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## Telemetry Status LEDs
set_property PACKAGE_PIN U16 [get_ports telemetry_failover_active]
set_property IOSTANDARD LVCMOS33 [get_ports telemetry_failover_active]

set_property PACKAGE_PIN E19 [get_ports {telemetry_udb_context[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {telemetry_udb_context[0]}]

set_property PACKAGE_PIN U19 [get_ports {telemetry_udb_context[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {telemetry_udb_context[1]}]

set_property PACKAGE_PIN V19 [get_ports telemetry_snn_spike]
set_property IOSTANDARD LVCMOS33 [get_ports telemetry_snn_spike]

set_property PACKAGE_PIN W18 [get_ports telemetry_cpu_sleep]
set_property IOSTANDARD LVCMOS33 [get_ports telemetry_cpu_sleep]

## GPIO Port 0 Pads (Matching Cypress PSoC 4 Pinout: P0.0 to P0.7)
set_property PACKAGE_PIN J1 [get_ports {gpio_pads[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[0]}]

set_property PACKAGE_PIN L2 [get_ports {gpio_pads[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[1]}]

set_property PACKAGE_PIN J2 [get_ports {gpio_pads[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[2]}]

## Primary UART TX (P0.3)
set_property PACKAGE_PIN G2 [get_ports {gpio_pads[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[3]}]

set_property PACKAGE_PIN H1 [get_ports {gpio_pads[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[4]}]

## TCPWM OUT0 (P0.5)
set_property PACKAGE_PIN K2 [get_ports {gpio_pads[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[5]}]

## TCPWM nOUT0 (P0.6)
set_property PACKAGE_PIN H2 [get_ports {gpio_pads[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[6]}]

## Backup UART TX (P0.7 - Patent 3 Autonomous Failover Pin)
set_property PACKAGE_PIN G3 [get_ports {gpio_pads[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[7]}]

## GPIO Port 1 Pads (P1.0 to P1.7)
set_property PACKAGE_PIN A14 [get_ports {gpio_pads[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[8]}]

set_property PACKAGE_PIN A16 [get_ports {gpio_pads[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[9]}]

set_property PACKAGE_PIN B15 [get_ports {gpio_pads[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[10]}]

set_property PACKAGE_PIN B16 [get_ports {gpio_pads[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[11]}]

set_property PACKAGE_PIN A15 [get_ports {gpio_pads[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[12]}]

set_property PACKAGE_PIN A17 [get_ports {gpio_pads[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[13]}]

set_property PACKAGE_PIN C15 [get_ports {gpio_pads[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[14]}]

set_property PACKAGE_PIN C16 [get_ports {gpio_pads[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pads[15]}]
