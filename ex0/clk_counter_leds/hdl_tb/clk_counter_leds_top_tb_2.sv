/* A more complicated self-testing testbench to create stimuli to observe the waveforms/behaviour of the counter and the outputs */

// The timescale directive specifies the time unit and time precision for the simulation
`timescale 1ns / 1ps

module clk_counter_leds_top_tb_2();

  // Parameters matching the DUT:
  parameter EXT_CLOCK_FREQ = 50000000; // External Clock source, in [Hz]
  parameter EXT_CLOCK_PERIOD = 20.000;  // External Clock source, in [ns]
  
  // Testbench parameters:
  parameter CLK_PERIOD_NS = 20; // with 1 [ns] time unit, a clk period of 20 [ns] (50 [MHz]), is 20 [units] 
  parameter RESET_CYCLES = 5; // number of clock cycles to hold reset active
  parameter TEST_DURATION = 200; // number of clock cycles to run the test 
  
  // DUT signals: 
  logic         EXTCLK;
  logic  [1:0]  KEY;
  logic  [7:0]  LEDG;
  
  // Testbench variables/contorls:
  logic          tb_CLK_ena; // clock enable signal for EXTCLK
  logic  [31:0]  expected_counter; // expected counter value
  logic   [7:0]  expected_leds; // expected leds value
  integer        test_case;  // current test case number 
  integer        errors_count; // count of errors detected
  integer        cycle_count; // count of clock cycles elapsed
  
  // DUT instantiation:
  clk_counter_leds_top 
  #(
    .EXT_CLOCK_FREQ(EXT_CLOCK_FREQ),
    .EXT_CLOCK_PERIOD(EXT_CLOCK_PERIOD)
  ) DUT (
    .EXTCLK(EXTCLK), // external clock input 
    .KEY(KEY),// active-low reset on KEY[0], KEY[1] is not used
    .LEDG(LEDG) // 8 green leds output
  );
  
  // Testbench clock generation
  initial begin
    EXTCLK = 0; // set the initial Clock state - low 
    forever #(CLK_PERIOD_NS/2) EXTCLK = (tb_CLK_ena)? ~EXTCLK : 0; // Generate the psuedo 50 [MHz] clock, once the clock is "enabled"
  end
  
  // Testbench stimulus testing (simulation) and monitoring
  initial begin
    // Initial values - reset DUT and testbench variables
    tb_CLK_ena = 0; // disable clock at start
    KEY = 2'bx1; // Deassert reset (active-low) and user button is not used (don't care)
    expected_counter = 0; // expected counter starts at 0
    expected_leds = 8'b0; // expected leds starts at 0
    errors_count = 0; // no errors at start
    cycle_count = 0; // no clock cycles elapsed at start
    test_case = 0; // start with test case 0
  
    $display("=== Starting Elaborate Testbench for 'clk_counter_leds_top' ===");
    $display("Time: %0t [ns]", $time);
    $display("Clock Frequency: %0d [Hz]", EXT_CLOCK_FREQ);
    $display("Clock Period: %0.3f [ns]", EXT_CLOCK_PERIOD);
  
    // Enable external clock
    tb_CLK_ena = 1;
   
    // Test Case 1: Initial Reset Test
    test_case = 1;
    $display("\n--- Test Case %0d: Initial Reset Test ---", test_case);
    reset_dut();
    check_dut_reset_state();
  
    // Test Case 2: Basic Counter Operation
    test_case = 2;
    $display("\n--- Test Case %0d: Basic Counter Operation ---", test_case);
    test_dut_basic_counting(32'h0400_0000); // Test counting up to 0x04000000, so some of the LEDs will light up.
    
    // Test Case 3: Reset During Operation
    test_case = 3; 
    $display("\n--- Test Case %0d: Reset During Operation ---", test_case);
    test_reset_dut_during_operation();
    
    // Test Case 4: Multiple Reset Cycles 
    test_case = 4; 
    $display("\n--- Test Case %0d: Multiple Reset Cycles ---", test_case);
    test_dut_multiple_resets();
    
    // Test Case 5: Counter Overflow Test 
    test_case = 5; 
    $display("\n--- Test Case %0d: Counter Overflow Test ---", test_case);
    test_dut_counter_overflow();
    
    // Test Case 6: LED Pattern Verification 
    test_case = 6;
    $display("\n--- Test Case %0d: LED Pattern Verification ---", test_case);
    test_dut_led_patterns();
    
    // Test Case 7: Timing Verification 
    test_case = 7;
    $display("\n--- Test Case %0d: Timing Verification ---", test_case);
    test_dut_timing_requirements();
    
    // Test Case 8: Edge Case Testing 
    test_case = 8;
    $display("\n--- Test Case %0d: Edge Case Testing ---", test_case);
    test_dut_edge_cases();
    
    // Test Case 9: Stress Test
    test_case = 9; 
    $display("\n--- Test Case %0d: Stress Test ---", test_case);
    stress_test_dut();
    
    // Print out the Final Results
    display_final_test_results();
    
    $finish;
  end 
  
  // Continous (backround) montirong for unexpected behaviour 
  always @(posedge EXTCLK) begin 
    if(KEY[0] === 1'b1) begin // Only when not in reset 
      cycle_count++;
      
      // Monitor for 'X' (unknonw) or 'Z' (high-impedance) states 
      if(^LEDG === 1'bx) begin // ^LEDG performs a reduction XOR operation on all bits of LEDG - It XORs all bits together: LEDG[n] ^ LEDG[n-1] ^ ... ^ LEDG[1] ^ LEDG[0]
        $error("Time %0t: LEDs contain X or Z values: %b", $time, LEDG);
        errors_count++;
      end 
    end 
  end 
  
  // VCD waveform dumping for debugging
  initial begin 
    $dumpfile("clk_counter_leds_top_tb_2.vcd"); // VCD file for GTKWave waveform viewer 
    $dumpvars(0, clk_counter_leds_top_tb_2); // dump all signals of this TB and below 
  end
  
  // Task: Reset DUT
  task automatic reset_dut();
    begin
      // Apply reset
      $display("Applying reset...");
      KEY[0] = 0; // Assert reset (active-low)
      repeat(RESET_CYCLES) @(posedge EXTCLK); // wait for RESET_CYCLES clock cycles
    
      // Release reset
      KEY[0] = 1; // Deassert reset
      expected_counter = 0; // expected counter resets to 0
      @(posedge EXTCLK); // wait for one clock cycle
      $display("Reset released at time %0t [ns]", $time);
    end
  endtask
  
  // Task: Check DUT state after reset
  task automatic check_dut_reset_state();
    begin 
      if(LEDG !== 8'h00) begin 
        $error("Reset state check failed! Expected LEDs: 8'h00, Got: 8'h%02h", LEDG);
      end else begin
        $display("✓ Reset state check passed - LEDs correctly show 8'h00");
      end
    end
  endtask
  
  // Task: Test basic counting operation
  task automatic test_dut_basic_counting(input integer cycles);
    integer i;
    begin 
      for(i = 0; i < cycles; i++) begin
        @(posedge EXTCLK); //
        expected_counter++;
        expected_leds = expected_counter[31:24]; // LEDs reflect the lower 8 bits of the counter
        
        // Check LEDs output
        if(LEDG !== expected_leds) begin
          $error("Cycle %0d: LEDG mismatch! Expected: 8'h%02h, Got: 8'h%02h", i, expected_leds, LEDG);
          errors_count++;
        end
      
        // Periodic status update - each decimal part of the 
        if((i % (cycles / 16)) == 0) begin 
          $display("  Cycle %0d: Counter=32'h%08h, LEDs=8'h%02h", i, expected_counter, LEDG);
        end
      end
      
      $display("✓ Basic counting test completed");
    end
  endtask
  
  // Task: Test reset during operation
  task automatic test_reset_dut_during_operation();
    begin 
      $display("Testing reset during counter operation...");
    
      // Let counter run (continue from the previous test case) for some cycles 
      repeat(50) @(posedge EXTCLK);
      expected_counter += 50; 
      
      $display("Counter value before reset: %0d", expected_counter);
      
      // Apply reset in the middle of operation 
      KEY[0] = 1'b0; 
      @(posedge EXTCLK);
      
      // Check that LEDs immediately show reset state 
      if (LEDG !== 8'h00) begin 
        $error("Reset during operation failed! LEDs should be 8'h00, got 8'h%02h", LEDG);  
        errors_count++;
      end else begin 
        $display("✓ Asynchronous reset working correctly");
      end
      
      // Release reset and verify counting resumes from 0
      KEY[0] = 1'b1; 
      expected_counter = 0;
      
      repeat(10) begin 
        @(posedge EXTCLK);
        expected_counter++;
        expected_leds = expected_counter[31:24];
        
        if(LEDG !== expected_leds) begin 
          $error("Post-reset counting error! Expected: 8'h%02h, Got: 8'h%02h", expected_leds, LEDG);
          errors_count++;
        end  
      end
      
      $display("✓ Reset during operation test completed");
    end
  endtask 
  
  // Task: Test multiple reset cycles 
  task automatic test_dut_multiple_resets();
    integer i;
    begin 
      $display("Testing multiple reset cycles...");
      
     for(i = 0; i < 5 ; i++) begin 
      // Run counter for random number of cycles 
      repeat($urandom_range(10, 50)) @(posedge EXTCLK);
      
      // Apply reset 
      reset_dut();
      check_dut_reset_state();
      
      // Verify counting starts from 0
      repeat(5) begin 
        @(posedge EXTCLK);
        expected_counter++;
      end
      if (expected_counter != DUT.clk_counter) begin 
        $error("Expected DUT clock counter mismatch! Expected: 32'h%08h, Got: 32'h%08h", expected_counter, DUT.clk_counter);
        errors_count++;
      end 
      
      $display("  Reset cycle %0d completed", i+1);
    end
      
     $display("✓ Multiple reset cycles test completed");
    end 
  endtask 

  // Task: Test counter overflow
  task automatic test_dut_counter_overflow();
    begin 
      $display("Testing counter overflow behaviour...");
      
      // Reset the counter and ...
      reset_dut();
      // ... then set it close to overflow. 
      // Fast-forward to near overflow (this is simulation, so we can do this)
      // In real hardware, this would take a very long time
      force DUT.clk_counter = 32'hFFFFFF00;
      expected_counter = 32'hFFFFFF00;
      @(posedge EXTCLK);
      release DUT.clk_counter;
      
      // Test the last few counts before overflow 
      repeat(300) begin 
        @(posedge EXTCLK); 
        expected_counter++;
        expected_leds = expected_counter[31:24];
      
        if(LEDG !== expected_leds) begin 
          $error("Overflow test: LED mismatch at counter=32'h%08h! Expected: 8'h%08h, Got: 8'h%02h", expected_counter, expected_leds, LEDG);
        end
      
        // Show overflow transition 
        if(expected_counter == 32'hFFFFFFFF || expected_counter == 32'h00000000) begin 
          $display("  Counter oveflow: 32'h%08h -> LEDs: 8'h%02h", expected_counter, LEDG);
        end
      end 
      
      $display("✓ Counter overflow test completed");
    end
  endtask
  
  // Task: Test LED patterns 
  task test_dut_led_patterns();
    integer         i;
    logic    [7:0]  pattern;
    // Test specific patterns by forcing counter values 
    static logic [31:0] test_values [8] = '{
      32'h0000_0000, // All LEDs off
      32'hFF00_0000, // All LEDs on 
      32'hAA00_0000, // Alternating pattern 
      32'h5500_0000, // Opposite alternating 
      32'h0F00_0000, // Lower nibble 
      32'hF000_0000, // Upper nibble
      32'h0100_0000, // Single LED 
      32'h8000_0000  // MSB LED         
    };
	
    begin 
      $display("Testing specific LED patterns...");
      
      for(i = 0; i < 8; i++) begin 
        reset_dut();
        force DUT.clk_counter = test_values[i];
        expected_counter = test_values[i];
        expected_leds = expected_counter[31:24];
        
        @(posedge EXTCLK);
        
        if(LEDG !== expected_leds) begin 
          $error("LED pattern test %0d failed! Expected: 8'h%02h, Got: 8'h%02h", i, expected_leds, LEDG);
          errors_count++;
        end else begin 
          $display("  ✓ Pattern %0d: Counter=32'h%08h -> LEDs=8'h%02h", i, test_values[i], LEDG);
        end        
        
        release DUT.clk_counter;
      end 
      
      $display("✓ LED pattern test completed");
    end
  endtask
  
  // Task: Test timing requirements 
  task automatic test_dut_timing_requirements();
    time reset_to_count_time; 
    time count_change_time;
    
    begin 
      $display("Testing timing requirements...");

      // Test reset to first count timing 
      reset_dut();
      reset_to_count_time = $time; 
      
      @(posedge EXTCLK); 
      expected_counter++;
      expected_leds = expected_counter[31:24];
      count_change_time = $time - reset_to_count_time;  
      
      $display("  Reset to first count delay: %0t", count_change_time);
  
      // Test setup and hold times (basic check) - visually inspect simulation waveform
      repeat(10) begin 
        @(negedge EXTCLK); 
        // Check that LEDs don't change on negative edge 
        #1; // Small delayt
        if(LEDG !== expected_leds) begin 
          $error("LEDs time (clock edge) requirements failed! Expected: 8'h%02h, Got: 8'h%02h", expected_leds, LEDG);
          errors_count++;
        end
        @(posedge EXTCLK);
        // LEDs should change only on positive edge
        expected_counter++;
        expected_leds = expected_counter[31:24];
      end 
      
      $display("✓ Timing requirements test completed");
    end
  endtask
  
  // Task: Test edge cases
  task automatic test_dut_edge_cases();
    begin 
      $display("Testing edge cases...");

      // Test very short reset pulses
      repeat(10) @(posedge EXTCLK);
      KEY[0] = 1'b0;
      #1; // Very short reset pulse 
      KEY[0] = 1'b1;
      
      // LEDs should still be reset 
      @(posedge EXTCLK); 
      if(LEDG !== 8'h00) begin 
        $error("Short reset pulse failed!");
        errors_count++;
      end else begin 
        $display("  ✓ Short reset pulse works correctly");
      end
      
      // Test KEY[1] (should not affect counter)
      expected_counter = 0; 
      repeat(10) begin 
        @(posedge EXTCLK);
        expected_counter++;
      end 
      
      KEY[1] = 1'b0; // Press the User button 
      repeat(10) begin 
        @(posedge EXTCLK);
        expected_counter++;
        expected_leds = expected_counter[31:24];
        
        if (LEDG != expected_leds) begin 
          $error("KEY[1] affected counter operation!");
          errors_count++;
        end 
      end
      KEY[1] = 1'b1; // Release user button 
  
      $display("  ✓ KEY[1] correctly ignored");
      $display("✓ Edge cases test completed");
    end
  endtask
  
  // Task: Stress Test
  task automatic stress_test_dut();
    integer i; 
    begin 
      $display("Running stress test...");
    
      // Random reset patterns 
      for (i = 0; i < 20; i++) begin 
        repeat($urandom_range(5, 25)) @(posedge EXTCLK);
        
        // Random reset duration 
        KEY[0] = 1'b0;
        repeat($urandom_range(1, 5)) @(posedge EXTCLK);
        KEY[0] = 1'b1; 
        expected_counter = 0;
        
        // Verify reset worked 
        @(posedge EXTCLK); 
        if(LEDG != 8'h00) begin 
          $error("Stress test reset %0d failed!", i);
        end 
      end 
      
      $display("✓ Stress test completed");
    end 
  endtask 
  
  task automatic display_final_test_results();
    begin
      $display("\n" + "="*60);
      $display("TESTBENCH SUMMARY");
      $display("="*60);
      $display("Total Test Cases: %0d", test_case);
      $display("Total Errors: %0d", errors_count);

      if(errors_count == 0) begin 
        $display("🎉 ALL TESTS PASSED! 🎉");
        $display("The 'clk_counter_leds_top' design is functioning correctly.");
      end else begin       
        $display("❌ %0d ERRORS DETECTED", errors_count);
        $display("Please review the design for issues.");
      end 
    
      $display("="*60);
      $display("Simulation completed at time: %0t", $time);
	end
  endtask

endmodule 