# Using Terasic's DE0 NANO (Intel EP4CE22F17C6F FPGA) Evaluation Board Kit 
# Set (allocate) the pins to the appropriate ports of the entity/module 

#============================================================
# CLOCKs
#============================================================
# The main clock source for the FPGA - external
set_location_assignment PIN_R8 -to EXTCLK ;
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to EXTCLK ; 

#============================================================
# LEDs
#============================================================
# Green LEDs - outputs 
set_location_assignment PIN_A15 -to LEDG[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[0]
set_location_assignment PIN_A13 -to LEDG[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[1]
set_location_assignment PIN_B13 -to LEDG[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[2]
set_location_assignment PIN_A11 -to LEDG[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[3]
set_location_assignment PIN_D1 -to LEDG[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[4]
set_location_assignment PIN_F3 -to LEDG[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[5]
set_location_assignment PIN_B1 -to LEDG[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[6]
set_location_assignment PIN_L3 -to LEDG[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[7]

#============================================================
# KEYs
#============================================================
# Push buttons - active low (GND) - inputs 
set_location_assignment PIN_J15 -to KEY[0] ; # KEY0 , will be used to cause a general reset (asynchronous)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY[0] ;
set_location_assignment PIN_E1 -to KEY[1] ; # KEY1 , will be used for user interaction (of some sort)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY[1] ;

# Set the rest of the unused pins to inputs (in tri-state) 
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_NO_OUTPUT_GND "AS OUTPUT DRIVING AN UNSPECIFIED SIGNAL"
