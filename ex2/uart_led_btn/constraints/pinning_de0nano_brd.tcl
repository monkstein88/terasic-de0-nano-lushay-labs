# Using Terasic's DE0 NANO (Intel EP4CE22F17C6F FPGA) Evaluation Board Kit 
# Set (allocate) the pins to the appropriate ports of the entity/module 

#============================================================
# CLOCKs
#============================================================
# The main clock source for the FPGA - external
set_location_assignment PIN_R8 -to EXTCLK_i ;
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to EXTCLK_i ; 

#============================================================
# LEDs
#============================================================
# Green LEDs - outputs 
set_location_assignment PIN_A15 -to LEDG_o[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[0]
set_location_assignment PIN_A13 -to LEDG_o[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[1]
set_location_assignment PIN_B13 -to LEDG_o[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[2]
set_location_assignment PIN_A11 -to LEDG_o[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[3]
set_location_assignment PIN_D1 -to LEDG_o[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[4]
set_location_assignment PIN_F3 -to LEDG_o[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[5]
set_location_assignment PIN_B1 -to LEDG_o[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[6]
set_location_assignment PIN_L3 -to LEDG_o[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG_o[7]

#============================================================
# KEY
#============================================================
# Push buttons - active low (GND) - inputs 
set_location_assignment PIN_J15 -to KEY_i[0] ; # KEY_i0 , will be used to cause a general reset (asynchronous)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY_i[0] ;
set_location_assignment PIN_E1 -to KEY_i[1] ; # KEY_i1 , will be used for user interaction (of some sort)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY_i[1] ;

#============================================================
# UART * Pins
#============================================================
# UART - inputs and outputs
set_location_assignment PIN_T11 -to UART_RX_i ; # UART RX - input to FPGA
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_RX_i ;             
set_location_assignment PIN_R12 -to UART_TX_o ; # UART TX - output from FPGA
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_TX_o ;

# Set the rest of the unused pins to inputs (in tri-state) 
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_NO_OUTPUT_GND "AS OUTPUT DRIVING AN UNSPECIFIED SIGNAL"
