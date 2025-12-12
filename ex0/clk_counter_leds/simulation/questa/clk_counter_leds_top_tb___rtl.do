# stop any simulation that is currently running 
quit -sim 

transcript on

# Checks if the 'rtl_work' library already exists, deletes the existing library to avoid conflicts. 
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
# Then, create  a new library "rtl_work" and map the default library 'work' to 'rtl_work' , so all compiled files go there
vlib rtl_work
vmap work rtl_work

# compile the SystemVerilog source code in the 'hdl' (design) folder. Note: QuestaSim compiles the design files to library 'work' by default.
vlog -sv -work work +incdir+../../hdl/ {../../hdl/*.sv}

# compile the SystemVerilog in the 'hdl_tb' (testbench) folder. Note: QuestaSim compiles the design files to library 'work' by default.
vlog -sv -work work +incdir+../../hdl_tb/ {../../hdl_tb/*.sv}

# start the Simulator, including some libraries . You must ensure that the first -L entry in all vsim commands is always -L work,  because this alters the way that Questa Intel FPGA Edition searches for module definitions.
# This technique also helps to eliminate issues caused by duplicate modules shared by multiple IP. 
vsim -wlf ./clk_counter_leds_top_tb.wlf -t 1ps -L work -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L rtl_work -voptargs="+acc" work.clk_counter_leds_top_tb

# show waveforms specified in wave.do 
source ./clk_counter_leds_top_tb___wave.do

#run the simulation for the desired amount of time 
view structure
view signals
run -all




