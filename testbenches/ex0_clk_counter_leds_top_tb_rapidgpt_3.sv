`timescale 1ns / 1ps

module tb_clk_counter_leds_top;

    // Parameters matching the DUT
    parameter EXT_CLOCK_FREQ = 50000000;
    parameter EXT_CLOCK_PERIOD = 20.000;
    
    // Testbench signals
    logic          EXTCLK;
    logic   [1:0]  KEY_n;
    logic   [7:0]  LEDG;
    
    // Clock generation
    initial begin
        EXTCLK = 0;
        forever #(EXT_CLOCK_PERIOD/2) EXTCLK = ~EXTCLK; // 50MHz clock
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
    
    // Test stimulus
    initial begin
        // Initialize signals
        KEY_n = 2'b11; // Both keys not pressed (active-low)
        
        // Wait for a few clock cycles
        repeat(5) @(posedge EXTCLK);
        
        $display("=== Starting Testbench ===");
        $display("Time: %0t | Testing normal operation", $time);
        
        // Test 1: Normal counting operation
        repeat(20) begin
            @(posedge EXTCLK);
            $display("Time: %0t | Counter[31:24] = %h, LEDG = %b", 
                     $time, dut.clk_counter[31:24], LEDG);
        end
        
        // Test 2: Reset functionality
        $display("\nTime: %0t | Testing reset functionality", $time);
        KEY_n[0] = 1'b0; // Assert reset (active-low)
        #50; // Hold reset for 50ns
        
        $display("Time: %0t | Reset asserted, LEDG should be 0: %b", $time, LEDG);
        
        KEY_n[0] = 1'b1; // Deassert reset
        @(posedge EXTCLK);
        $display("Time: %0t | Reset released, counter should restart: LEDG = %b", $time, LEDG);
        
        // Test 3: Let counter run to see LED changes
        $display("\nTime: %0t | Running counter to observe LED changes", $time);
        repeat(300) begin
            @(posedge EXTCLK);
            if (dut.clk_counter[7:0] == 8'h00) begin // Print every 256 counts
                $display("Time: %0t | Counter = %h, LEDG = %b", 
                         $time, dut.clk_counter, LEDG);
            end
        end
        
        // Test 4: Reset during operation
        $display("\nTime: %0t | Testing reset during operation", $time);
        KEY_n[0] = 1'b0; // Assert reset
        repeat(3) @(posedge EXTCLK);
        KEY_n[0] = 1'b1; // Deassert reset
        
        repeat(10) begin
            @(posedge EXTCLK);
            $display("Time: %0t | After mid-operation reset, LEDG = %b", $time, LEDG);
        end
        
        // Test 5: Test KEY[1] (user button) - should not affect counter
        $display("\nTime: %0t | Testing KEY[1] (should not affect counter)", $time);
        KEY_n[1] = 1'b0; // Press user button
        repeat(10) @(posedge EXTCLK);
        KEY_n[1] = 1'b1; // Release user button
        repeat(10) @(posedge EXTCLK);
        $display("Time: %0t | KEY[1] test complete, counter should continue normally", $time);
        
        $display("\n=== Testbench Complete ===");
        $finish;
    end
    
    // Monitor for continuous display (optional)
    initial begin
        $monitor("Time: %0t | EXTCLK: %b | KEY_n: %b | Counter: %h | LEDG: %b", 
                 $time, EXTCLK, KEY_n, dut.clk_counter, LEDG);
    end
    
    // Waveform dumping (for simulation tools that support it)
    initial begin
        $dumpfile("tb_clk_counter_leds_top.vcd");
        $dumpvars(0, tb_clk_counter_leds_top);
    end

endmodule
