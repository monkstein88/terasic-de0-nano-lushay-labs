// Testbench for debounce module
`timescale 1ns / 1ps // Note: the simulation time unit must be set to 1 [ns]

module debounce_tb;

  // =============================================================================
  // TESTBENCH PARAMETERS AND CONSTANTS
  // =============================================================================
  // Testbench parameters - matching DUT's:
  localparam CLK_FREQ = 50_000_000; // External Clock source, in [Hz]
  localparam CLK_PERIOD = 20;       // External Clock source, in [ns]
  localparam DEBOUNCE_TIME = 1;     // Debounce (Filter) time in [ms]
  // Testbench parameters - for simulation:
  localparam MAX_SIMULATION_TIME = 100_000_000; // Simulation time in [ns]
  localparam DEBOUNCE_CYCLES = (CLK_FREQ / 1000) * DEBOUNCE_TIME;
  // =============================================================================
  // TESTBENCH SIGNALS
  // =============================================================================
  // DUT signals:
  logic clk;      // Clock signal
  logic arst_n_i; // Asynchronous reset input - active low
  logic din_i;       // Input signal to be debounced
  logic deb_o_low;   // Debounced output signal - initial value '0'
  logic deb_o_high;  // Debounced output signal - initial value '1'
  // Testbench variables:
  int unsigned test_count = 0;
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // =============================================================================
  // CLOCK GENERATION
  // =============================================================================
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk; // Toggle clock every half period
  end   

  // =============================================================================
  // UNIT UNDER TEST (UUT) INSTANTIATION
  // =============================================================================
  // Dеbounce module instantiation - two instances with different initial values
  debounce #(
    .CLK_FREQ(CLK_FREQ),
    .DEBOUNCE_TIME(DEBOUNCE_TIME),
    .DEBOUNCE_INIT(1'b0)
  ) UUT_INIT_LOW (
    .arst_n_i(arst_n_i),
    .clk_i(clk),
    .din_i(din_i),
    .deb_o(deb_o_low)
  );

  debounce #(
    .CLK_FREQ(CLK_FREQ),
    .DEBOUNCE_TIME(DEBOUNCE_TIME),
    .DEBOUNCE_INIT(1'b1)
  ) UUT_INIT_HIGH (
    .arst_n_i(arst_n_i),
    .clk_i(clk),
    .din_i(din_i),
    .deb_o(deb_o_high)
  );

  // ============================================================================
  // TASKS AND FUNCTIONS
  // ============================================================================
  // Task to wait for a number of tb time units - not clock cycles
  task wait_period(input int num_time_units);
    #(num_time_units);
  endtask

  // Task to wait for a number of clock cycles
  task wait_cycles(input int num_cycles);
    repeat(num_cycles) @(posedge clk);
  endtask
  
  // Task to apply glitches (brief pulses)
  task apply_glitch(input logic value, input int duration_cycles);
    din = value;
    wait_cycles(duration_cycles);
    din = ~value;
  endtask
  
  // Task to check expected output
  task check_output(input logic expected_for_high, input logic expected_for_low, input string test_name);
    if (deb_o_high !== expected_for_high) || (deb_o_low !== expected_for_low) begin
      $display("ERROR [%0t ns] %s: Expected deb_o_high=%b, deb_o_low=%b, got deb_o_high=%b, deb_o_low=%b", 
               $time, test_name, expected_for_high, expected_for_low, deb_o_high, deb_o_low);
      errors++;
    end else begin
      $display("PASS [%0t ns] %s: deb_o_high=%b and deb_o_low=%b as expected", 
               $time, test_name, deb_o_high, deb_o_low);
    end
  endtask

  // =============================================================================
  // TEST SEQUENCE
  // =============================================================================
  // Display testbench header information
  $display("========================================");
  $display("Debouncer Testbench Starting...");
  $display("========================================");
  $display("Clock Frequency: %0d [Hz]", CLK_FREQ);    
  $display("Clock Period: %0d [ns]", CLK_PERIOD);
  $display("Debounce Init Values: %s", "Both LOW and HIGH");
  $display("Debounce Time: %0d [ms]", DEBOUNCE_TIME);
  $display("");

  // Wait for a short time before starting tests - to observe initial conditions
  wait_period(CLK_PERIOD * 5); 

  // Initialize signals
  arst_n_i = 1'b1; // Assert reset
  din_i = 1'b0;    // Initial input value

  wait_cycles(10); // Wait for a few clock cycles

  // Test 1: Apply reset
  test_num++;
  $display("\n--- Test %0d: Reset Test ---", test_num);
  arst_n_i = 0;
  wait_cycles(5);
  check_output(1'b1, 1'b0, "Reset state"); // Reset values are asserted immediately.
  arst_n_i = 1; // Release reset
  wait_cycles(5); 
  check_output(1'b1, 1'b0, "After reset release"); // Should remain at initial values, still.

  // Test 2: Short glitches should be filtered out
  test_num++;
  $display("\n--- Test %0d: Glitch Filtering (short pulses) ---", test_num);
  din_i = 0;
  wait_cycles(10);
  
  // Apply several short glitches
  for (int i = 0; i < 5; i++) begin
    apply_glitch(1'b1, 3); // 3-cycle glitch
    wait_cycles(5);
  end
  wait_cycles(10);
  check_output(1'b0, 1'b0, "After short glitches");
  
  // Test 3: Stable transition from 0 to 1
  test_num++;
  $display("\n--- Test %0d: Clean Transition 0->1 ---", test_num);
  din = 0;
  wait_cycles(10);
  din = 1;
  
  // Should still be 0 before debounce completes
  wait_cycles(DEBOUNCE_CYCLES - 5);
  check_output(1'b0, 1'b0, "Before debounce complete");
  
  // Wait for debounce to complete
  wait_cycles(10);
  check_output(1'b1, 1'b1, "After debounce complete");
  
  // Test 4: Glitches during debouncing should restart counter
  test_num++;
  $display("\n--- Test %0d: Glitch During Debounce ---", test_num);
  din = 1;
  wait_cycles(10);
  din = 0; // Start transition to 0
  
  // Midway through debounce, apply a glitch
  wait_cycles(DEBOUNCE_CYCLES / 2);
  din = 1; // Glitch back to 1
  wait_cycles(5);
  din = 0; // Back to 0 (counter should restart)
  
  // Output should still be 1
  wait_cycles(DEBOUNCE_CYCLES - 10);
  check_output(1'b1, 1'b1, "Glitch restarted counter");
  
  // Now wait full debounce time
  wait_cycles(20);
  check_output(1'b0, 1'b0, "After full debounce from glitch");
  
  // Test 5: Stable transition from 1 to 0
  test_num++;
  $display("\n--- Test %0d: Clean Transition 1->0 ---", test_num);
  din = 0;
  wait_cycles(10);
  din = 1;
  wait_cycles(DEBOUNCE_CYCLES + 10);
  check_output(1'b1, 1'b1, "Stable at 1");
  
  din = 0;
  wait_cycles(DEBOUNCE_CYCLES + 10);
  check_output(1'b0, 1'b0, "Transitioned to 0");
  
  // Test 6: Multiple rapid transitions (bouncing)
  test_num++;
  $display("\n--- Test %0d: Rapid Bouncing ---", test_num);
  din = 0;
  wait_cycles(10);
  
  // Simulate button bouncing
  for (int i = 0; i < 10; i++) begin
    din = ~din;
    wait_cycles($urandom_range(5, 20));
  end
  din = 1; // Settle to 1
  
  wait_cycles(DEBOUNCE_CYCLES + 10);
  check_output(1'b1, 1'b1, "After bouncing settled to 1");
  
  // Test 7: Reset during debouncing
  test_num++;
  $display("\n--- Test %0d: Reset During Debounce ---", test_num);
  din = 1;
  wait_cycles(10);
  din = 0; // Start transition
  wait_cycles(DEBOUNCE_CYCLES / 2); // Halfway through
  
  arst_n = 0; // Apply reset
  wait_cycles(3);
  check_output(1'b1, 1'b1, "During reset");
  arst_n = 1;
  wait_cycles(5);
  check_output(1'b0, 1'b0, "After reset with din=0");
  
  // Test 8: Verify timing accuracy
  test_num++;
  $display("\n--- Test %0d: Timing Verification ---", test_num);
  din = 0;
  wait_cycles(20);
  
  din = 1;
  fork
    begin
      wait_cycles(DEBOUNCE_CYCLES - 3);
      if (deb_o !== 1'b0) begin
        $display("ERROR: Output changed too early");
        errors++;
      end
    end
    begin
      wait_cycles(DEBOUNCE_CYCLES + 5);
      if (deb_o !== 1'b1) begin
        $display("ERROR: Output didn't change in time");
        errors++;
      end else begin
        $display("PASS: Timing accurate");
      end
    end
  join
  
  wait_cycles(20);
  
  // Test Summary
  $display("\n========================================");
  $display("Testbench Completed. Summary: ");
  $display("========================================");
  $display("Total tests run: %0d", test_num);
  if (errors == 0) begin
    $display("Result: ALL TESTS PASSED!");
  end else begin
    $display("Result: %0d ERRORS DETECTED", errors);
  end
  $display("========================================\n");
  
  $finish;


  // =============================================================================
  // WAVEFORM DUMPING 
  // =============================================================================
  initial begin
    $dumpfile("debounce_tb.vcd");
    $dumpvars(0, debounce_tb);
  end

  // =============================================================================
  // TIMEOUT WATCHDOG
  // =============================================================================
 initial begin
    #(CLK_PERIOD * DEBOUNCE_CYCLES * 50); // Generous timeout
    $display("ERROR: Testbench timeout!");
    $finish;
  end


endmodule 