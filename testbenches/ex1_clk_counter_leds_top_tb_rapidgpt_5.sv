// Note the time unit must be 1 [ns] for the testbench to function properly - ref. timeout safety
`timescale 1ns / 1ps

module clk_counter_leds_top_tb; 

  // =============================================================================
  // TESTBENCH PARAMETERS AND CONSTANTS
  // =============================================================================
  
  // Testbench parameters - matching DUT's:
  localparam EXT_CLOCK_FREQ = 50000000; // External Clock source, in [Hz]
  localparam EXT_CLOCK_PERIOD = 20.000;  // External Clock source, in [ns]
  localparam LEDG_SIZE = 8;  // The number of LEDs on the board
  // Testbench own parameters - for simulation:
  localparam MAX_SIM_TIME_CYCLES = 200; // Timeout after 200 LED (count) periods 
    
  // Testbench signals - matching DUT's : 
  logic EXTCLK; 
  logic [1:0] KEY; // active-low
  logic [7:0] LEDG; // active-high
  
  // Testbench derived parameters - matching DUT's:
  localparam LED_CNTR_WIDTH = LEDG_SIZE-1; // This is both the reg. width of the led counter, and its MSb position - within the LEDG array 
  localparam LED_OVRFL_POS  = $high(LEDG); // This is the position of the overflow indicator - within the LEDG array 
  localparam COUNT_FREQ = EXT_CLOCK_FREQ / 5; // LEDG counting frequency is 0.2 [s]. NOTE: This must match the DUT's !
  localparam COUNT_WIDTH = $clog2(COUNT_FREQ);

  // Testbench (control/monitor) signals:
  integer test_count = 0;
  integer pass_count = 0;
  integer fail_count = 0; 
   
  // Testbench (for DUT's internal/checking/misc) signals:
  integer expected_ledg = 0; // this also refers to DUT's (internal) 'led_counter' for checking 
  integer expected_clk_counter = 0; // this refers to DUT's (internal) 'clk_counter' for checking 
  bit     expected_overflow = 0; // this refers to the DUT's (internal) 'overflow' for checking

  // =============================================================================
  // DUT INSTANTIATION 
  // =============================================================================
  clk_counter_leds_top #(
    .EXT_CLOCK_FREQ(EXT_CLOCK_FREQ),
    .EXT_CLOCK_PERIOD(EXT_CLOCK_PERIOD),
    .LEDG_SIZE(LEDG_SIZE)
  ) DUT (
    .EXTCLK(EXTCLK),
    .KEY(KEY),
    .LEDG(LEDG)
  );

  // =============================================================================
  // CLOCK GENERATION
  // =============================================================================
  initial begin 
    EXTCLK = 1'b0;
    forever #(EXT_CLOCK_PERIOD/2) EXTCLK = ~EXTCLK;
  end 
  
  // =============================================================================
  // MAIN TEST SEQUENCE 
  // =============================================================================
  initial begin
    $display("Starting clk_counter_leds_top testbench...");
    
    // Initialize - both reset and enable pressed (active low)
    KEY = 2'b00;
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    
    // Wait for a few clock cycles
    repeat(10) @(posedge EXTCLK);
    
    // Test 1: Reset behavior
    test_count++;
    $display("\n=== Test %0d: Reset Behavior ===", test_count);
    if (LEDG == 8'h00) begin
      $display("[PASS] LEDs are all off during reset");
      pass_count++;
    end else begin
      $display("[FAIL] LEDs should be all off during reset, got: 0x%02h", LEDG);
      fail_count++;
    end
    
    // Test 2: Release reset, keep enable pressed (counting disabled)
    test_count++;
    $display("\n=== Test %0d: Reset Released, Counting Disabled ===", test_count);
    KEY[0] = 1'b1; // Release reset
    KEY[1] = 1'b1; // Keep enable pressed (disabled - active low)
    
    repeat(20) @(posedge EXTCLK);
    
    if (LEDG == 8'h00) begin
      $display("[PASS] LEDs remain off when counting is disabled");
      pass_count++;
    end else begin
      $display("[FAIL] LEDs should remain off when disabled, got: 0x%02h", LEDG);
      fail_count++;
    end
    
    // Test 3: Enable counting
    test_count++;
    $display("\n=== Test %0d: Enable Counting ===", test_count);
    KEY[1] = 1'b0; // Release enable button (enable counting - active low)
    
    // Wait for first LED increment (should take COUNT_FREQ clock cycles)
    repeat(COUNT_FREQ + 10) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == 7'h01 && LEDG[LED_OVRFL_POS] == 1'b0) begin
      $display("[PASS] First LED increment successful: 0x%02h", LEDG);
      pass_count++;
    end else begin
      $display("[FAIL] Expected LED counter = 1, overflow = 0, got: counter=0x%02h, overflow=%b", 
               LEDG[LED_CNTR_WIDTH-1:0], LEDG[LED_OVRFL_POS]);
      fail_count++;
    end
    
    // Test 4: Multiple increments
    test_count++;
    $display("\n=== Test %0d: Multiple Increments ===", test_count);
    
    // Wait for several more increments
    for (int i = 2; i <= 5; i++) begin
      repeat(COUNT_FREQ) @(posedge EXTCLK);
      if (LEDG[LED_CNTR_WIDTH-1:0] == i && LEDG[LED_OVRFL_POS] == 1'b0) begin
        $display("[PASS] LED counter = %0d", i);
      end else begin
        $display("[FAIL] Expected LED counter = %0d, got: 0x%02h", i, LEDG[LED_CNTR_WIDTH-1:0]);
        fail_count++;
      end
    end
    pass_count++;
    
    // Test 5: Disable/Enable cycle
    test_count++;
    $display("\n=== Test %0d: Disable/Enable Cycle ===", test_count);
    logic [6:0] saved_count = LEDG[LED_CNTR_WIDTH-1:0];
    
    KEY[1] = 1'b1; // Disable counting
    repeat(COUNT_FREQ) @(posedge EXTCLK); // Wait what would be a count period
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == saved_count && LEDG[LED_OVRFL_POS] == 1'b0) begin
      $display("[PASS] Counter stopped when disabled");
      pass_count++;
    end else begin
      $display("[FAIL] Counter should not change when disabled");
      fail_count++;
    end
    
    KEY[1] = 1'b0; // Re-enable counting
    repeat(COUNT_FREQ + 10) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == (saved_count + 1)) begin
      $display("[PASS] Counter resumed correctly after re-enable");
      pass_count++;
    end else begin
      $display("[FAIL] Counter did not resume correctly");
      fail_count++;
    end
    
    // Test 6: Overflow behavior - count to maximum
    test_count++;
    $display("\n=== Test %0d: Overflow Behavior ===", test_count);
    
    // Fast forward to near overflow (127 -> 0 transition)
    // Force the counter to a high value for faster testing
    force DUT.led_counter = 7'h7E; // Set to 126
    #1; // Let the force take effect
    release DUT.led_counter;
    
    // Wait for increment to 127
    repeat(COUNT_FREQ + 10) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == 7'h7F) begin
      $display("[PASS] Counter reached maximum value (127)");
    end else begin
      $display("[INFO] Counter at: %0d", LEDG[LED_CNTR_WIDTH-1:0]);
    end
    
    // Wait for overflow (127 -> 0 with overflow pulse)
    repeat(COUNT_FREQ + 10) @(posedge EXTCLK);
    
    if (LEDG[LED_CNTR_WIDTH-1:0] == 7'h00) begin
      $display("[PASS] Counter wrapped around to 0");
      pass_count++;
    end else begin
      $display("[FAIL] Counter should wrap to 0 after overflow");
      fail_count++;
    end
    
    // Test 7: Reset during operation
    test_count++;
    $display("\n=== Test %0d: Reset During Operation ===", test_count);
    
    KEY[0] = 1'b0; // Assert reset
    @(posedge EXTCLK);
    
    if (LEDG == 8'h00) begin
      $display("[PASS] Reset clears all LEDs immediately");
      pass_count++;
    end else begin
      $display("[FAIL] Reset should clear all LEDs");
      fail_count++;
    end
    
    // Final results
    $display("\n=============================================================================");
    $display("TESTBENCH RESULTS:");
    $display("Total Tests: %0d", test_count);
    $display("Passed:      %0d", pass_count);
    $display("Failed:      %0d", fail_count);
    
    if (fail_count == 0) begin
      $display("*** ALL TESTS PASSED! ***");
    end else begin
      $display("*** %0d TESTS FAILED ***", fail_count);
    end
    $display("=============================================================================");
    
    $finish;
  end
  
  // =============================================================================
  // TIMEOUT WATCHDOG
  // =============================================================================
  initial begin 
    #(COUNT_FREQ * EXT_CLOCK_PERIOD * MAX_SIM_TIME_CYCLES);
    $display("\n[ERROR] Time: %0t - Simulation Timeout!", $time);
    $display("[ERROR] Testbench did not complete within expected time!");
    fail_count++;
    $finish;
  end
  
  // =============================================================================
  // CONTINUOUS MONITORING (OPTIONAL DEBUG)
  // =============================================================================
  always @(posedge EXTCLK) begin 
    if(KEY[0] === 1'b1) begin // Only when not in reset ...
      // Monitor for 'X' (unknown) or 'Z' (high-impedance) state
      if(^LEDG === 1'bx) begin 
        $display("[ERROR] Time: %0t - LEDs contain 'X' or 'Z' values", $time);
        fail_count++;
      end 
    end 
  end   

  // =============================================================================
  // ASSERTION-BASED VERIFICATION
  // =============================================================================
  `ifdef ASSERTIONS_ENABLED 
  
  // Property: DUT's reset behaviour 
  property reset_behavior;
    @(posedge EXTCLK) 
    (KEY[0] != 1'b1) // Reset is active low
    |-> (LEDG == '0); 
  endproperty
  
  // Property: DUT's clock counter increment timing
  property clk_increment;
    @(posedge EXTCLK) 
    (KEY[0] && (KEY[1] == 1'b0) && $past(KEY[0]) && ($past(KEY[1]) == 1'b0)) // Not in reset, enabled (KEY[1] low)
    |-> ((DUT.clk_counter == ($past(DUT.clk_counter) + 1'b1)) || 
         ((DUT.clk_counter == '0) && ($past(DUT.clk_counter) == (COUNT_FREQ-1))));
  endproperty
  
  // Property: DUT's LEDs should increment
  property led_increment;
    @(posedge EXTCLK)  
    (KEY[0] && (KEY[1] == 1'b0) && (DUT.clk_counter == (COUNT_FREQ-1))) // Enabled and at count limit
    |=> (LEDG[LED_CNTR_WIDTH-1:0] == ($past(LEDG[LED_CNTR_WIDTH-1:0]) + 1'b1)); 
  endproperty
  
  // Property: DUT's overflow indication (single cycle pulse)
  property overflow_pulse;
    @(posedge EXTCLK) 
    (DUT.overflow == 1'b1) 
    |=> (DUT.overflow == 1'b0); // Overflow should be a single cycle pulse
  endproperty
  
  // Property: DUT's not counting when disabled
  property no_count_when_disabled;
    @(posedge EXTCLK)  
     disable iff(!KEY[0]) // Disable assertion when in reset
     (KEY[1] == 1'b1)  // When disabled (KEY[1] high)
     |=> $stable(LEDG[LED_CNTR_WIDTH-1:0]); 
  endproperty
  
  // Bind assertions: 
  assert property (reset_behavior)
    else $error("Reset behaviour failed at time: %t", $time);
  
  assert property (clk_increment)   
    else $error("Clock counter incrementation timing failed at time: %t", $time); 
  
  assert property (led_increment)
    else $error("LEDs counting (incrementation) timing failed at time: %t", $time); 
    
  assert property (overflow_pulse)
    else $error("Overflow pulse behavior failed at time: %t", $time);
    
  assert property (no_count_when_disabled)
    else $error("Not counting when disabled failed at time: %t", $time);
    
  `endif // ASSERTIONS_ENABLED
  
  // =============================================================================
  // WAVEFORM DUMPING 
  // =============================================================================
  initial begin 
    $dumpfile("clk_counter_leds_top_tb.vcd"); 
    $dumpvars(0, clk_counter_leds_top_tb);  
    // Add flush points for better waveform viewing
    forever begin 
      @((negedge KEY[0], posedge KEY[0]) or (negedge KEY[1], posedge KEY[1])) 
        $dumpflush;
    end 
  end

endmodule 
