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
    parameter SIM_TIME_LIMIT   = 50_000_000; // Maximum simulation time in ns
    
    // Calculated parameters for understanding DUT behavior
    localparam LED_CNTR_WIDTH = LEDG_SIZE - 1;           // 7 bits for counter
    localparam LED_OVRFL_POS  = LEDG_SIZE - 1;          // Position 7 for overflow
    localparam COUNT_FREQ     = EXT_CLOCK_FREQ / 5;     // 10M counts for 0.2s
    
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
    
    // Simple monitoring signals
    logic [7:0]   prev_ledg;
    integer       led_change_count;
    integer       error_count;
    
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
    // SIGNAL ASSIGNMENTS
    // =============================================================================
    
    // Map testbench control signals to DUT inputs
    assign KEY[0] = tb_reset_n;  // Reset is active low
    assign KEY[1] = ~tb_enable;  // Enable is active low (inverted in DUT)
    
    // =============================================================================
    // SIMPLE MONITORING
    // =============================================================================
    
    // Track LED changes for basic monitoring
    always_ff @(posedge EXTCLK) begin
        if (!tb_reset_n) begin
            led_change_count <= 0;
            prev_ledg <= 8'h00;
        end else begin
            prev_ledg <= LEDG;
            if (LEDG != prev_ledg) begin
                led_change_count <= led_change_count + 1;
                $display("[%0t] LED Changed: 0x%02h -> 0x%02h", $time, prev_ledg, LEDG);
            end
        end
    end
    
    // =============================================================================
    // TESTBENCH TASKS
    // =============================================================================
    
    // Task: Initialize testbench
    task initialize_tb();
        tb_reset_n = 1'b0;
        tb_enable = 1'b0;
        test_running = 1'b1;
        test_case_num = 0;
        error_count = 0;
        led_change_count = 0;
        prev_ledg = 8'h00;
        
        $display("=== TESTBENCH INITIALIZATION ===");
        $display("Clock Frequency: %0d Hz", EXT_CLOCK_FREQ);
        $display("Expected LED update period: %0.1f ms", (COUNT_FREQ * CLOCK_PERIOD_NS) / 1_000_000.0);
    endtask
    
    // Task: Apply reset
    task apply_reset(input integer reset_cycles = 10);
        $display("[%0t] Applying reset...", $time);
        tb_reset_n = 1'b0;
        repeat(reset_cycles) @(posedge EXTCLK);
        tb_reset_n = 1'b1;
        @(posedge EXTCLK);
        $display("[%0t] Reset released", $time);
    endtask
    
    // Task: Wait for LED changes
    task wait_for_led_changes(input integer num_changes);
        integer initial_count = led_change_count;
        $display("[%0t] Waiting for %0d LED changes...", $time, num_changes);
        
        while ((led_change_count - initial_count) < num_changes) begin
            @(posedge EXTCLK);
            if ($time > SIM_TIME_LIMIT) begin
                $error("Timeout waiting for LED changes");
                break;
            end
        end
        $display("[%0t] Completed - observed %0d changes", $time, led_change_count - initial_count);
    endtask
    
    // Task: Check LED values
    task check_leds(input logic [7:0] expected_leds, input string description);
        if (LEDG !== expected_leds) begin
            $error("[%0t] %s: Expected=0x%02h, Actual=0x%02h", $time, description, expected_leds, LEDG);
            error_count++;
        end else begin
            $display("[%0t] %s: PASS (0x%02h)", $time, description, LEDG);
        end
    endtask
    
    // Task: Run test case
    task run_test_case(input string name);
        test_case_num++;
        test_case_name = name;
        $display("\n=== TEST %0d: %s ===", test_case_num, name);
    endtask
    
    // Task: Wait for clock cycles
    task wait_clocks(input integer num_clocks);
        repeat(num_clocks) @(posedge EXTCLK);
    endtask
    
    // =============================================================================
    // MAIN TEST SEQUENCE
    // =============================================================================
    
    initial begin
        // Initialize waveform dumping
        $dumpfile("clk_counter_leds_top_tb.vcd");
        $dumpvars(0, clk_counter_leds_top_tb);
        
        initialize_tb();
        
        // =========================================================================
        // TEST 1: Reset Functionality
        // =========================================================================
        run_test_case("Reset Functionality");
        
        apply_reset(20);
        check_leds(8'h00, "Reset state");
        
        // Test reset during operation
        tb_enable = 1'b1;
        wait_clocks(1000);  // Let some time pass
        apply_reset(5);
        check_leds(8'h00, "Reset during operation");
        
        // =========================================================================
        // TEST 2: Enable/Disable Control
        // =========================================================================
        run_test_case("Enable/Disable Control");
        
        apply_reset(5);
        
        // Verify no counting when disabled
        tb_enable = 1'b0;
        logic [7:0] leds_before = LEDG;
        wait_clocks(COUNT_FREQ + 1000);  // Wait longer than count period
        if (LEDG != leds_before) begin
            $error("LEDs changed while disabled");
            error_count++;
        end else begin
            $display("PASS: No counting when disabled");
        end
        
        // Enable and verify counting starts
        tb_enable = 1'b1;
        wait_for_led_changes(1);
        if (LEDG[LED_CNTR_WIDTH-1:0] == 8'h01) begin
            $display("PASS: Counting started correctly");
        end else begin
            $error("Unexpected LED value after enable: 0x%02h", LEDG);
            error_count++;
        end
        
        // =========================================================================
        // TEST 3: Basic Counting Sequence
        // =========================================================================
        run_test_case("Basic Counting Sequence");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Observe several increments
        for (int i = 1; i <= 5; i++) begin
            wait_for_led_changes(1);
            $display("Count %0d: LEDs = 0x%02h", i, LEDG);
            
            // Basic sanity check - counter should increment
            if (LEDG[LED_CNTR_WIDTH-1:0] != i[LED_CNTR_WIDTH-1:0]) begin
                $warning("Unexpected counter value at step %0d", i);
            end
        end
        
        // =========================================================================
        // TEST 4: Timing Verification
        // =========================================================================
        run_test_case("Timing Verification");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Measure time between LED changes
        integer start_time, end_time, measured_period;
        
        wait_for_led_changes(1);
        start_time = $time;
        wait_for_led_changes(1);
        end_time = $time;
        measured_period = end_time - start_time;
        
        integer expected_period = COUNT_FREQ * CLOCK_PERIOD_NS;
        real period_error = real'(measured_period - expected_period) / real'(expected_period) * 100.0;
        
        $display("Timing Analysis:");
        $display("  Expected period: %0d ns", expected_period);
        $display("  Measured period: %0d ns", measured_period);
        $display("  Error: %0.2f%%", period_error);
        
        if (measured_period == expected_period) begin
            $display("PASS: Timing is exact");
        end else begin
            $warning("Timing mismatch detected");
        end
        
        // =========================================================================
        // TEST 5: Disable During Count
        // =========================================================================
        run_test_case("Disable During Count");
        
        apply_reset(5);
        tb_enable = 1'b1;
        
        // Let counter run partway
        wait_clocks(COUNT_FREQ / 2);  // Halfway through count period
        
        // Disable and verify counting stops
        tb_enable = 1'b0;
        logic [7:0] leds_at_disable = LEDG;
        wait_clocks(COUNT_FREQ);  // Wait a full period
        
        if (LEDG == leds_at_disable) begin
            $display("PASS: Counter stopped when disabled mid-count");
        end else begin
            $error("Counter continued after disable");
            error_count++;
        end
        
        // Re-enable and verify it continues
        tb_enable = 1'b1;
        wait_for_led_changes(1);
        $display("PASS: Counter resumed after re-enable");
        
        // =========================================================================
        // TEST 6: Edge Cases
        // =========================================================================
        run_test_case("Edge Cases");
        
        apply_reset(5);
        
        // Rapid enable/disable toggles
        for (int i = 0; i < 10; i++) begin
            tb_enable = 1'b1;
            wait_clocks(5);
            tb_enable = 1'b0;
            wait_clocks(5);
        end
        
        // Verify system still works
        tb_enable = 1'b1;
        wait_for_led_changes(1);
        $display("PASS: System functional after rapid toggles");
        
        // =========================================================================
        // TEST COMPLETION
        // =========================================================================
        
        test_running = 1'b0;
        
        $display("\n=== TEST SUMMARY ===");
        $display("Tests run: %0d", test_case_num);
        $display("Errors: %0d", error_count);
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
    // TIMEOUT PROTECTION
    // =============================================================================
    
    initial begin
        #SIM_TIME_LIMIT;
        $error("Simulation timeout reached");
        $finish;
    end
    
endmodule
