# QuestaSim simulation script for clk_counter_leds_top_tb.sv testbench

# stop any simulation that is currently running 
quit -sim 

# Set path to your custom modelsim.ini
set PRECOMP_DEVICE_LIB_FILE ./sim_libs/modelsim.ini
# Set environment variable FIRST, so that QuestaSim uses your custom modelsim.ini file before library loading
set env(MODELSIM) [file normalize $PRECOMP_DEVICE_LIB_FILE]

# Define the testbench file and module names
set TESTBENCH_FILE debounce_tb.sv
set TESTBENCH_MODULE debounce_tb
# Define the DUT (Device Under Test) instance name within the testbench
set TESTBENCH_DUT_NAME UUT

# Start a new transcript to log the simulation output
transcript on

# Checks if the 'rtl_work' library already exists, deletes the existing library to avoid conflicts. 
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
# Then, create  a new library "rtl_work" and map the default library 'work' to 'rtl_work' , so all compiled files go there.  they'll use your custom ini file
vlib rtl_work
vmap work rtl_work

# compile the SystemVerilog source code in the 'hdl' (design) folder. Note: QuestaSim compiles the design files to library 'work' by default.
vlog -sv -work work +incdir+../../hdl/ {../../hdl/*.sv}

# compile the SystemVerilog in the 'hdl_tb' (testbench) folder. Note: QuestaSim compiles the design files to library 'work' by default.
vlog -sv -work work +incdir+../../hdl_tb/ {../../hdl_tb/*.sv}

# start the Simulator, including some libraries . You must ensure that the first -L entry in all vsim commands is always -L work,  because this alters the way that Questa Intel FPGA Edition searches for module definitions.
# This technique also helps to eliminate issues caused by duplicate modules shared by multiple IP. 
vsim -modelsimini $PRECOMP_DEVICE_LIB_FILE -64 -wlf ./$TESTBENCH_MODULE.wlf -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L work -L rtl_work -voptargs="+acc" work.$TESTBENCH_MODULE

# show waveforms specified as specified below:
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider TB_CONTROLS:
add wave -noupdate -divider CLKs:
add wave -noupdate -label CLK -radix binary /$TESTBENCH_MODULE/clk
add wave -noupdate -divider INPUTs:
add wave -noupdate -label ASYNC_RST_N /$TESTBENCH_MODULE/arst_n_i
add wave -noupdate -label DIN_I /$TESTBENCH_MODULE/din_i
add wave -noupdate -divider {OUTPUTs (INIT-LOW):}
add wave -noupdate -label deb_o /$TESTBENCH_MODULE/deb_o_low
add wave -noupdate -label {  UUT Internal: deb_counter} -radix unsigned -radixshowbase 0 -expand /$TESTBENCH_MODULE/${TESTBENCH_DUT_NAME}_INIT_LOW/deb_counter
add wave -noupdate -divider {OUTPUTs (INIT-HIGH)}
add wave -noupdate -label deb_o /$TESTBENCH_MODULE/deb_o_high
add wave -noupdate -label {  UUT Internal: deb_counter} -radix unsigned -radixshowbase 0 -expand /$TESTBENCH_MODULE/${TESTBENCH_DUT_NAME}_INIT_HIGH/deb_counter
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {270716 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 297
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
wave zoom out

#run the simulation for the desired amount of time 
view structure
view signals
run -all




