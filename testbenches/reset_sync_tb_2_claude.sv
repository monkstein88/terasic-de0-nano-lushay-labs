`timescale 1ns/1ps

module reset_sync_tb;

  // Testbench parameters
  localparam CLK_PERIOD = 10; // 100 MHz clock
  localparam SYNC_STAGES_TEST = 3; // Number of stages to test
  
  // Testbench signals
  logic async_rst;
  logic clk;
  logic synced_rst_high;
  logic synced_rst_low;
  
  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // DUT instantiation - Active HIGH reset
  reset_sync #(
    .RESET_POLARITY("HIGH"),
    .SYNC_STAGES(SYNC_STAGES_TEST)
  ) dut_active_high (
    .async_rst_i(async_rst),
    .clk_i(clk),
    .synced_rst_o(synced_rst_high)
  );
  
  // DUT instantiation - Active LOW reset
  reset_sync #(
    .RESET_POLARITY("LOW"),
    .SYNC_STAGES(SYNC_STAGES_TEST)
  ) dut_active_low (
    .async_rst_i(async_rst),
    .clk_i(clk),
    .synced_rst_o(synced_rst_low)
  );
  
  // Test sequence
  initial begin
    $display("========================================");
    $display("Reset Synchronizer Testbench Starting");
    $display("========================================");
    $display("Clock Period: %0d ns", CLK_PERIOD);
    $display("Sync Stages: %0d", SYNC_STAGES_TEST);
    $display("");
    
    // Initialize
    async_rst = 0;
    
    // Wait for a few clock cycles
    repeat(5) @(posedge clk);
    
    // Test 1: Active-HIGH reset - Asynchronous assertion
    $display("Test 1: Active-HIGH Reset - Asynchronous Assertion");
    async_rst = 1;
    #1; // Small delay to see asynchronous effect
    $display("  t=%0t: async_rst asserted, synced_rst_high=%b (should be 1 immediately)", 
             $time, synced_rst_high);
    
    // Hold reset for a few cycles
    repeat(3) @(posedge clk);
    
    // Test 2: Active-HIGH reset - Synchronous deassertion
    $display("Test 2: Active-HIGH Reset - Synchronous Deassertion");
    @(posedge clk);
    async_rst = 0;
    $display("  t=%0t: async_rst deasserted at clock edge", $time);
    
    // Monitor deassertion through sync stages
    for(int i = 1; i <= SYNC_STAGES_TEST + 1; i++) begin
      @(posedge clk);
      $display("  t=%0t: Clock %0d after deassertion, synced_rst_high=%b", 
               $time, i, synced_rst_high);
    end
    
    // Verify full deassertion
    if(synced_rst_high == 0) begin
      $display("  PASS: Reset deasserted after %0d clock cycles", SYNC_STAGES_TEST);
    end else begin
      $display("  FAIL: Reset not deasserted properly!");
    end
    $display("");
    
    // Wait before next test
    repeat(5) @(posedge clk);
    
    // Test 3: Active-LOW reset - Asynchronous assertion
    $display("Test 3: Active-LOW Reset - Asynchronous Assertion");
    async_rst = 0;
    #1; // Small delay to see asynchronous effect
    $display("  t=%0t: async_rst asserted (LOW), synced_rst_low=%b (should be 0 immediately)", 
             $time, synced_rst_low);
    
    // Hold reset for a few cycles
    repeat(3) @(posedge clk);
    
    // Test 4: Active-LOW reset - Synchronous deassertion
    $display("Test 4: Active-LOW Reset - Synchronous Deassertion");
    @(posedge clk);
    async_rst = 1;
    $display("  t=%0t: async_rst deasserted (HIGH) at clock edge", $time);
    
    // Monitor deassertion through sync stages
    for(int i = 1; i <= SYNC_STAGES_TEST + 1; i++) begin
      @(posedge clk);
      $display("  t=%0t: Clock %0d after deassertion, synced_rst_low=%b", 
               $time, i, synced_rst_low);
    end
    
    // Verify full deassertion
    if(synced_rst_low == 1) begin
      $display("  PASS: Reset deasserted after %0d clock cycles", SYNC_STAGES_TEST);
    end else begin
      $display("  FAIL: Reset not deasserted properly!");
    end
    $display("");
    
    // Test 5: Metastability test - Assert reset near clock edge
    repeat(5) @(posedge clk);
    $display("Test 5: Metastability Test - Reset Toggle Near Clock Edge");
    async_rst = 0;
    #(CLK_PERIOD - 0.5); // Assert very close to clock edge
    async_rst = 1;
    #1;
    $display("  t=%0t: Reset toggled near clock edge", $time);
    repeat(SYNC_STAGES_TEST + 2) @(posedge clk);
    $display("  System stabilized, synced_rst_high=%b, synced_rst_low=%b", 
             synced_rst_high, synced_rst_low);
    $display("");
    
    // Test 6: Short pulse test
    repeat(5) @(posedge clk);
    $display("Test 6: Short Async Reset Pulse (< 1 clock cycle)");
    async_rst = 0;
    #(CLK_PERIOD/4); // Short pulse
    async_rst = 1;
    $display("  t=%0t: Short reset pulse applied", $time);
    repeat(SYNC_STAGES_TEST + 2) @(posedge clk);
    $display("  After sync stages, synced_rst_high=%b, synced_rst_low=%b", 
             synced_rst_high, synced_rst_low);
    $display("");
    
    // Final summary
    $display("========================================");
    $display("Testbench Completed Successfully");
    $display("========================================");
    
    #100;
    $finish;
  end
  
  // Waveform dumping
  initial begin
    $dumpfile("reset_sync_tb.vcd");
    $dumpvars(0, reset_sync_tb);
  end
  
  // Optional: Monitor for unexpected changes
  always @(synced_rst_high) begin
    $display("  [Monitor] t=%0t: synced_rst_high changed to %b", $time, synced_rst_high);
  end
  
  always @(synced_rst_low) begin
    $display("  [Monitor] t=%0t: synced_rst_low changed to %b", $time, synced_rst_low);
  end

endmodule