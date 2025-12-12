/* A simple 32-bit counter module (design) that increments with each clk cycle, with the upper 8-bits of the counter displayed on 8 LEDs array. 
 * And has a an user (asynchronous) reset. */
module clk_counter_leds_top
#(
  parameter EXT_CLOCK_FREQ = 50000000, // External Clock source, in [Hz]
  parameter EXT_CLOCK_PERIOD = 20.000  // External Clock source, in [ns]
)
(
  input  wire          EXTCLK, 
  input  wire   [1:0]  KEY,  // active-low: KEY[0] - RESET ; KEY[1] - USER BUTTON
  output logic  [7:0]  LEDG  // active-high : LEDG[x] - green leds
);

/* Internal Signals */
logic [31:0] clk_counter = 0; // 32-bit counter register

/* Implementation - Simple 32-bit counter with async reset. */
assign LEDG = clk_counter[($size(clk_counter)-1)-:$size(LEDG)]; // assign the upper 8-bits of the counter to the 8 green leds
always_ff @(posedge EXTCLK, negedge KEY[0]) begin 
  if(KEY[0]!=1'b1) begin 
    clk_counter <= 0; // async reset, when KEY[0] is pressed (active-low)
  end else begin
    clk_counter <= clk_counter + 1; // increment counter, at each clock cycle, overflow is ok
  end
end
 
endmodule