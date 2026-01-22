`timescale 1ns / 1ps

module counter_tb();

    // Testbench parameters
    parameter CLK_PERIOD = 10;  // 100MHz clock
    parameter COUNTER_WIDTH = 8; // Adjust based on your counter width
    
    // DUT signals
    logic clk;
    logic rst_n;
    logic enable;
    logic [COUNTER_WIDTH-1:0] count_out;
    logic overflow;
    
    // Testbench variables
    integer test_count = 0;
    integer error_count = 0;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    counter_top #(
        .WIDTH(COUNTER_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .count_out(count_out),
        .overflow(overflow)
    );
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        enable = 0;
        
        // Wait for a few clock cycles
        repeat(5) @(posedge clk);
        
        // Release reset
        rst_n = 1;
        @(posedge clk);
        
        // Test 1: Basic counting test
        $display("=== Test 1: Basic Counting ===");
        test_basic_counting();
        
        // Test 2: Reset functionality
        $display("=== Test 2: Reset Functionality ===");
        test_reset_functionality();
        
        // Test 3: Enable/Disable functionality
        $display("=== Test 3: Enable/Disable ===");
        test_enable_disable();
        
        // Test 4: Overflow detection
        $display("=== Test 4: Overflow Detection ===");
        test_overflow();
        
        // Test summary
        $display("\n=== Test Summary ===");
        $display("Total tests: %0d", test_count);
        $display("Errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $finish;
    end
    
    // Test tasks
    task test_basic_counting();
        logic [COUNTER_WIDTH-1:0] expected_count;
        
        enable = 1;
        expected_count = 0;
        
        // Count for several cycles
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            expected_count++;
            
            if (count_out !== expected_count) begin
                $error("Time %0t: Count mismatch! Expected: %0d, Got: %0d", 
                       $time, expected_count, count_out);
                error_count++;
            end else begin
                $display("Time %0t: Count = %0d (PASS)", $time, count_out);
            end
            test_count++;
        end
        
        enable = 0;
    endtask
    
    task test_reset_functionality();
        // Enable counter and let it count
        enable = 1;
        repeat(5) @(posedge clk);
        
        // Assert reset
        rst_n = 0;
        @(posedge clk);
        
        // Check if counter is reset
        if (count_out !== 0) begin
            $error("Time %0t: Reset failed! Expected: 0, Got: %0d", 
                   $time, count_out);
            error_count++;
        end else begin
            $display("Time %0t: Reset successful (PASS)", $time);
        end
        test_count++;
        
        // Release reset
        rst_n = 1;
        enable = 0;
        @(posedge clk);
    endtask
    
    task test_enable_disable();
        logic [COUNTER_WIDTH-1:0] saved_count;
        
        // Enable and count
        enable = 1;
        repeat(3) @(posedge clk);
        saved_count = count_out;
        
        // Disable counter
        enable = 0;
        repeat(3) @(posedge clk);
        
        // Check if counter stopped
        if (count_out !== saved_count) begin
            $error("Time %0t: Enable/Disable failed! Expected: %0d, Got: %0d", 
                   $time, saved_count, count_out);
            error_count++;
        end else begin
            $display("Time %0t: Enable/Disable working correctly (PASS)", $time);
        end
        test_count++;
    endtask
    
    task test_overflow();
        // Reset counter
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        
        enable = 1;
        
        // Count to maximum value
        while (count_out < (2**COUNTER_WIDTH - 1)) begin
            @(posedge clk);
        end
        
        // One more clock should cause overflow
        @(posedge clk);
        
        if (overflow !== 1'b1) begin
            $error("Time %0t: Overflow not detected!", $time);
            error_count++;
        end else begin
            $display("Time %0t: Overflow detected correctly (PASS)", $time);
        end
        test_count++;
        
        enable = 0;
    endtask
    
    // Monitor for debugging
    initial begin
        $monitor("Time: %0t | clk: %b | rst_n: %b | enable: %b | count_out: %0d | overflow: %b",
                 $time, clk, rst_n, enable, count_out, overflow);
    end
    
    // Waveform dump (for simulation)
    initial begin
        $dumpfile("counter_tb.vcd");
        $dumpvars(0, counter_tb);
    end

endmodule
