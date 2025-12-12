
# Move up one level to the parent directory and change directory to simulation with questa
cd ../simulation/questa/

# Open the VSIM (QuestaSim) and view the .wlf file using the waveform template - *wave.do
exec vsim -64 -gui -view ./clk_counter_leds_top_tb.wlf -do ./clk_counter_leds_top_tb___wave.do



