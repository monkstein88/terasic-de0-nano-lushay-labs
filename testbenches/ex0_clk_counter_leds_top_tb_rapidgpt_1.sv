`timescale 1ns / 1ps

module clk_counter_leds_top_tb_elaborate();

// Parameters
parameter CLK_PERIOD_NS = 20;
parameter MAX_SIM_TIME = 1000000;
parameter COUNTER_WIDTH = 32; // Assuming 32-bit counter

// DUT signals
logic        EXTCLK;
logic        RST_N;
logic [7:0]  LEDG;

// Testbench control
logic        tb_clk_enable = 1;
int          test_count = 0;
int          pass_count = 0;
int          fail_count = 0;

// Expected values for checking
logic [7:0]  expected_ledg;
logic [31:0] prev_counter;

//=============================================================================
// Clock Generation
//=============================================================================
initial begin
  EXTCLK = 0;
  forever #(CLK_PERIOD_NS/2) begin
    if (tb_clk_enable) EXTCLK = ~EXTCLK;
  end
end

//=============================================================================
// DUT Instantiation
//=============================================================================
clk_counter_leds_top DUT (
  .EXTCLK(EXTCLK),
  .KEY({1'bx, RST_N}),
  .LEDG(LEDG)
);

//=============================================================================
// Test Tasks
//=============================================================================
task automatic reset_dut(input int cycles = 5);
  $display("[%t] Applying reset for %0d cycles", $time, cycles);
  RST_N = 0;
  repeat(cycles) @(posedge EXTCLK);
  RST_N = 1;
  @(posedge EXTCLK); // Wait one cycle after release
endtask

task automatic wait_clocks(input int cycles);
  repeat(cycles) @(posedge EXTCLK);
endtask

task automatic check_reset_behavior();
  test_count++;
  $display("\n=== TEST %0d: Reset Behavior ===", test_count);
  
  // Apply reset and check if counter goes to 0
  RST_N = 0;
  #1; // Small delay for combinational logic
  
  if (DUT.clk_counter === 0) begin
    $display("PASS: Counter reset to 0");
    pass_count++;
  end else begin
    $display("FAIL: Counter not reset (value: %h)", DUT.clk_counter);
    fail_count++;
  end
  
  @(posedge EXTCLK);
  RST_N = 1;
endtask

task automatic check_counting_behavior();
  test_count++;
  $display("\n=== TEST %0d: Counting Behavior ===", test_count);
  
  reset_dut(3);
  prev_counter = DUT.clk_counter;
  
  // Check if counter increments properly
  repeat(10) begin
    @(posedge EXTCLK);
    if (DUT.clk_counter !== (prev_counter + 1)) begin
      $display("FAIL: Counter increment error. Expected: %h, Got: %h", 
               prev_counter + 1, DUT.clk_counter);
      fail_count++;
      return;
    end
    prev_counter = DUT.clk_counter;
  end
  
  $display("PASS: Counter increments correctly");
  pass_count++;
endtask

task automatic check_led_mapping();
  test_count++;
  $display("\n=== TEST %0d: LED Mapping ===", test_count);
  
  reset_dut(2);
  
  // Check LED mapping for different counter values
  repeat(20) begin
    @(posedge EXTCLK);
    expected_ledg = DUT.clk_counter[31:24]; // Assuming upper 8 bits map to LEDs
    
    if (LEDG !== expected_ledg) begin
      $display("FAIL: LED mapping error at counter %h. Expected LEDs: %b, Got: %b", 
               DUT.clk_counter, expected_ledg, LEDG);
      fail_count++;
      return;
    end
  end
  
  $display("PASS: LED mapping correct");
  pass_count++;
endtask

task automatic stress_test_resets();
  test_count++;
  $display("\n=== TEST %0d: Stress Test - Random Resets ===", test_count);
  
  int reset_cycles, run_cycles;
  
  repeat(5) begin
    reset_cycles = $urandom_range(1, 5);
    run_cycles = $urandom_range(10, 50);
    
    reset_dut(reset_cycles);
    wait_clocks(run_cycles);
    
    // Quick sanity check
    if (DUT.clk_counter < run_cycles) begin
      $display("FAIL: Counter value %h less than expected minimum %h", 
               DUT.clk_counter, run_cycles);
      fail_count++;
      return;
    end
  end
  
  $display("PASS: Stress test completed successfully");
  pass_count++;
endtask

task automatic test_overflow_behavior();
  test_count++;
  $display("\n=== TEST %0d: Counter Overflow ===", test_count);
  
  reset_dut(2);
  
  // Force counter to near overflow for testing
  force DUT.clk_counter = 32'hFFFFFFFE;
  @(posedge EXTCLK);
  release DUT.clk_counter;
  
  // Check overflow behavior
  @(posedge EXTCLK);
  if (DUT.clk_counter !== 32'hFFFFFFFF) begin
    $display("FAIL: Counter didn't reach maximum value");
    fail_count++;
    return;
  end
  
  @(posedge EXTCLK);
  if (DUT.clk_counter !== 32'h00000000) begin
    $display("FAIL: Counter didn't wrap to zero. Value: %h", DUT.clk_counter);
    fail_count++;
    return;
  end
  
  $display("PASS: Counter overflow behavior correct");
  pass_count++;
endtask

//=============================================================================
// Main Test Sequence
//=============================================================================
initial begin
  $display("=== Starting Elaborate Counter Testbench ===");
  $display("Clock Period: %0d ns", CLK_PERIOD_NS);
  
  // Initialize
  RST_N = 1;
  #(CLK_PERIOD_NS * 2);
  
  // Run comprehensive test suite
  check_reset_behavior();
  check_counting_behavior();
  check_led_mapping();
  stress_test_resets();
  test_overflow_behavior();
  
  // Final simulation time
  #(CLK_PERIOD_NS * 20);
  
  // Test Summary
  $display("\n" + "="*50);
  $display("TEST SUMMARY");
  $display("="*50);
  $display("Total Tests: %0d", test_count);
  $display("Passed:      %0d", pass_count);
  $display("Failed:      %0d", fail_count);
  $display("Success Rate: %0.1f%%", (pass_count * 100.0) / test_count);
  
  if (fail_count == 0) begin
    $display("*** ALL TESTS PASSED ***");
  end else begin
    $display("*** %0d TEST(S) FAILED ***", fail_count);
  end
  
  $finish;
end

//=============================================================================
// Continuous Monitoring
//=============================================================================
// Enhanced monitoring with change detection
logic [7:0] ledg_prev = 0;
logic [31:0] counter_prev = 0;

always @(posedge EXTCLK) begin
  if (RST_N) begin
    // Monitor counter changes
    if (DUT.clk_counter !== counter_prev) begin
      $display("[%t] Counter: %8h -> %8h | LEDs: %8b", 
               $time, counter_prev, DUT.clk_counter, LEDG);
    end
    
    // Monitor LED changes
    if (LEDG !== ledg_prev) begin
      $display("[%t] *** LED CHANGE: %8b -> %8b ***", 
               $time, ledg_prev, LEDG);
    end
    
    counter_prev <= DUT.clk_counter;
    ledg_prev <= LEDG;
  end
end

//=============================================================================
// Safety Features
//=============================================================================
// Simulation timeout
initial begin
  #MAX_SIM_TIME;
  $display("ERROR: Simulation timeout reached!");
  $finish;
end

// Waveform generation
initial begin
  $dumpfile("elaborate_tb.vcd");
  $dumpvars(0, clk_counter_leds_top_tb_elaborate);
  
  // Add flush points for better waveform viewing
  forever begin
    @(negedge RST_N or posedge RST_N);
    $dumpflush;
  end
end

//=============================================================================
// Assertions (if supported by your simulator)
//=============================================================================
`ifdef ASSERTIONS_ENABLED
// Counter should increment when not in reset
property counter_increment;
  @(posedge EXTCLK) RST_N && $past(RST_N) |-> 
    (DUT.clk_counter == $past(DUT.clk_counter) + 1) ||
    ($past(DUT.clk_counter) == 32'hFFFFFFFF && DUT.clk_counter == 0);
endproperty

// Counter should be 0 when in reset
property reset_behavior;
  @(posedge EXTCLK) !RST_N |-> (DUT.clk_counter == 0);
endproperty

assert_increment: assert property(counter_increment)
  else $error("Counter increment assertion failed at %t", $time);

assert_reset: assert property(reset_behavior)
  else $error("Reset assertion failed at %t", $time);
`endif

endmodule
