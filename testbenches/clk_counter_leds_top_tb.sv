// A simple test bench to create stimuli to ovbserve the waveforms/behaviour of the counter and the outputs 
`timescale 1ns / 1ns

module clk_counter_leds_top_tb();

// Testbench parameters
parameter CLK_PERIOD = 20; // with 1 [ns] time unit, a clk period of 20 [ns] (50 [MHz]), is 20 [units]

// DUT signals
logic        EXTCLK;
logic        RST_N;
logic [7:0]  LEDG;

// Testbench controls
logic tb_CLK_ENA;

// Testbench clock generation
initial begin
  EXTCLK = 0;
  forever #(CLK_PERIOD/2) EXTCLK = (tb_CLK_ENA)? ~EXTCLK : 0; // Generate the psuedo 50 [MHz] clock, once the clock is "enabled"
end

// DUT instantiation 
clk_counter_leds_top #()
DUT (
  .EXTCLK(EXTCLK), 
  .KEY({1'bx,RST_N}),
  .LEDG(LEDG)
);

// Testbench stimulus testing (simulation)
initial begin 
  // Print out a info text string optionally injecting variables into it - performed once
  $display($time, "<< Starting COUNTER Simulation >>") ; 
  // 0.) Initial (starting) position - Reset released (deasserted), Clock generation disabled, wait for a while
  RST_N <= 1; 
  tb_CLK_ENA <= 0; 
  # (CLK_PERIOD * 5); 

  // 1.) Apply reset, enable clock and wait for a while
  RST_N <= 0;
  tb_CLK_ENA <= 1; 
  #(CLK_PERIOD * 5);

  // 2.) Release the reset and wait for a while - the DUT's internal clk counter should start counting
  RST_N <= 1;
  repeat(10) @(posedge EXTCLK);

  // 3.) Apply reset - the DUT's internal clk counter must immediately (async) go to 0
  RST_N <= 0;
  repeat(1) @(posedge EXTCLK);
  
  RST_N <= 1;
  //repeat(32'hFFFF_FFFF) @(posedge EXTCLK);
  repeat(32) @(posedge EXTCLK);
  
  RST_N <= 0;
  repeat(1) @(posedge EXTCLK);
  
  RST_N <= 1;
  //repeat(32'hFFFF_FFFF) @(posedge EXTCLK);
  repeat(32) @(posedge EXTCLK);

  RST_N <= 0;
  repeat(1) @(posedge EXTCLK);
  
  RST_N <= 1;
  //repeat(32'hFFFF_FFFF) @(posedge EXTCLK);
  repeat(32) @(posedge EXTCLK);

  RST_N <= 0;
  repeat(5) @(posedge EXTCLK);
  
  RST_N <= 1;
  repeat(10) @(posedge EXTCLK);  
  
  RST_N <= 0;
  #(CLK_PERIOD * 5);

  RST_N <= 1;
  repeat(10) @(posedge EXTCLK);
  // Finish simulation 
  $display($time, "<< COUNTER Simulation Complete >>") ; 
  $stop;
end

// Monitor block: triggers when LEDG changes
always @(LEDG) begin
  $display("Time: [%0t] |  DUT.clkcounter: %0h | LEDG: %0h |", $time, DUT.clkcounter, LEDG);
end

// Waveform dump (for simulation)
initial begin
  $dumpfile("clk_counter_leds_top_tb.vcd");  // $dumpfile chooses the name of the file - VCD file 
  $dumpvars(0, clk_counter_leds_top_tb); // chooses what to save and how many levels of nested objects to save. By sending 0 as the number of layers it means we want all nested layers
                                // (which will include 'counter_top' and module instantiated within it, if any), and by sending the top module test it means store everything
                                // and all child wires / registers.
end

endmodule