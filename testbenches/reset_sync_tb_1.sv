// Testbench for reset synchronizer module
`timescale  1ns / 1ps

module reset_sync_tb;

  // Parameters
  parameter CLK_PERIOD_NS = 10; // 100 MHz clock

  // Signals
  logic clk;
  logic async_in_rst;
  logic synced_out_rst;

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD_NS / 2) clk = ~clk;
  end

  // Instantiate the reset synchronization module
  reset_sync #(
    .RESET_POLARITY("LOW"),
    .SYNC_STAGES(2)
  ) uut (
    .async_rst_i(async_in_rst),
    .clk_i(clk),
    .synced_rst_o(synced_rst)
  );

  // Test sequence
  initial begin
    // Initialize signals
    async_rst = 1'b1; // Not in reset (active low)
    #25;

    // Apply asynchronous reset
    async_rst = 1'b0; // Assert reset
    #15;
    async_rst = 1'b1; // Deassert reset

    // Wait and observe synchronized reset output
    #100;

    // Finish simulation
    $finish;
  end