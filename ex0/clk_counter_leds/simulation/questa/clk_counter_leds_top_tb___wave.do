onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider TB_CONTROLS:
add wave -noupdate -label TB_CLK_ENA -radix binary -radixshowbase 0 /clk_counter_leds_top_tb/tb_CLK_ena 
add wave -noupdate -divider CLKs:
add wave -noupdate -label EXTCLK -radix binary /clk_counter_leds_top_tb/EXTCLK
add wave -noupdate -divider INPUTs:
add wave -noupdate -label RESET /clk_counter_leds_top_tb/RST_N
add wave -noupdate -divider OUTPUTs:
add wave -noupdate -label LEDG /clk_counter_leds_top_tb/LEDG
add wave -noupdate -divider DUT_INTERNALS:
add wave -noupdate -label clk_counter /clk_counter_leds_top_tb/DUT/clk_counter 
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
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
WaveRestoreZoom {0 ns} {3098 ns}