// A simple test bench to create stimuli to ovbserve the waveforms/behaviour of the counter and the outputs 
`timescale 1ns / 1ps

module clk_counter_leds_top_tb();

// Testbench parameters
parameter CLK_PERIOD_NS = 20; // with 1 [ns] time unit, a clk period of 20 [ns] (50 [MHz]), is 20 [units]

// DUT signals
logic        EXTCLK;
logic        RST_N;
logic [7:0]  LEDG;

// Testbench controls
logic tb_CLK_ena; //

// Testbench clock generation
initial begin
  EXTCLK = 0;
  forever #(CLK_PERIOD_NS/2) EXTCLK = (tb_CLK_ena)? ~EXTCLK : 0; // Generate the psuedo 50 [MHz] clock, once the clock is "enabled"
end

// DUT instantiation 
clk_counter_leds_top #()
DUT (
  .EXTCLK(EXTCLK), // external clock input 
  .KEY({1'bx, RST_N}),// active-low reset on KEY[0], KEY[1] is not used
  .LEDG(LEDG) // 8 green leds output
);

// Testbench stimulus testing (simulation)
initial begin 
  // Print out a info text string optionally injecting variables into it - performed once
  $display($time, "<< Starting LED COUNTER Simulation >>") ; 
  // 0.) Initial (starting) position - Reset released (deasserted), Clock generation disabled, wait for a while
  RST_N <= 1; 
  tb_CLK_ena <= 0; 
  # (CLK_PERIOD_NS * 5); 

  // 1.) Check initial values of DUT signals - they should be zero 
  if(DUT.clk_counter !== 32'h0000_0000) begin
    $display("ERROR: clk_counter expected to be 0x00000000 at start, but found %0h", DUT.clk_counter);
  end else begin
    $display("SUCCESS: clk_counter correctly initialized to 0x00000000");
  end
  if(LEDG !== 8'h00) begin
    $display("ERROR: LEDG expected to be 0x00 at start, but found %0h", LEDG);
  end else begin
    $display("SUCCESS: LEDG correctly initialized to 0x00");
  end

  // 2.) Apply reset, enable clock and wait for a while
  RST_N <= 0;
  tb_CLK_ena <= 1; 
  repeat(5) @(posedge EXTCLK); // wait for 5 clock cycles, as clock is now running

  // 3.) Check if DUT's internal clk counter and LEDG are kept at zero, even as clock is running
  if(DUT.clk_counter !== 32'h0000_0000) begin
   $display("ERROR: clk_counter expected to stay at 0x00000000 while reset is asserted, but got %0h", DUT.clk_counter);
  end else begin
    $display("SUCCESS: clk_counter correctly held at 0x00000000 while reset is asserted");
  end 
  if(LEDG !== 8'h00) begin
    $display("ERROR: LEDG expected to be 0x00 while reset is asserted, but found %0h", LEDG);
  end else begin
    $display("SUCCESS: LEDG correctly held at 0x00 while reset is asserted");
  end

  // 4.) Release the reset and wait for a while - the DUT's internal clk counter should start counting
  RST_N <= 1; 
  @(posedge EXTCLK); // wait for next clock edge to release reset
  repeat(10) @(posedge EXTCLK); // wait for 10 clock cycles

  // 5.) Check if DUT's internal clk counter reached expected value of 10 (0x0000_000A)
  if(DUT.clk_counter !== 32'h0000_000A) begin
    $display("ERROR: clk_counter expected to be 0x0000000A after 10 clock cycles, but found %0h", DUT.clk_counter);
  end else begin
    $display("SUCCESS: clk_counter incremented correctly to 0x0000000A");
  end
  
  // 6.) Apply reset - the DUT's internal clk counter must immediately (async) go to 0
  RST_N <= 0;
  #1; // wait 1 [ns] to allow async reset to propagate
  if(DUT.clk_counter !== 32'h0000_0000) begin
    $display("ERROR: clk_counter expected to be 0x00000000 immediately after reset, but found %0h", DUT.clk_counter);
  end else begin
    $display("SUCCESS: clk_counter correctly reset to 0x00000000 immediately after reset");
  end
  
  // 7.) Release the reset on the next clock edge, then wait for the counter to reach a value where LEDG should change (0x0400_0000) 
  @(posedge EXTCLK);
  RST_N <= 1;
  @(posedge EXTCLK); // wait for next clock edge to release reset
  repeat(32'h0400_0000) @(posedge EXTCLK); // wait for 0x0400_0000 clock cycles

  // 8.) Check if LEDG reached expected value of 0x04 (upper 8 bits of 0x0400_0000 clk_counter)
  if(LEDG !== 8'h04) begin
    $display("ERROR: LEDG expected to be 0x04, but found %0h", LEDG);
  end else begin
    $display("SUCCESS: LEDG correctly reached 0x04");
  end

  // 9.) Force counter to near overflow for testing purposes, wait for a clock edge and release the force
  force DUT.clk_counter = 32'hFFFFFFFE; // Force the counter to 0xFFFFFFFE
  @(posedge EXTCLK); // wait for one clock cycle to let the forced value take effect
  release DUT.clk_counter; // Release the forced value

  // 10.) Check if LEDG reached expected value of 0xFF (upper 8 bits of 0xFFFFFFFE clk_counter)
  if(LEDG !== 8'hFF) begin
    $display("ERROR: LEDG expected to be 0xFF, but found %0h", LEDG);
  end else begin
    $display("SUCCESS: LEDG correctly forced to 0xFF");
  end

  // 11.) Wait for the counter to overflow and wrap around to 0, check LEDG again
  @(posedge EXTCLK); // clk_counter should now be 0xFFFFFFFF
  @(posedge EXTCLK); // clk_counter should now wrap to 0x00000000
  
  // 12.) Check if counter wrapped to 0 and LEDG is also 0x00
  if(DUT.clk_counter !== 32'h0000_0000) begin
    $display("ERROR: clk_counter expected to wrap to 0x00000000 after overflow, but found %0h", DUT.clk_counter);
  end else begin
    $display("SUCCESS: clk_counter correctly wrapped to 0x00000000 after overflow");
  end
  if(LEDG !== 8'h00) begin
    $display("ERROR: LEDG expected to be 0x00 after overflow wrap, but found %0h", LEDG);
  end else begin
    $display("SUCCESS: LEDG correctly reset to 0x00 after overflow wrap");
  end

  // Finish simulation 
  $display($time, "<< LED COUNTER Simulation Complete >>") ; 
  $stop;
end

// Monitor block: triggers when LEDG changes, displays current values and checks correctness
always @(LEDG) begin
  $display("Time: [%0t] |  DUT.clk_counter: %0h | LEDG: %0h |", $time, DUT.clk_counter, LEDG);
  if (LEDG === DUT.clk_counter[31:24]) begin
    $display("  OK: LEDG matches the upper 8 bits of clk_counter.");
  end else begin
    $display("  ERROR: LEDG does not match the upper 8 bits of clk_counter!");
  end
end

// VCD waveform generation (for GTKWave or similar viewers)
initial begin
  $dumpfile("clk_counter_leds_top_tb.vcd");  // $dumpfile chooses the name of the file - VCD file 
  $dumpvars(0, clk_counter_leds_top_tb); // chooses what to save and how many levels of nested objects to save. By sending 0 as the number of layers it means we want all nested layers
                                // (which will include 'counter_top' and module instantiated within it, if any), and by sending the top module test it means store everything
                                // and all child wires / registers.
end

endmodule