`timescale 1ns / 1ps

module reset_sync_tb;

  // Test parameters
  localparam CLK_PERIOD = 10; // 100MHz clock
  localparam TEST_DURATION = 1000; // Test duration in clock cycles
  
  // Testbench signals
  logic clk_i;
  logic async_rst_i;
  logic synced_rst_o_high;
  logic synced_rst_o_low;
  logic synced_rst_o_high_4stage;
  logic synced_rst_o_low_4stage;
  
  // Test control signals
  logic test_passed = 1'b1;
  integer test_count = 0;
  integer pass_count = 0;
  integer fail_count = 0;
  
  // Clock generation
  initial begin
    clk_i = 1'b0;
    forever #(CLK_PERIOD/2) clk_i = ~clk_i;
  end
  
  // DUT instantiations - testing different configurations
  
  // Active-high reset, 2 stages (default)
  reset_sync #(
    .RESET_POLARITY("HIGH"),
    .SYNC_STAGES(2)
  ) dut_high_2stage (
    .async_rst_i(async_rst_i),
    .clk_i(clk_i),
    .synced_rst_o(synced_rst_o_high)
  );
  
  // Active-low reset, 2 stages
  reset_sync #(
    .RESET_POLARITY("LOW"),
    .SYNC_STAGES(2)
  ) dut_low_2stage (
    .async_rst_i(async_rst_i),
    .clk_i(clk_i),
    .synced_rst_o(synced_rst_o_low)
  );
  
  // Active-high reset, 4 stages
  reset_sync #(
    .RESET_POLARITY("HIGH"),
    .SYNC_STAGES(4)
  ) dut_high_4stage (
    .async_rst_i(async_rst_i),
    .clk_i(clk_i),
    .synced_rst_o(synced_rst_o_high_4stage)
  );
  
  // Active-low reset, 4 stages
  reset_sync #(
    .RESET_POLARITY("LOW"),
    .SYNC_STAGES(4)
  ) dut_low_4stage (
    .async_rst_i(async_rst_i),
    .clk_i(clk_i),
    .synced_rst_o(synced_rst_o_low_4stage)
  );

  // Test tasks
  task automatic test_async_assert_sync_deassert_high(input int stages);
    begin
      $display("=== Testing Active-High Reset Async Assert/Sync Deassert (%0d stages) ===", stages);
      test_count++;
      
      // Start with reset deasserted
      async_rst_i = 1'b0;
      repeat(5) @(posedge clk_i);
      
      // Check that reset output is deasserted after sync stages
      if (stages == 2) begin
        if (synced_rst_o_high !== 1'b0) begin
          $error("FAIL: Active-high reset should be deasserted, got %b", synced_rst_o_high);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset properly deasserted");
          pass_count++;
        end
      end else begin
        if (synced_rst_o_high_4stage !== 1'b0) begin
          $error("FAIL: Active-high reset should be deasserted, got %b", synced_rst_o_high_4stage);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset properly deasserted");
          pass_count++;
        end
      end
      
      // Test asynchronous assertion
      async_rst_i = 1'b1;
      #1; // Small delay to allow async assertion
      
      if (stages == 2) begin
        if (synced_rst_o_high !== 1'b1) begin
          $error("FAIL: Reset should assert immediately (async), got %b", synced_rst_o_high);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset asserted asynchronously");
          pass_count++;
        end
      end else begin
        if (synced_rst_o_high_4stage !== 1'b1) begin
          $error("FAIL: Reset should assert immediately (async), got %b", synced_rst_o_high_4stage);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset asserted asynchronously");
          pass_count++;
        end
      end
      
      // Test synchronous deassertion
      async_rst_i = 1'b0;
      
      // Should still be asserted for (stages-1) clock cycles
      repeat(stages-1) begin
        @(posedge clk_i);
        if (stages == 2) begin
          if (synced_rst_o_high !== 1'b1) begin
            $error("FAIL: Reset should still be asserted during sync deassertion");
            test_passed = 1'b0;
            fail_count++;
          end
        end else begin
          if (synced_rst_o_high_4stage !== 1'b1) begin
            $error("FAIL: Reset should still be asserted during sync deassertion");
            test_passed = 1'b0;
            fail_count++;
          end
        end
      end
      
      // After 'stages' clock cycles, should be deasserted
      @(posedge clk_i);
      if (stages == 2) begin
        if (synced_rst_o_high !== 1'b0) begin
          $error("FAIL: Reset should be deasserted after %0d clock cycles, got %b", stages, synced_rst_o_high);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset deasserted synchronously after %0d clock cycles", stages);
          pass_count++;
        end
      end else begin
        if (synced_rst_o_high_4stage !== 1'b0) begin
          $error("FAIL: Reset should be deasserted after %0d clock cycles, got %b", stages, synced_rst_o_high_4stage);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset deasserted synchronously after %0d clock cycles", stages);
          pass_count++;
        end
      end
      
      repeat(3) @(posedge clk_i);
    end
  endtask
  
  task automatic test_async_assert_sync_deassert_low(input int stages);
    begin
      $display("=== Testing Active-Low Reset Async Assert/Sync Deassert (%0d stages) ===", stages);
      test_count++;
      
      // Start with reset deasserted (high for active-low)
      async_rst_i = 1'b1;
      repeat(5) @(posedge clk_i);
      
      // Check that reset output is deasserted
      if (stages == 2) begin
        if (synced_rst_o_low !== 1'b1) begin
          $error("FAIL: Active-low reset should be deasserted (high), got %b", synced_rst_o_low);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset properly deasserted");
          pass_count++;
        end
      end else begin
        if (synced_rst_o_low_4stage !== 1'b1) begin
          $error("FAIL: Active-low reset should be deasserted (high), got %b", synced_rst_o_low_4stage);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset properly deasserted");
          pass_count++;
        end
      end
      
      // Test asynchronous assertion (low for active-low)
      async_rst_i = 1'b0;
      #1; // Small delay to allow async assertion
      
      if (stages == 2) begin
        if (synced_rst_o_low !== 1'b0) begin
          $error("FAIL: Active-low reset should assert immediately (async), got %b", synced_rst_o_low);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset asserted asynchronously");
          pass_count++;
        end
      end else begin
        if (synced_rst_o_low_4stage !== 1'b0) begin
          $error("FAIL: Active-low reset should assert immediately (async), got %b", synced_rst_o_low_4stage);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset asserted asynchronously");
          pass_count++;
        end
      end
      
      // Test synchronous deassertion
      async_rst_i = 1'b1;
      
      // Should still be asserted for (stages-1) clock cycles
      repeat(stages-1) begin
        @(posedge clk_i);
        if (stages == 2) begin
          if (synced_rst_o_low !== 1'b0) begin
            $error("FAIL: Reset should still be asserted during sync deassertion");
            test_passed = 1'b0;
            fail_count++;
          end
        end else begin
          if (synced_rst_o_low_4stage !== 1'b0) begin
            $error("FAIL: Reset should still be asserted during sync deassertion");
            test_passed = 1'b0;
            fail_count++;
          end
        end
      end
      
      // After 'stages' clock cycles, should be deasserted
      @(posedge clk_i);
      if (stages == 2) begin
        if (synced_rst_o_low !== 1'b1) begin
          $error("FAIL: Active-low reset should be deasserted after %0d clock cycles, got %b", stages, synced_rst_o_low);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset deasserted synchronously after %0d clock cycles", stages);
          pass_count++;
        end
      end else begin
        if (synced_rst_o_low_4stage !== 1'b1) begin
          $error("FAIL: Active-low reset should be deasserted after %0d clock cycles, got %b", stages, synced_rst_o_low_4stage);
          test_passed = 1'b0;
          fail_count++;
        end else begin
          $display("PASS: Reset deasserted synchronously after %0d clock cycles", stages);
          pass_count++;
        end
      end
      
      repeat(3) @(posedge clk_i);
    end
  endtask
  
  task test_multiple_reset_pulses();
    begin
      $display("=== Testing Multiple Reset Pulses ===");
      test_count++;
      
      async_rst_i = 1'b0;
      repeat(10) @(posedge clk_i);
      
      // Multiple short reset pulses
      for (int i = 0; i < 3; i++) begin
        async_rst_i = 1'b1;
        repeat(2) @(posedge clk_i);
        async_rst_i = 1'b0;
        repeat(5) @(posedge clk_i);
      end
      
      // Check final state
      if (synced_rst_o_high === 1'b0) begin
        $display("PASS: Multiple reset pulses handled correctly");
        pass_count++;
      end else begin
        $error("FAIL: Reset not properly deasserted after multiple pulses");
        test_passed = 1'b0;
        fail_count++;
      end
    end
  endtask
  
  task test_reset_during_deassertion();
    begin
      $display("=== Testing Reset During Deassertion ===");
      test_count++;
      
      // Assert reset
      async_rst_i = 1'b1;
      repeat(3) @(posedge clk_i);
      
      // Start deassertion
      async_rst_i = 1'b0;
      @(posedge clk_i); // One clock cycle into deassertion
      
      // Assert reset again during deassertion
      async_rst_i = 1'b1;
      #1;
      
      if (synced_rst_o_high === 1'b1) begin
        $display("PASS: Reset immediately asserted during deassertion");
        pass_count++;
      end else begin
        $error("FAIL: Reset should immediately assert during deassertion");
        test_passed = 1'b0;
        fail_count++;
      end
      
      // Complete the test
      async_rst_i = 1'b0;
      repeat(5) @(posedge clk_i);
    end
  endtask

  // Main test sequence
  initial begin
    $display("Starting Reset Synchronizer Testbench");
    $display("=====================================");
    
    // Initialize
    async_rst_i = 1'b0;
    repeat(10) @(posedge clk_i);
    
    // Test active-high reset with 2 stages
    test_async_assert_sync_deassert_high(2);
    
    // Test active-low reset with 2 stages  
    test_async_assert_sync_deassert_low(2);
    
    // Test active-high reset with 4 stages
    test_async_assert_sync_deassert_high(4);
    
    // Test active-low reset with 4 stages
    test_async_assert_sync_deassert_low(4);
    
    // Test edge cases
    test_multiple_reset_pulses();
    test_reset_during_deassertion();
    
    // Final results
    repeat(10) @(posedge clk_i);
    
    $display("\n=====================================");
    $display("Test Results Summary:");
    $display("Total Tests: %0d", test_count);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);
    
    if (test_passed) begin
      $display("*** ALL TESTS PASSED ***");
    end else begin
      $display("*** SOME TESTS FAILED ***");
    end
    $display("=====================================");
    
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #(CLK_PERIOD * TEST_DURATION);
    $error("TIMEOUT: Testbench exceeded maximum runtime");
    $finish;
  end
  
  // Optional: Dump waveforms for debugging
  initial begin
    $dumpfile("reset_sync_tb.vcd");
    $dumpvars(0, reset_sync_tb);
  end

endmodule
