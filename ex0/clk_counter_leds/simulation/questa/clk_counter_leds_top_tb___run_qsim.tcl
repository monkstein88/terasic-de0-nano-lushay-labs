# if ![info exists PRECOMP_DEVICE_LIB_FILE] { set PRECOMP_DEVICE_LIB_FILE "./simulation_library/modelsim.ini" }

# Move up one level to the parent directory and change directory to simulation with questa
cd ../simulation/questa/

set PRECOMP_DEVICE_LIB_FILE ./sim_libs/modelsim.ini

# Open the VSIM (QuestaSim) and run simulation. Note: Use the compiled Questa Simulation Libraries cited in the modelsim.ini
exec vsim -modelsimini $PRECOMP_DEVICE_LIB_FILE -64 -gui -do ./clk_counter_leds_top_tb___rtl.do



