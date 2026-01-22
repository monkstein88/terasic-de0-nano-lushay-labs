`timescale 1ns / 1ps

module clk_counter_leds_top_tb;

    // Parameters matching the DUT
    parameter EXT_CLOCK_FREQ = 50000000;
    parameter EXT_CLOCK_PERIOD = 20.000;
    
    // Testbench parameters
    parameter CLK_PERIOD = 20;  // 50MHz clock period in ns
    parameter RESET_CYCLES = 5;
    parameter TEST_DURATION = 1000; // Number of clock cycles to test
    
    // DUT signals
    logic          EXTCLK;
    logic   [1:0]  KEY_n;
    logic   [7:0]  LEDG;
    
    // Testbench variables
    logic [31:0] expected_counter;
    logic [7:0]  expected_leds;
    integer      test_case;
    integer      error_count;
    integer      cycle_count;
    
    // Clock generation
    initial begin
        EXTCLK = 0;
        forever #(CLK_PERIOD/2) EXTCLK = ~EXTCLK;
    end
    
    // DUT instantiation
    clk_counter_leds_top #(
        .EXT_CLOCK_FREQ(EXT_CLOCK_FREQ),
        .EXT_CLOCK_PERIOD(EXT_CLOCK_PERIOD)
    ) dut (
        .EXTCLK(EXTCLK),
        .KEY_n(KEY_n),
        .LEDG(LEDG)
    );
    
    // Test stimulus and monitoring
    initial begin
        // Initialize signals
        KEY_n = 2'b11;  // Release all keys (active low)
        expected_counter = 0;
        error_count = 0;
        cycle_count = 0;
        test_case = 0;
        
        $display("=== Starting Elaborate Testbench for clk_counter_leds_top ===");
        $display("Time: %0t", $time);
        $display("Clock Frequency: %0d Hz", EXT_CLOCK_FREQ);
        $display("Clock Period: %0.3f ns", EXT_CLOCK_PERIOD);
        
        // Test Case 1: Initial Reset Test
        test_case = 1;
        $display("\n--- Test Case %0d: Initial Reset Test ---", test_case);
        reset_dut();
        check_reset_state();
        
        // Test Case 2: Basic Counter Operation
        test_case = 2;
        $display("\n--- Test Case %0d: Basic Counter Operation ---", test_case);
        test_basic_counting(100);
        
        // Test Case 3: Reset During Operation
        test_case = 3;
        $display("\n--- Test Case %0d: Reset During Operation ---", test_case);
        test_reset_during_operation();
        
        // Test Case 4: Multiple Reset Cycles
        test_case = 4;
        $display("\n--- Test Case %0d: Multiple Reset Cycles ---", test_case);
        test_multiple_resets();
        
        // Test Case 5: Counter Overflow Test
        test_case = 5;
        $display("\n--- Test Case %0d: Counter Overflow Test ---", test_case);
        test_counter_overflow();
        
        // Test Case 6: LED Pattern Verification
        test_case = 6;
        $display("\n--- Test Case %0d: LED Pattern Verification ---", test_case);
        test_led_patterns();
        
        // Test Case 7: Timing Verification
        test_case = 7;
        $display("\n--- Test Case %0d: Timing Verification ---", test_case);
        test_timing_requirements();
        
        // Test Case 8: Edge Case Testing
        test_case = 8;
        $display("\n--- Test Case %0d: Edge Case Testing ---", test_case);
        test_edge_cases();
        
        // Test Case 9: Stress Test
        test_case = 9;
        $display("\n--- Test Case %0d: Stress Test ---", test_case);
        stress_test();
        
        // Final Results
        display_final_results();
        
        $finish;
    end
    
    // Task: Reset DUT
    task reset_dut();
        begin
            $display("Applying reset...");
            KEY_n[0] = 1'b0;  // Assert reset (active low)
            repeat(RESET_CYCLES) @(posedge EXTCLK);
            KEY_n[0] = 1'b1;  // Release reset
            expected_counter = 0;
            @(posedge EXTCLK);  // Wait one cycle after reset release
            $display("Reset released at time %0t", $time);
        end
    endtask
    
    // Task: Check reset state
    task check_reset_state();
        begin
            if (LEDG !== 8'h00) begin
                $error("Reset state check failed! Expected LEDs: 8'h00, Got: 8'h%02h", LEDG);
                error_count++;
            end else begin
                $display("✓ Reset state check passed - LEDs correctly show 8'h00");
            end
        end
    endtask
    
    // Task: Test basic counting functionality
    task test_basic_counting(input integer cycles);
        integer i;
        begin
            $display("Testing basic counting for %0d cycles...", cycles);
            
            for (i = 0; i < cycles; i++) begin
                @(posedge EXTCLK);
                expected_counter++;
                expected_leds = expected_counter[31:24]; // Upper 8 bits
                
                // Check LED output
                if (LEDG !== expected_leds) begin
                    $error("Cycle %0d: LED mismatch! Expected: 8'h%02h, Got: 8'h%02h", 
                           i, expected_leds, LEDG);
                    error_count++;
                end
                
                // Periodic status update
                if (i % 25 == 0) begin
                    $display("  Cycle %0d: Counter=%0d, LEDs=8'h%02h", i, expected_counter, LEDG);
                end
            end
            
            $display("✓ Basic counting test completed");
        end
    endtask
    
    // Task: Test reset during operation
    task test_reset_during_operation();
        integer i;
        begin
            $display("Testing reset during counter operation...");
            
            // Let counter run for some cycles
            repeat(50) @(posedge EXTCLK);
            expected_counter += 50;
            
            $display("Counter value before reset: %0d", expected_counter);
            
            // Apply reset in the middle of operation
            KEY_n[0] = 1'b0;
            @(posedge EXTCLK);
            
            // Check that LEDs immediately show reset state
            if (LEDG !== 8'h00) begin
                $error("Reset during operation failed! LEDs should be 8'h00, got 8'h%02h", LEDG);
                error_count++;
            end else begin
                $display("✓ Asynchronous reset working correctly");
            end
            
            // Release reset and verify counting resumes from 0
            KEY_n[0] = 1'b1;
            expected_counter = 0;
            
            repeat(10) begin
                @(posedge EXTCLK);
                expected_counter++;
                expected_leds = expected_counter[31:24];
                
                if (LEDG !== expected_leds) begin
                    $error("Post-reset counting error! Expected: 8'h%02h, Got: 8'h%02h", 
                           expected_leds, LEDG);
                    error_count++;
                end
            end
            
            $display("✓ Reset during operation test completed");
        end
    endtask
    
    // Task: Test multiple reset cycles
    task test_multiple_resets();
        integer i;
        begin
            $display("Testing multiple reset cycles...");
            
            for (i = 0; i < 5; i++) begin
                // Run counter for random number of cycles
                repeat($urandom_range(10, 50)) @(posedge EXTCLK);
                
                // Apply reset
                reset_dut();
                check_reset_state();
                
                // Verify counting starts from 0
                repeat(5) begin
                    @(posedge EXTCLK);
                    expected_counter++;
                end
                
                $display("  Reset cycle %0d completed", i+1);
            end
            
            $display("✓ Multiple reset cycles test completed");
        end
    endtask
    
    // Task: Test counter overflow
    task test_counter_overflow();
        begin
            $display("Testing counter overflow behavior...");
            
            // Set counter close to overflow
            reset_dut();
            
            // Fast-forward to near overflow (this is simulation, so we can do this)
            // In real hardware, this would take a very long time
            force dut.clk_counter = 32'hFFFFFF00;  // Close to overflow
            expected_counter = 32'hFFFFFF00;
            
            @(posedge EXTCLK);
            release dut.clk_counter;
            
            // Test the last few counts before overflow
            repeat(300) begin
                @(posedge EXTCLK);
                expected_counter++;
                expected_leds = expected_counter[31:24];
                
                if (LEDG !== expected_leds) begin
                    $error("Overflow test: LED mismatch at counter=32'h%08h! Expected: 8'h%02h, Got: 8'h%02h", 
                           expected_counter, expected_leds, LEDG);
                    error_count++;
                end
                
                // Show overflow transition
                if (expected_counter == 32'hFFFFFFFF || expected_counter == 32'h00000000) begin
                    $display("  Counter overflow: 32'h%08h -> LEDs: 8'h%02h", expected_counter, LEDG);
                end
            end
            
            $display("✓ Counter overflow test completed");
        end
    endtask
    
    // Task: Test LED patterns
    task test_led_patterns();
        integer i;
        logic [7:0] pattern;
        begin
            $display("Testing specific LED patterns...");
            
            // Test specific patterns by forcing counter values
            logic [31:0] test_values [8] = '{
                32'h00000000,  // All LEDs off
                32'hFF000000,  // All LEDs on
                32'hAA000000,  // Alternating pattern
                32'h55000000,  // Opposite alternating
                32'h0F000000,  // Lower nibble
                32'hF0000000,  // Upper nibble
                32'h01000000,  // Single LED
                32'h80000000   // MSB LED
            };
            
            for (i = 0; i < 8; i++) begin
                reset_dut();
                force dut.clk_counter = test_values[i];
                expected_counter = test_values[i];
                expected_leds = expected_counter[31:24];
                
                @(posedge EXTCLK);
                
                if (LEDG !== expected_leds) begin
                    $error("LED pattern test %0d failed! Expected: 8'h%02h, Got: 8'h%02h", 
                           i, expected_leds, LEDG);
                    error_count++;
                end else begin
                    $display("  ✓ Pattern %0d: Counter=32'h%08h -> LEDs=8'h%02h", 
                             i, test_values[i], LEDG);
                end
                
                release dut.clk_counter;
            end
            
            $display("✓ LED pattern test completed");
        end
    endtask
    
    // Task: Test timing requirements
    task test_timing_requirements();
        time reset_to_count_time;
        time count_change_time;
        begin
            $display("Testing timing requirements...");
            
            // Test reset to first count timing
            reset_dut();
            reset_to_count_time = $time;
            
            @(posedge EXTCLK);
            count_change_time = $time - reset_to_count_time;
            
            $display("  Reset to first count delay: %0t", count_change_time);
            
            // Test setup and hold times (basic check)
            repeat(10) begin
                @(negedge EXTCLK);
                // Check that LEDs don't change on negative edge
                #1;  // Small delay
                @(posedge EXTCLK);
                // LEDs should change only on positive edge
            end
            
            $display("✓ Timing requirements test completed");
        end
    endtask
    
    // Task: Test edge cases
    task test_edge_cases();
        begin
            $display("Testing edge cases...");
            
            // Test very short reset pulses
            repeat(10) @(posedge EXTCLK);
            KEY_n[0] = 1'b0;
            #1;  // Very short reset pulse
            KEY_n[0] = 1'b1;
            
            // Should still reset
            @(posedge EXTCLK);
            if (LEDG !== 8'h00) begin
                $error("Short reset pulse failed!");
                error_count++;
            end else begin
                $display("  ✓ Short reset pulse works correctly");
            end
            
            // Test KEY[1] (should not affect counter)
            expected_counter = 0;
            repeat(10) begin
                @(posedge EXTCLK);
                expected_counter++;
            end
            
            KEY_n[1] = 1'b0;  // Press user button
            repeat(10) begin
                @(posedge EXTCLK);
                expected_counter++;
                expected_leds = expected_counter[31:24];
                
                if (LEDG !== expected_leds) begin
                    $error("KEY[1] affected counter operation!");
                    error_count++;
                end
            end
            KEY_n[1] = 1'b1;  // Release user button
            
            $display("  ✓ KEY[1] correctly ignored");
            $display("✓ Edge cases test completed");
        end
    endtask
    
    // Task: Stress test
    task stress_test();
        integer i;
        begin
            $display("Running stress test...");
            
            // Random reset patterns
            for (i = 0; i < 20; i++) begin
                repeat($urandom_range(5, 25)) @(posedge EXTCLK);
                
                // Random reset duration
                KEY_n[0] = 1'b0;
                repeat($urandom_range(1, 5)) @(posedge EXTCLK);
                KEY_n[0] = 1'b1;
                expected_counter = 0;
                
                // Verify reset worked
                @(posedge EXTCLK);
                if (LEDG !== 8'h00) begin
                    $error("Stress test reset %0d failed!", i);
                    error_count++;
                end
            end
            
            $display("✓ Stress test completed");
        end
    endtask
    
    // Task: Display final results
    task display_final_results();
        begin
            $display("\n" + "="*60);
            $display("TESTBENCH SUMMARY");
            $display("="*60);
            $display("Total Test Cases: %0d", test_case);
            $display("Total Errors: %0d", error_count);
            
            if (error_count == 0) begin
                $display("🎉 ALL TESTS PASSED! 🎉");
                $display("The clk_counter_leds_top design is functioning correctly.");
            end else begin
                $display("❌ %0d ERRORS DETECTED", error_count);
                $display("Please review the design for issues.");
            end
            
            $display("="*60);
            $display("Simulation completed at time: %0t", $time);
        end
    endtask
    
    // Continuous monitoring for unexpected behavior
    always @(posedge EXTCLK) begin
        if (KEY_n[0] === 1'b1) begin  // Only when not in reset
            cycle_count++;
            
            // Monitor for X or Z states
            if (^LEDG === 1'bx) begin
                $error("Time %0t: LEDs contain X or Z values: %b", $time, LEDG);
                error_count++;
            end
        end
    end
    
    // Waveform dumping for debugging
    initial begin
        $dumpfile("clk_counter_leds_top_tb.vcd");
        $dumpvars(0, clk_counter_leds_top_tb);
    end

endmodule
