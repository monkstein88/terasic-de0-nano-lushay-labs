
module clk_counter_leds_top #(
    parameter EXT_CLOCK_FREQ = 50000000, // External Clock source, in [Hz]
    parameter EXT_CLOCK_PERIOD = 20.000,  // External Clock source, in [ns]
    parameter LEDG_SIZE = 8  // The number of LEDs on the board
)(
    input wire         EXTCLK,
    input wire   [1:0] KEY,   // active-low: KEY[0] - RESET ; KEY[1] - USER BUTTON (used for enable)
    output logic [7:0] LEDG   // active-high: LEDG[x] - green leds
);
  
  localparam LED_CNTR_WIDTH = LEDG_SIZE-1; // Counter width parameter - utilize the lower 7 indexes of leds as counter indicator.
  localparam LED_OVRFL_POS  = $high(LEDG); // Overflow bit positon - utilize the highest index of the leds as overflow indicator 
  localparam COUNT_FREQ = EXT_CLOCK_FREQ / 5; // LEDG counting frequency is 0.2 [s]
  localparam COUNT_WIDTH = $clog2(COUNT_FREQ);
  
  // Internal counter registers and signals
  wire                        clk;
  wire                        arst_n;
  wire                        enable;
  logic [LED_CNTR_WIDTH-1:0]  led_counter = '0;
  logic [COUNT_WIDTH-1:0]     clk_counter = '0;
  logic                       overflow = 1'b0;
  
  // Input (continous) assignments 
  assign clk     = EXTCLK;
  assign arst_n  = KEY[0]; // This is the total design reset  
  assign enable  = ~KEY[1]; // This is the user button that will enable counting 
  
  // Sequential logic - counter register
  always_ff @(posedge clk, negedge arst_n) begin
    if (!arst_n) begin
      clk_counter <= '0;
      led_counter <= '0;
      overflow    <= 1'b0;
    end else if(enable) begin
        clk_counter <= clk_counter + 1'b1;
        if(clk_counter == (COUNT_FREQ-1)) begin 
          clk_counter <= '0;
          overflow <= (led_counter == {LED_CNTR_WIDTH{1'b1}}); // Indicate an overflow - when (the moment) the counter rolls over (becomes 0). This is supposed to be just 1 count cycle pulse
          led_counter <= led_counter + 1'b1;
        end
    end else begin 
        overflow <= 1'b0; // if counting is disabled - stop indicating oveflow immeadiately
        clk_counter <= '0; // Zero the clock counter also, so the wait time (counting frequency) is preserved when enabled back again afterwards.
      end 
  end    
  
  // Output (continous) assignments:
  assign LEDG[LED_CNTR_WIDTH-1:0] = led_counter; // Use the 7 LSb of the LEDG to indicate counter value  
  assign LEDG[LED_OVRFL_POS]      = overflow;    // Use the 8th LEDG to indicate the counter overflow 
  
endmodule



