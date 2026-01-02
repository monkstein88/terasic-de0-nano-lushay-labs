`timescale 1ns / 1ps

module clk_counter_leds_top_tb;

  // Testbench parameters - match DUT
  localparam EXT_CLOCK_FREQ   = 50000000;
  localparam EXT_CLOCK_PERIOD = 20.000;
  localparam LEDG_SIZE        = 8;
  
  // Derived parameters for testing
  localparam LED_CNTR_WIDTH = LEDG_SIZE - 1;
  localparam COUNT_FREQ = EXT_CLOCK_FREQ / 5;
  
  // Testbench signals
  logic         EXTCLK;
  logic [1:0]   KEY;
  logic [7:0]   LEDG;
  
  // Clock generation
  initial begin
    EXTCLK = 0;
    forever #(EXT_CLOCK_PERIOD/2) EXTCLK = ~EXTCLK;
  end
  
  // DUT instantiation
  clk_counter_leds_top #(
    .EXT_CLOCK_FREQ(EXT_CLOCK_FREQ),
    .EXT_CLOCK_PERIOD(EXT_CLOCK_PERIOD),
    .LEDG_SIZE(LEDG_SIZE)
  ) dut (
    .EXTCLK(EXTCLK),
    .KEY(KEY),
    .LEDG(LEDG)
  );
  
  // Test stimulus
  initial begin
    // Initialize signals
    KEY = 2'b11; // Both buttons not pressed (active-low)
    
    // Display test info
    $display("=== Testbench Start ===");
    $display("Clock Period: %0.3f ns", EXT_CLOCK_PERIOD);
    $display("Clock Frequency: %0d Hz", EXT_CLOCK_FREQ);
    $display("LED Counter Width: %0d bits", LED_CNTR_WIDTH);
    $display("Count Frequency: %0d clocks (0.5s)", COUNT_FREQ);
    $display("");
    
    // Test 1: Reset
    $display("[%0t ns] TEST 1: Applying Reset", $time);
    KEY[0] = 0; // Assert reset (active-low)
    repeat(10) @(posedge EXTCLK);
    
    if (LEDG === 8'h00) 
      $display("[%0t ns] PASS: Reset clears all LEDs", $time);
    else
      $display("[%0t ns] FAIL: LEDs not cleared (LEDG = 0x%h)", $time, LEDG);
    
    KEY[0] = 1; // Deassert reset
    repeat(5) @(posedge EXTCLK);
    $display("");
    
    // Test 2: Enable counting
    $display("[%0t ns] TEST 2: Enable counting (KEY[1] = 0)", $time);
    KEY[1] = 0; // Enable counting (active-low button)
    
    // Wait for first LED increment (simulate shorter for testbench speed)
    // In real hardware this would take 0.5s, here we just wait enough cycles
    repeat(COUNT_FREQ + 10) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == 7'd1)
      $display("[%0t ns] PASS: LED counter incremented to 1", $time);
    else
      $display("[%0t ns] FAIL: LED counter = %0d (expected 1)", $time, LEDG[LED_CNTR_WIDTH-1:0]);
    
    // Wait for second increment
    repeat(COUNT_FREQ) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == 7'd2)
      $display("[%0t ns] PASS: LED counter incremented to 2", $time);
    else
      $display("[%0t ns] FAIL: LED counter = %0d (expected 2)", $time, LEDG[LED_CNTR_WIDTH-1:0]);
    
    $display("");
    
    // Test 3: Disable counting
    $display("[%0t ns] TEST 3: Disable counting (KEY[1] = 1)", $time);
    KEY[1] = 1; // Disable counting
    repeat(5) @(posedge EXTCLK);
    
    automatic logic [6:0] held_value = LEDG[LED_CNTR_WIDTH-1:0];
    repeat(COUNT_FREQ + 100) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == held_value)
      $display("[%0t ns] PASS: Counter held at %0d while disabled", $time, held_value);
    else
      $display("[%0t ns] FAIL: Counter changed while disabled", $time);
    
    $display("");
    
    // Test 4: Re-enable and continue
    $display("[%0t ns] TEST 4: Re-enable counting", $time);
    KEY[1] = 0; // Re-enable
    
    repeat(COUNT_FREQ) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == (held_value + 1))
      $display("[%0t ns] PASS: Counter resumed from %0d to %0d", $time, held_value, LEDG[LED_CNTR_WIDTH-1:0]);
    else
      $display("[%0t ns] FAIL: Counter = %0d (expected %0d)", $time, LEDG[LED_CNTR_WIDTH-1:0], held_value+1);
    
    $display("");
    
    // Test 5: Overflow detection (accelerated)
    $display("[%0t ns] TEST 5: Testing overflow (accelerated)", $time);
    $display("Waiting for counter to reach 127 and overflow...");
    
    // Fast-forward by forcing the counter near overflow
    force dut.led_counter = 7'd125;
    #1; // Allow force to take effect
    release dut.led_counter;
    
    // Now wait for natural counting to 127 and overflow
    repeat(3 * COUNT_FREQ) @(posedge EXTCLK);
    
    // Check if we've seen overflow bit
    if (LEDG[7] == 1'b1 && LEDG[LED_CNTR_WIDTH-1:0] == 7'd127)
      $display("[%0t ns] PASS: Overflow detected at counter = 127", $time);
    else if (LEDG[LED_CNTR_WIDTH-1:0] == 7'd0 && LEDG[7] == 1'b0)
      $display("[%0t ns] PASS: Counter rolled over to 0, overflow cleared", $time);
    
    $display("");
    
    // Test 6: Reset during operation
    $display("[%0t ns] TEST 6: Reset during counting", $time);
    KEY[0] = 0; // Assert reset
    repeat(5) @(posedge EXTCLK);
    
    if (LEDG === 8'h00)
      $display("[%0t ns] PASS: Reset clears counter mid-operation", $time);
    else
      $display("[%0t ns] FAIL: Reset failed (LEDG = 0x%h)", $time, LEDG);
    
    KEY[0] = 1; // Deassert reset
    repeat(10) @(posedge EXTCLK);
    
    $display("");
    $display("=== Testbench Complete ===");
    $finish;
  end
  
  // Monitor for debugging
  initial begin
    $monitor("[%0t ns] KEY=%b, LEDG[6:0]=%3d, OVERFLOW=%b, clk_cnt=%0d", 
             $time, KEY, LEDG[6:0], LEDG[7], dut.clk_counter);
  end
  
  // Waveform dump (for viewing in GTKWave or similar)
  initial begin
    $dumpfile("clk_counter_leds_top_tb.vcd");
    $dumpvars(0, clk_counter_leds_top_tb);
  end

endmodule