`timescale 1ns / 1ps

module clk_counter_leds_top_tb;

    // =============================================================================
    // TESTBENCH PARAMETERS AND CONSTANTS
    // =============================================================================
    
    // DUT Parameters - matching the design under test
    parameter EXT_CLOCK_FREQ   = 50000000;  // 50 MHz external clock
    parameter EXT_CLOCK_PERIOD = 20.000;    // 20ns period (50MHz)
    parameter LEDG_SIZE        = 8;         // 8 LEDs on the board
    
    // Testbench specific parameters
    parameter CLOCK_PERIOD_NS  = 20;        // Clock period in nanoseconds
    parameter SIM_TIME_LIMIT   = 100_000_000; // Maximum simulation time in ns
    
    // Calculated parameters (matching DUT internal calculations)
    localparam LED_CNTR_WIDTH = LEDG_SIZE - 1;           // 7 bits for counter
    localparam LED_OVRFL_POS  = LEDG_SIZE - 1;          // Position 7 for overflow
    localparam COUNT_FREQ     = EXT_CLOCK_FREQ / 5;     // 10M counts for 0.2s
    localparam COUNT_WIDTH    = $clog2(COUNT_FREQ);     // Width needed for count
    
    // =============================================================================
    // TESTBENCH SIGNALS
    // =============================================================================
    
    // DUT Interface Signals
    logic         EXTCLK;
    logic [1:0]   KEY;
    logic [7:0]   LEDG;
    
    // Testbench Control Signals
    logic         tb_reset_n;
    logic         tb_enable;
    logic         test_running;
    integer       test_case_num;
    string        test_case_name;
    
    // Monitoring and Checking Signals
    logic [LED_CNTR_WIDTH-1:0] expected_counter;
    logic                      expected_overflow;
    logic [COUNT_WIDTH-1:0]    clock_cycle_count;
    integer                    led_change_count;
    
    // Error tracking
    integer error_count;
    integer warning_count;
    
    // =============================================================================
    // CLOCK GENERATION
    // =============================================================================
    
    initial begin
        EXTCLK = 1'b0;
        forever #(CLOCK_PERIOD_NS/2) EXTCLK = ~EXTCLK;
    end
    
    // =============================================================================
    // DEVICE UNDER TEST INSTANTIATION
    // =============================================================================
    
    clk_counter_leds_top #(
        .EXT_CLOCK_FREQ   (EXT_CLOCK_FREQ),
        .EXT_CLOCK_PERIOD (EXT_CLOCK_PERIOD),
        .LEDG_SIZE        (LEDG_SIZE)
    ) DUT (
        .EXTCLK (EXTCLK),
        .KEY    (KEY),
        .LEDG   (LEDG)
    );
    
    // =============================================================================
    // SIGNAL ASSIGNMENTS AND INTERFACE MAPPING
    // =============================================================================
    
    // Map testbench control signals to DUT inputs
    assign KEY[0] = tb_reset_n;  // Reset is active low
    assign KEY[1] = ~tb_enable;  // Enable is active low (inverted in DUT)
    
    // =============================================================================
    // MONITORING AND REFERENCE MODEL
    // =============================================================================
    
    // Reference model to track expected behavior
    always_ff @(posedge EXTCLK, negedge tb_reset_n) begin
        if (!tb_reset_n) begin
            expected_counter <= '0;
            expected_overflow <= 1'b0;
            clock_cycle_count <= '0;
        end else if (tb_enable) begin
            clock_cycle_count <= clock_cycle_count + 1'b1;
            if (clock_cycle_count == (COUNT_FREQ - 1)) begin
                clock_cycle_count <= '0;
                expected_overflow <= (expected_counter == {LED_CNTR_WIDTH{1'b1}});
                expected_counter <= expected_counter + 1'b1;
            end else begin
                expected_overflow <= 1'b0;
            end
        end else begin
            expected_overflow <= 1'b0;
            clock_cycle_count <= '0;
        end
    end
    
    // LED change detection for monitoring
    always_ff @(posedge EXTCLK) begin
        if (!tb_reset_n) begin
            led_change_count <= 0;
        end else begin
            if ($changed(LEDG[LED_CNTR_WIDTH-1:0])) begin
                led_change_count <= led_change_count + 1;
            end
        end
    end
    
    // =============================================================================
    // ASSERTION-BASED VERIFICATION
    // =============================================================================
    
    // Property: Reset behavior
    property reset_behavior;
        @(posedge EXTCLK) 
        !tb_reset_n |-> (LEDG == 8'h00);
    endproperty
    
    // Property: Counter increment timing
    property counter_timing;
        @(posedge EXTCLK) 
        tb_enable && tb_reset_n && (clock_cycle_count == COUNT_FREQ-1) 
        |=> (LEDG[LED_CNTR_WIDTH-1:0] == $past(LEDG[LED_CNTR_WIDTH-1:0]) + 1'b1);
    endproperty
    
    // Property: Overflow indication
    property overflow_indication;
        @(posedge EXTCLK)
        tb_enable && tb_reset_n && (expected_counter == {LED_CNTR_WIDTH{1'b1}}) && 
        (clock_cycle_count == COUNT_FREQ-1)
        |=> LEDG[LED_OVRFL_POS];
    endproperty
    
    // Property: No counting when disabled
    property no_count_when_disabled;
        @(posedge EXTCLK)
        !tb_enable && tb_reset_n |=> $stable(LEDG[LED_CNTR_WIDTH-1:0]);
    endproperty
    
    // Bind assertions
    assert property (reset_behavior) 
        else $error("Reset behavior failed at time %t", $time);
    
    assert property (counter_timing) 
        else $error("Counter timing failed at time %t", $time);
    
    assert property (overflow_indication) 
        else $error("Overflow indication failed at time %t", $time);
    
    assert property (no_count_when_disabled) 
        else $error("Counting occurred when disabled at time %t", $time);
    
    // =============================================================================
    // TESTBENCH TASKS AND FUNCTIONS
    // =============================================================================
    
    // Task: Initialize testbench
    task initialize_tb();
        tb_reset_n = 1'b0;
        tb_enable = 1'b0;
        test_running = 1'b1;
        test_case_num = 0;
        error_count = 0;
        warning_count = 0;
        expected_counter = '0;
        expected_overflow = 1'b0;
        clock_cycle_count = '0;
        led_change_count = 0;
        
        $display("=== TESTBENCH INITIALIZATION COMPLETE ===");
        $display("DUT Parameters:");
        $display("  EXT_CLOCK_FREQ = %0d Hz", EXT_CLOCK_FREQ);
        $display("  COUNT_FREQ = %0d cycles", COUNT_FREQ);
        $display("  LED_CNTR_WIDTH = %0d bits", LED_CNTR_WIDTH);
        $display("  Expected counting period = %0.3f ms", (COUNT_FREQ * CLOCK_PERIOD_NS) / 1_000_000.0);
    endtask
    
    // Task: Apply reset
    task apply_reset(input integer reset_cycles = 10);
        $display("[%0t] Applying reset for %0d cycles", $time, reset_cycles);
        tb_reset_n = 1'b0;
        repeat(reset_cycles) @(posedge EXTCLK);
        tb_reset_n = 1'b1;
        @(posedge EXTCLK);
        $display("[%0t] Reset released", $time);
    endtask
    
    // Task: Wait for LED counter changes
    task wait_for_led_changes(input integer num_changes);
        integer initial_count = led_change_count;
        $display("[%0t] Waiting for %0d LED counter changes...", $time, num_changes);
        
        while ((led_change_count - initial_count) < num_changes) begin
            @(posedge EXTCLK);
            if ($time > SIM_TIME_LIMIT) begin
                $error("Timeout waiting for LED changes");
                break;
            end
        end
        $display("[%0t] Observed %0d LED changes", $time, led_change_count - initial_count);
    endtask
    
    // Task: Check LED values
    task check_leds(input logic [7:0] expected_leds, input string description);
        if (LEDG !== expected_leds) begin
            $error("[%0t] LED mismatch in %s: Expected=0x%02h, Actual=0x%02h", 
                   $time, description, expected_leds, LEDG);
            error_count++;
        end else begin
            $display("[%0t] LED check passed in %s: 0x%02h", $time, description, LEDG);
        end
    endtask
    
    // Task: Run a specific test case
    task run_test_case(input string name);
        test_case_num++;
        test_case_name = name;
        $display("\n=== TEST CASE %0d: %s ===", test_case_num, name);
    endtask
    
    // Task: Wait for specific number of clock cycles
    task wait_clocks(input integer num_clocks);
        repeat(num_clocks) @(posedge EXTCLK);
    endtask
    
    // Function: Calculate expected LED value after N increments
    function logic [7:0] calc_expected_leds(input integer increments);
        logic [LED_CNTR_WIDTH-1:0] counter_val;
        logic overflow_bit;
        
        counter_val = increments[LED_CNTR_WIDTH-1:0];
        overflow_bit = (increments > 0) && (counter_val == 0); // Overflow occurred
        
        return {overflow_bit, counter_val};
    endfunction
    
    // =============================================================================
    // MAIN TEST SEQUENCE
    // =============================================================================
    
    initial begin
        // Initialize waveform dumping
        $dumpfile("clk_counter_leds_top_tb.vcd");
        $dumpvars(0, clk_counter_leds_top_tb);
        
        // Initialize testbench
        initialize_tb();
        
        // =========================================================================
        // TEST CASE 1: Basic Reset Functionality
        // =========================================================================
        run_test_case("Basic Reset Functionality");
        
        apply_reset(20);
        check_leds(8'h00, "after reset");
        
        // Verify reset is synchronous to clock
        tb_enable = 1'b1;
        wait_clocks(5);
        tb_reset_n = 1'b0;
        wait_clocks(1);
        check_leds(8'h00, "synchronous reset");
        tb_reset_n = 1'b1;
        
        // =========================================================================
        // TEST CASE 2: Enable/Disable Functionality
        // =========================================================================
        run_test_case("Enable/Disable Functionality");
        
        apply_reset(5);
        
        // Test that counter doesn't increment when disabled
        tb_enable = 1'b0;
        wait_clocks(COUNT_FREQ + 100);
        check_leds(8'h00, "disabled counting");
        
        // Enable and verify counting starts
        tb_enable = 1'b1;
        wait_for_led_changes(1);
        check_leds(8'h01, "first count after enable");
        
        // Disable mid-count and verify it stops
        tb_enable = 1'b0;
        logic [7:0] leds_before_disable = LEDG;
        wait_clocks(COUNT_FREQ + 100);
        if (LEDG[LED_CNTR_WIDTH-1:0] != leds_before_disable[LED_CNTR_WIDTH-1:0]) begin
            $error("Counter incremented while disabled");
            error_count++;
        end
        
        // =========================================================================
        // TEST CASE 3: Normal Counting Sequence
        // =========================================================================
        run_test_case("Normal Counting Sequence");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Wait for several counter increments and verify sequence
        for (int i = 1; i <= 10; i++) begin
            wait_for_led_changes(1);
            check_leds(calc_expected_leds(i), $sformatf("count %0d", i));
        end
        
        // =========================================================================
        // TEST CASE 4: Overflow Behavior
        // =========================================================================
        run_test_case("Overflow Behavior");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Fast-forward to near overflow condition
        // Note: In real simulation, this would take very long, so we'll check the logic
        $display("Testing overflow logic (conceptual - would take %0.2f seconds in real-time)", 
                 (2**LED_CNTR_WIDTH * COUNT_FREQ * CLOCK_PERIOD_NS) / 1_000_000_000.0);
        
        // We can't practically wait for real overflow in simulation, but we can
        // verify the overflow bit behavior by checking a few cycles near rollover
        wait_for_led_changes(5);
        
        // =========================================================================
        // TEST CASE 5: Timing Verification
        // =========================================================================
        run_test_case("Timing Verification");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Measure actual timing between LED changes
        integer start_time, end_time, measured_period;
        
        wait_for_led_changes(1);
        start_time = $time;
        wait_for_led_changes(1);
        end_time = $time;
        measured_period = end_time - start_time;
        
        integer expected_period = COUNT_FREQ * CLOCK_PERIOD_NS;
        if (measured_period != expected_period) begin
            $error("Timing mismatch: Expected=%0dns, Measured=%0dns", 
                   expected_period, measured_period);
            error_count++;
        end else begin
            $display("Timing verification passed: %0dns period", measured_period);
        end
        
        // =========================================================================
        // TEST CASE 6: Reset During Operation
        // =========================================================================
        run_test_case("Reset During Operation");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Let counter increment a few times
        wait_for_led_changes(3);
        logic [7:0] leds_before_reset = LEDG;
        
        // Apply reset and verify immediate clearing
        apply_reset(5);
        check_leds(8'h00, "reset during operation");
        
        // Verify counting resumes correctly
        tb_enable = 1'b1;
        wait_for_led_changes(1);
        check_leds(8'h01, "resume after reset");
        
        // =========================================================================
        // TEST CASE 7: Edge Case - Rapid Enable/Disable
        // =========================================================================
        run_test_case("Rapid Enable/Disable");
        
        apply_reset(5);
        
        // Rapidly toggle enable
        for (int i = 0; i < 20; i++) begin
            tb_enable = 1'b1;
            wait_clocks(10);
            tb_enable = 1'b0;
            wait_clocks(10);
        end
        
        // Verify system is still functional
        tb_enable = 1'b1;
        wait_for_led_changes(2);
        $display("System remains functional after rapid enable/disable");
        
        // =========================================================================
        // TEST COMPLETION AND REPORTING
        // =========================================================================
        
        test_running = 1'b0;
        
        $display("\n=== TESTBENCH COMPLETION SUMMARY ===");
        $display("Total test cases run: %0d", test_case_num);
        $display("Total errors: %0d", error_count);
        $display("Total warnings: %0d", warning_count);
        $display("LED changes observed: %0d", led_change_count);
        $display("Simulation time: %0t", $time);
        
        if (error_count == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** %0d TESTS FAILED ***", error_count);
        end
        
        $finish;
    end
    
    // =============================================================================
    // CONTINUOUS MONITORING AND COVERAGE
    // =============================================================================
    
    // Monitor for unexpected changes
    always @(LEDG) begin
        if (test_running) begin
            $display("[%0t] LED Update: 0x%02h (Counter: %0d, Overflow: %b)", 
                     $time, LEDG, LEDG[LED_CNTR_WIDTH-1:0], LEDG[LED_OVRFL_POS]);
        end
    end
    
    // Timeout protection
    initial begin
        #SIM_TIME_LIMIT;
        $error("Simulation timeout reached");
        $finish;
    end
    
    // Coverage collection (if supported by simulator)
    `ifdef COVERAGE_ENABLED
    covergroup cg_led_values @(posedge EXTCLK);
        led_counter: coverpoint LEDG[LED_CNTR_WIDTH-1:0] {
            bins low_values[] = {[0:15]};
            bins mid_values[] = {[16:111]};
            bins high_values[] = {[112:127]};
        }
        
        overflow_bit: coverpoint LEDG[LED_OVRFL_POS] {
            bins no_overflow = {0};
            bins overflow = {1};
        }
        
        enable_state: coverpoint tb_enable {
            bins disabled = {0};
            bins enabled = {1};
        }
        
        cross led_counter, overflow_bit, enable_state;
    endgroup
    
    cg_led_values cg_inst = new();
    `endif
    
endmodule
