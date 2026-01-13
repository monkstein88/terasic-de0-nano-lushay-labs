// Note the time unit must be 1 [ns] for the testbench to function properly - ref. TIMEOUT WATCHDOG
`timescale 1ns / 1ps // 

module clk_counter_leds_top_tb; 

  // =============================================================================
  // TESTBENCH PARAMETERS AND CONSTANTS
  // =============================================================================
  
  // Testbench parameters - matching DUT's:
  localparam EXT_CLOCK_FREQ = 50000000; // External Clock source, in [Hz]
  localparam EXT_CLOCK_PERIOD = 20.000;  // External Clock source, in [ns]
  localparam LEDG_SIZE = 8;  // The number of LEDs on the board
  // Testbench own paramters - for simulation:
  localparam MAX_SIM_TIME_LED_INCR = 200; // Timeout after 200 LED (count) periods - LED increments
    
  // Testbench signals - matching DUT's : 
  logic EXTCLK; 
  logic [1:0] KEY; // active-low
  logic [7:0] LEDG; // active-high
  
  // Testbench derived parameters - matching DUT's:
  localparam LEDG_CNTR_WIDTH = LEDG_SIZE-1; // This is both the reg. width of the led counter, and its MSb position - within the LEDG array 
  localparam LEDG_OVRFL_POS  = $high(LEDG); // This is the position of the  overflow indicator - within the LEDG array 
  localparam COUNT_FREQ = EXT_CLOCK_FREQ / 5; // LEDG counting frequency is 0.2 [s]. NOTE: This must match the DUT's !
  localparam COUNT_WIDTH = $clog2(COUNT_FREQ);

  // Testbench (control/monitor) signals:
  integer test_count = 0;
  integer pass_count = 0;
  integer fail_count = 0; 
  string  test_name;
   
  // Testbench (for DUT's internal/checking/misc) signals:
  integer expected_led_counter = 0; // this also refers to DUT's (internal) 'led_counter' for checking 
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
    // Initialize inputs
    KEY = 2'b11; // Not in reset, not enabled (both buttons are unpressed - active-low)
    
    // Display testbench header info
    $display("================================================================================");
    $display("  Testbench for 'clk_counter_leds_top' Module");
    $display("================================================================================");
    $display("  Clock Frequency:     %0d Hz", EXT_CLOCK_FREQ);
    $display("  Clock Period:        %0.3f ns", EXT_CLOCK_PERIOD);
    $display("  LED Update Period:   0.2 seconds (%0d clocks)", COUNT_FREQ);
    $display("  Counter Width:       %0d bits", LEDG_CNTR_WIDTH);
    $display("================================================================================\n");
    
    // Test #1: Reset behaviour test 
    test_count++;
    test_name = "Power-On Reset";
    $display("\n--- TEST %0d: %s ---", test_count, test_name);
    wait_clocks(5);
    apply_reset(10);
    check_ledg_correctness();
    
    // Test #2: LED counting enable test 
    test_count++;
    test_name = "LED Counting Enable";
    $display("\n--- TEST %0d: %s ---", test_count, test_name);
    assert_counter_enable();
    wait_till_led_increment();
    check_ledg_correctness();
    
    // Test #3: LED counting disable test 
    test_count++;
    test_name = "LED Counting Disable";
    $display("\n--- TEST %0d: %s ---", test_count, test_name);
    deassert_counter_enable();
    wait_clocks(COUNT_FREQ * 2); // Wait for 2 LED increment periods
    check_ledg_correctness(); // LEDG should not have changed 
    
    // Test #4: Overflow behaviour test 
    test_count++;
    test_name = "Overflow Behaviour";
    $display("\n--- TEST %0d: %s ---", test_count, test_name);
    assert_counter_enable();
    // Wait until overflow occurs
    begin
      integer cycles_to_overflow;
      cycles_to_overflow = ((2**LEDG_CNTR_WIDTH) - expected_led_counter) * COUNT_FREQ - expected_clk_counter;
      wait_clocks(cycles_to_overflow);
      check_ledg_correctness();
    end
    // Wait one more LED increment period to check post-overflow behaviour 
    wait_till_led_increment();
    // Plus 100 extra clock cycle to ensure and make visible the overflow indication is cleared
    wait_clocks(100);
    
    // Testbench summary report
    $display("\n================================================================================");
    $display("  TESTBENCH SUMMARY REPORT");
    $display("================================================================================");
    $display("  Total Tests Executed: %0d", test_count);
    $display("  Tests Passed:         %0d", pass_count);
    $display("  Tests Failed:         %0d", fail_count);
    $display("================================================================================\n");
    
    $finish; // End simulation

  end
  // =============================================================================
  // TIMEOUT WATCHDOG
  // =============================================================================
  initial begin 
    #(COUNT_FREQ * EXT_CLOCK_PERIOD * MAX_SIM_TIME_LED_INCR);
    $display("\n[ERROR] Watchdog - Simulation Timeout at time: %0t", $time);
    $display("[ERROR] Testbench did not complete within expected time!");
    fail_count++;
    $finish;
  end
  
  // =============================================================================
  // CONTINUOUS MONITORING (OPTIONAL DEBUG)
  // =============================================================================
  // Monitor for 'X' (unknown) or 'Z' (high-impedance) states in DUT's LEDG output
  always @(posedge EXTCLK) begin 
    if(KEY[0] === 1'b1) begin // Only when not in reset ...
      if(^LEDG === 1'bx) begin // If any bit of LEDG is 'X' or 'Z' (^-operator sums all bits together, resulting in 'X' if any bit is 'X' or 'Z')
        $display("[ERROR] Continous Monitoring - LEDs contain 'X' or 'Z' values at time: %0t", $time);
        fail_count++;
      end 
    end 
  end   

  // Check overflow indication correctness  
  always @(LEDG) begin 
    if((LEDG[LEDG_OVRFL_POS] == 1'b1) && ( LEDG[LEDG_CNTR_WIDTH-1:0] != '0)) begin // Only when all LED' counter part are 0, is the LED' overflow indication supposed to be ON (due to overflow). 
        $display("[ERROR] Continous Monitoring - Overflow occuring unexpectedly at time: %0t", $time);
        fail_count++;   
    end
  end 

  // =============================================================================
  // TESTBENCH TASKS AND FUNCTIONS
  // =============================================================================
  // Task: Assert DUT reset
  task apply_reset(input integer duration_clocks);
    begin 
      $display("\n[INFO]  Applying reset for %0d clock cycles...", duration_clocks);
      KEY[0] = 1'b0; // Apply reset (active-low)
      expected_clk_counter = '0;
      expected_led_counter = '0;
      expected_overflow = 1'b0;
      repeat(duration_clocks) @(posedge EXTCLK);
      KEY[0] = 1'b1; // De-apply reset (active-low)
      @(posedge EXTCLK); // Wait one clock cycle after reset release
      $display("[INFO]  Reset released\n");
    end
  endtask

  // Task: Assert (enable) DUT LED counting 
  task assert_counter_enable();
    begin 
      KEY[1] = 1'b0; // Apply enable (active-low)
      @(posedge EXTCLK); // Wait one clock cycle after enable
      $display("[INFO]  LED Counting enabled\n");
    end
  endtask   
 
  // Task: De-assert (disable) DUT LED counting
  task deassert_counter_enable();
    begin 
      KEY[1] = 1'b1; // De-apply enable (active-low)
      @(posedge EXTCLK); // Wait one clock cycle after disable
      expected_clk_counter = 0;
      $display("[INFO]  LED Counting disabled\n");
    end
  endtask

  // Task: Wait for a number of EXTCLK clock cycles
  task wait_clocks(input integer num_clocks);
    begin 
      repeat(num_clocks) begin 
        @(posedge EXTCLK);
        if(KEY[1] == 1'b0) begin // If counting is enabled
          if(expected_clk_counter == COUNT_FREQ-1)begin 
            if(expected_led_counter == (2**LEDG_CNTR_WIDTH)-1) begin 
              expected_overflow = 1'b1;
            end else begin 
              expected_overflow = 1'b0;
            end
            expected_led_counter = (expected_led_counter + 1) % (2**LEDG_CNTR_WIDTH);
          end
          expected_clk_counter = (expected_clk_counter + 1) % COUNT_FREQ;
        end
      end
      $display("[INFO]  Waited %0d clock cycles", num_clocks);
    end
  endtask   

  // Task: Wait for LED counter to increment
  task wait_till_led_increment();
    integer clk_cycles_needed;
    begin   
      clk_cycles_needed = COUNT_FREQ - expected_clk_counter;
      $display("[INFO]  Waiting for LED increment, requiring %0d clock cycles...", clk_cycles_needed);
      wait_clocks(clk_cycles_needed);
      $display("[INFO]  LED incremented, expected LEDG value: %0h", {expected_overflow, expected_led_counter[LEDG_CNTR_WIDTH-1:0]});
    end 
  endtask 
 
  // Task: Check DUT's LEDG correctness against expected value
  task check_ledg_correctness();
    logic [LEDG_SIZE-1:0] expected_ledg;
    begin 
      expected_ledg = {expected_overflow, expected_led_counter[LEDG_CNTR_WIDTH-1:0]};
      if(LEDG !== expected_ledg) begin 
        $display("[ERROR] LEDG correctness check failed at time: %0t", $time);
        $display("[ERROR]   Expected LEDG: %0h, Actual LEDG: %0h", expected_ledg, LEDG);
        fail_count++;
      end else begin 
        $display("[INFO]  LEDG correctness check passed at time: %0t", $time);
        pass_count++;
      end
    end
  endtask

  // Function: Calculate expected LEDG value, given the elapsed total (overall) number of clocks (since last reset)
  function logic [LEDG_SIZE-1:0] calculate_expected_ledg(input integer total_clk_counts);
    logic [LEDG_CNTR_WIDTH-1:0] led_counter_value;
    logic led_overflow_bit;
    begin 
      led_counter_value = (total_clk_counts % (2**LEDG_CNTR_WIDTH));
      led_overflow_bit = (total_clk_counts / (2**LEDG_CNTR_WIDTH)) > 0 ? 1'b1 : 1'b0;
      calculate_expected_ledg = {led_overflow_bit, led_counter_value};
    end
  endfunction

  // =============================================================================
  // ASSERTION-BASED VERIFICATION
  // =============================================================================
  `ifdef ASSERTIONS_ENABLED 
  
  // Property: DUT's reset behaviour
  property reset_behavior;
    @(posedge EXTCLK) // Trigger: on every positive edge of EXTCLK,
    (KEY[0] != 1'b1) // Condition: KEY[0] (DUT reset) is pressed
    |-> (LEDG == '0); // Expected Behaviour (in the next clock cycle): the LEDs are all turned off (immediately).
  endproperty
  
  // Property: DUT's clock counter increment timing
  property clk_increment;
    @(posedge EXTCLK) // Trigger: on every positive edge of EXTCLK,
    (KEY[0] && $past(KEY[0]) && (KEY[1] && $past(KEY[1]))) // Condition: KEY[0] (DUT reset) and KEY[1] (clk counter enable) were not asserted and were not asserted in the previous cycle
    |-> ((DUT.clk_counter == ($past(DUT.clk_counter) + 1'b1)) || // // Expected Behaviour (in the same clock cycle): The clk counter should either increment, or, ...
         ((DUT.clk_counter == '0) && $past(DUT.clk_counter == (COUNT_FREQ-1)))); // ...  wrap around from maximum COUNT threshold to zero
  endproperty
  
  // Property: DUT's LEDs should increment
  property led_increment;
    @(posedge EXTCLK)  // Trigger: on every positive edge of EXTCLK,
    (KEY[0] && KEY[1] && (DUT.clk_counter == (COUNT_FREQ-1))) // Condition: KEY[0] (DUT reset) and KEY[1] (clk counter enable) are not asserted, and clock counter has reached COUNT limit to incrmement the LEDs (counter)
    |=> (LEDG[LEDG_CNTR_WIDTH-1:0] == ($past(LEDG[LEDG_CNTR_WIDTH-1:0]) + 1'b1)); // Expected Behaviour (in the next clock cycle): The LEDs should increment, or, wrap around from the maximum to 0  
  endproperty
  
  // Property: DUT's overflow indication
  property overflow_indication;
    @(posedge EXTCLK) // Trigger: on every positive edge of EXTCLK, 
    (KEY[0] && KEY[1] && ((LEDG[LEDG_CNTR_WIDTH-1:0] + 1'b1) == '0)) // Condition: KEY[0] (DUT reset) and KEY1[1] (clk counter enable) are not asserted, and LEDG (counter) has reached its limit and is about to roll-over.     
    |=> ((LEDG[LEDG_OVRFL_POS] == 1'b1) && (LEDG[LEDG_CNTR_WIDTH-1:0] == '0)); // Expected Behaviour (in the next clock cycle): The  Overlflow LED indicator should turn on, and the Counter LEDs should turn off. 
  endproperty
  
  // Property: DUT's not counting when disabled
  property no_count_when_disabled;
    @(posedge EXTCLK)  // Trigger: on every positive edge of EXTCLK, 
     disable iff(!KEY[0]) // Assertion Control: Disable assertion when KEY[0] (DUT reset) is asserted
     !KEY[1]  // Condition: the KEY1[1] (clk counter enable) is asserted 
     |=> $stable(LEDG[LEDG_CNTR_WIDTH-1:0]); // Expected Behaviour (in the next clock cycle): The LEDG (counter) should remain stable (not change).
  endproperty
  
  // Bind assertions: 
  assert property (reset_behavior) 
    else begin 
      $display("[ERROR] Assertion - Reset behaviour failed at time: %t", $time);
      fail_count++;
    end
    
  assert property (clk_increment)   
    else begin 
        $display("[ERROR] Assertion - Clock counter incrementation timing failed at time: %t", $time); 
        fail_count++;
    end
    
  assert property (led_increment)
    else begin 
      $display("[ERROR] Assertion - LEDs counting (incrementation) timing failed at time: %t", $time); 
      fail_count++;
    end
    
  assert property (overflow_indication)
    else begin 
      $display("[ERROR] Assertion - Overflow indication failed at time: %t", $time);
      fail_count++;
    end

  assert property (no_count_when_disabled)
    else begin 
      $display("[ERROR] Assertion - Not counting when disabled failed at time: %t", $time);
      fail_count++;
    end

  `endif // ASSERTIONS_ENABLED
  
  // =============================================================================
  // WAVEFORM DUMPING 
  // =============================================================================
  initial begin 
    $dumpfile("clk_counter_leds_top_tb.vcd"); // VCD file for GTKWave or other waveform viewer 
    // $dumpvars(0, clk_counter_leds_top_tb); // dump all signals of this TB and below. Note:  Commented out to reduce VCD size and runtime.
    // Add flush points for better waveform viewing
    forever begin 
      @((negedge KEY[0], posedge KEY[0]) or (negedge KEY[1], posedge KEY[1])) // When we either Reset or Enable the clock/led counter - flush vcd
        $dumpflush;
    end 
  end 

  
endmodule 