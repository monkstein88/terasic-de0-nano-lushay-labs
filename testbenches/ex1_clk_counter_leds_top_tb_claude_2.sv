`timescale 1ns / 1ps

module tb_clk_counter_leds_top;

  // ============================================================================
  // Testbench Parameters
  // ============================================================================
  localparam EXT_CLOCK_FREQ   = 50000000;  // 50 MHz
  localparam EXT_CLOCK_PERIOD = 20.0;      // 20 ns
  localparam LEDG_SIZE        = 8;
  
  // Derived parameters (matching DUT)
  localparam LED_CNTR_WIDTH = LEDG_SIZE - 1;  // 7 bits
  localparam COUNT_FREQ     = EXT_CLOCK_FREQ / 5;  // 10M clocks per LED update
  localparam COUNT_WIDTH    = $clog2(COUNT_FREQ);
  
  // ============================================================================
  // Testbench Signals
  // ============================================================================
  logic        EXTCLK;
  logic [1:0]  KEY;
  logic [7:0]  LEDG;
  
  // Test control signals
  int test_counter;
  int error_counter;
  string test_name;
  
  // ============================================================================
  // DUT Instantiation
  // ============================================================================
  clk_counter_leds_top #(
    .EXT_CLOCK_FREQ   (EXT_CLOCK_FREQ),
    .EXT_CLOCK_PERIOD (EXT_CLOCK_PERIOD),
    .LEDG_SIZE        (LEDG_SIZE)
  ) dut (
    .EXTCLK (EXTCLK),
    .KEY    (KEY),
    .LEDG   (LEDG)
  );
  
  // ============================================================================
  // Clock Generation
  // ============================================================================
  initial begin
    EXTCLK = 0;
    forever #(EXT_CLOCK_PERIOD/2) EXTCLK = ~EXTCLK;
  end
  
  // ============================================================================
  // Waveform Dump
  // ============================================================================
  initial begin
    $dumpfile("clk_counter_leds_top.vcd");
    $dumpvars(0, tb_clk_counter_leds_top);
  end
  
  // ============================================================================
  // Test Monitoring Task
  // ============================================================================
  task automatic check_leds(
    input logic [6:0] expected_counter,
    input logic expected_overflow,
    input string description
  );
    logic [6:0] actual_counter;
    logic actual_overflow;
    
    actual_counter  = LEDG[6:0];
    actual_overflow = LEDG[7];
    
    if (actual_counter !== expected_counter || actual_overflow !== expected_overflow) begin
      $display("[ERROR] %s", description);
      $display("        Expected: Counter=0x%0h, Overflow=%b", expected_counter, expected_overflow);
      $display("        Got:      Counter=0x%0h, Overflow=%b", actual_counter, actual_overflow);
      $display("        Time: %0t ns", $time);
      error_counter++;
    end else begin
      $display("[PASS]  %s - Counter=0x%0h, Overflow=%b @ %0t ns", 
               description, actual_counter, actual_overflow, $time);
    end
  endtask
  
  // ============================================================================
  // Task: Wait for N clock cycles
  // ============================================================================
  task automatic wait_clocks(input int num_clocks);
    repeat(num_clocks) @(posedge EXTCLK);
  endtask
  
  // ============================================================================
  // Task: Apply Reset
  // ============================================================================
  task automatic apply_reset(input int reset_cycles);
    $display("\n[INFO]  Applying reset for %0d clock cycles...", reset_cycles);
    KEY[0] = 0;  // Assert reset (active-low)
    wait_clocks(reset_cycles);
    KEY[0] = 1;  // Deassert reset
    wait_clocks(2);  // Stabilization time
    $display("[INFO]  Reset released\n");
  endtask
  
  // ============================================================================
  // Task: Wait for LED counter increment
  // ============================================================================
  task automatic wait_for_led_increment();
    logic [6:0] current_count;
    current_count = LEDG[6:0];
    
    $display("[INFO]  Waiting for LED counter to increment from 0x%0h...", current_count);
    
    // Wait for COUNT_FREQ clock cycles (plus some margin)
    wait_clocks(COUNT_FREQ + 10);
    
    if (LEDG[6:0] == current_count + 1) begin
      $display("[INFO]  LED counter successfully incremented to 0x%0h @ %0t ns", LEDG[6:0], $time);
    end else begin
      $display("[ERROR] LED counter did not increment as expected!");
      $display("        Expected: 0x%0h, Got: 0x%0h", current_count + 1, LEDG[6:0]);
      error_counter++;
    end
  endtask
  
  // ============================================================================
  // Task: Monitor overflow flag duration
  // ============================================================================
  task automatic check_overflow_pulse();
    int overflow_start_time;
    int overflow_duration;
    logic overflow_detected;
    
    $display("[INFO]  Monitoring overflow flag behavior...");
    overflow_detected = 0;
    
    // Wait until overflow occurs
    wait(LEDG[7] == 1);
    overflow_detected = 1;
    overflow_start_time = $time;
    $display("[INFO]  Overflow flag asserted at %0t ns", $time);
    
    // Measure how long it stays high
    wait(LEDG[7] == 0);
    overflow_duration = $time - overflow_start_time;
    $display("[INFO]  Overflow flag duration: %0d ns (%0d clocks)", 
             overflow_duration, overflow_duration/EXT_CLOCK_PERIOD);
    
    // Check if it's a single-cycle pulse or longer
    if (overflow_duration <= 2*EXT_CLOCK_PERIOD) begin
      $display("[PASS]  Overflow is a short pulse (1-2 clock cycles)");
    end else if (overflow_duration >= COUNT_FREQ * EXT_CLOCK_PERIOD * 0.9) begin
      $display("[WARN]  Overflow remains high for full counting period");
      $display("        This may be intentional, but comment suggests single-cycle pulse");
    end else begin
      $display("[INFO]  Overflow duration is intermediate: %0d clocks", 
               overflow_duration/EXT_CLOCK_PERIOD);
    end
  endtask
  
  // ============================================================================
  // Main Test Sequence
  // ============================================================================
  initial begin
    // Initialize
    error_counter = 0;
    test_counter = 0;
    KEY = 2'b11;  // Both buttons released (active-low)
    
    $display("================================================================================");
    $display("  Testbench for clk_counter_leds_top Module");
    $display("================================================================================");
    $display("  Clock Frequency:     %0d Hz", EXT_CLOCK_FREQ);
    $display("  Clock Period:        %0.3f ns", EXT_CLOCK_PERIOD);
    $display("  LED Update Period:   0.2 seconds (%0d clocks)", COUNT_FREQ);
    $display("  Counter Width:       %0d bits", LED_CNTR_WIDTH);
    $display("================================================================================\n");
    
    // ========================================================================
    // TEST 1: Power-On Reset Check
    // ========================================================================
    test_name = "TEST 1: Power-On Reset";
    $display("\n--- %s ---", test_name);
    wait_clocks(5);
    apply_reset(10);
    check_leds(7'h00, 1'b0, "After reset, all counters should be zero");
    
    // ========================================================================
    // TEST 2: Enable = 0 (Counting Disabled)
    // ========================================================================
    test_name = "TEST 2: Counting Disabled (Enable=0)";
    $display("\n--- %s ---", test_name);
    KEY[1] = 1;  // Disable (active-low, so 1 = disabled)
    wait_clocks(COUNT_FREQ * 2);  // Wait for 2 LED update periods
    check_leds(7'h00, 1'b0, "Counter should remain at 0 when disabled");
    
    // ========================================================================
    // TEST 3: Enable Counting and Verify First Increment
    // ========================================================================
    test_name = "TEST 3: First Counter Increment";
    $display("\n--- %s ---", test_name);
    KEY[1] = 0;  // Enable counting (active-low)
    wait_clocks(5);
    check_leds(7'h00, 1'b0, "Counter should still be 0 initially");
    
    wait_for_led_increment();
    check_leds(7'h01, 1'b0, "Counter should increment to 1");
    
    // ========================================================================
    // TEST 4: Verify Multiple Increments
    // ========================================================================
    test_name = "TEST 4: Multiple Counter Increments";
    $display("\n--- %s ---", test_name);
    
    for (int i = 2; i <= 5; i++) begin
      wait_for_led_increment();
      check_leds(i[6:0], 1'b0, $sformatf("Counter should be 0x%0h", i));
    end
    
    // ========================================================================
    // TEST 5: Pause and Resume
    // ========================================================================
    test_name = "TEST 5: Pause and Resume Counting";
    $display("\n--- %s ---", test_name);
    
    logic [6:0] count_before_pause;
    count_before_pause = LEDG[6:0];
    
    KEY[1] = 1;  // Pause
    $display("[INFO]  Pausing counter at value 0x%0h", count_before_pause);
    wait_clocks(COUNT_FREQ * 3);  // Wait for 3 LED periods
    check_leds(count_before_pause, 1'b0, "Counter should hold value when paused");
    
    KEY[1] = 0;  // Resume
    $display("[INFO]  Resuming counter");
    wait_for_led_increment();
    check_leds(count_before_pause + 1, 1'b0, "Counter should resume from previous value");
    
    // ========================================================================
    // TEST 6: Reset During Counting
    // ========================================================================
    test_name = "TEST 6: Reset During Counting";
    $display("\n--- %s ---", test_name);
    
    wait_clocks(COUNT_FREQ / 2);  // Wait halfway through a count period
    apply_reset(5);
    check_leds(7'h00, 1'b0, "Reset should clear counter to 0");
    
    wait_for_led_increment();
    check_leds(7'h01, 1'b0, "Counter should restart from 0 after reset");
    
    // ========================================================================
    // TEST 7: Count to Near Overflow
    // ========================================================================
    test_name = "TEST 7: Count to Near Maximum";
    $display("\n--- %s ---", test_name);
    
    // Fast-forward to near overflow by forcing internal counter
    // (In real simulation, you might use hierarchical reference or wait longer)
    $display("[INFO]  Fast-forwarding to counter value 0x7C...");
    
    // Force the counter (requires hierarchical reference)
    force dut.led_counter = 7'h7C;
    force dut.clk_counter = '0;
    wait_clocks(2);
    release dut.led_counter;
    release dut.clk_counter;
    
    // Now count normally to verify behavior near overflow
    for (int i = 0; i < 3; i++) begin
      wait_for_led_increment();
    end
    
    check_leds(7'h7F, 1'b0, "Counter should reach maximum (0x7F)");
    
    // ========================================================================
    // TEST 8: Overflow Detection
    // ========================================================================
    test_name = "TEST 8: Overflow Detection";
    $display("\n--- %s ---", test_name);
    
    $display("[INFO]  Counter at 0x7F, waiting for overflow...");
    
    // Fork a process to monitor overflow pulse
    fork
      begin
        check_overflow_pulse();
      end
      begin
        wait_for_led_increment();
      end
    join
    
    check_leds(7'h00, 1'b0, "Counter should wrap to 0 after overflow");
    
    // ========================================================================
    // TEST 9: Verify Counting Continues After Overflow
    // ========================================================================
    test_name = "TEST 9: Counting After Overflow";
    $display("\n--- %s ---", test_name);
    
    for (int i = 1; i <= 3; i++) begin
      wait_for_led_increment();
      check_leds(i[6:0], 1'b0, $sformatf("Counter continues: 0x%0h", i));
    end
    
    // ========================================================================
    // TEST 10: Rapid Enable/Disable Toggling
    // ========================================================================
    test_name = "TEST 10: Rapid Enable Toggle";
    $display("\n--- %s ---", test_name);
    
    logic [6:0] stable_count;
    stable_count = LEDG[6:0];
    
    // Toggle enable rapidly
    repeat(20) begin
      KEY[1] = ~KEY[1];
      wait_clocks(100);
    end
    
    KEY[1] = 0;  // Leave enabled
    wait_clocks(10);
    
    $display("[INFO]  After rapid toggling, counter is at 0x%0h", LEDG[6:0]);
    $display("[INFO]  This test verifies the design doesn't malfunction during rapid toggling");
    
    // ========================================================================
    // TEST 11: Multiple Reset Cycles
    // ========================================================================
    test_name = "TEST 11: Multiple Reset Cycles";
    $display("\n--- %s ---", test_name);
    
    for (int i = 0; i < 3; i++) begin
      wait_for_led_increment();
      apply_reset(3);
      check_leds(7'h00, 1'b0, $sformatf("Reset #%0d: Counter cleared", i+1));
    end
    
    // ========================================================================
    // TEST COMPLETION
    // ========================================================================
    $display("\n================================================================================");
    $display("  TEST SUMMARY");
    $display("================================================================================");
    $display("  Total Tests:  11");
    $display("  Errors:       %0d", error_counter);
    
    if (error_counter == 0) begin
      $display("  Status:       ALL TESTS PASSED ✓");
    end else begin
      $display("  Status:       TESTS FAILED ✗");
    end
    $display("================================================================================\n");
    
    // Finish simulation
    wait_clocks(100);
    $finish;
  end
  
  // ============================================================================
  // Timeout Watchdog
  // ============================================================================
  initial begin
    #(COUNT_FREQ * EXT_CLOCK_PERIOD * 200);  // Timeout after 200 LED periods
    $display("\n[ERROR] Simulation timeout!");
    $display("[ERROR] Testbench did not complete within expected time");
    $finish;
  end
  
  // ============================================================================
  // Continuous Monitoring (Optional Debug)
  // ============================================================================
  logic [6:0] prev_counter;
  logic prev_overflow;
  
  initial begin
    prev_counter = 0;
    prev_overflow = 0;
    forever begin
      @(posedge EXTCLK);
      
      // Detect counter changes
      if (LEDG[6:0] !== prev_counter) begin
        $display("[DEBUG] LED Counter changed: 0x%0h -> 0x%0h @ %0t ns", 
                 prev_counter, LEDG[6:0], $time);
        prev_counter = LEDG[6:0];
      end
      
      // Detect overflow changes
      if (LEDG[7] !== prev_overflow) begin
        $display("[DEBUG] Overflow flag changed: %b -> %b @ %0t ns", 
                 prev_overflow, LEDG[7], $time);
        prev_overflow = LEDG[7];
      end
    end
  end

endmodule