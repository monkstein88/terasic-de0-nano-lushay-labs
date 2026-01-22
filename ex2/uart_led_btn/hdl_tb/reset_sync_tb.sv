// Testbench for reset synchronizer module
`timescale 1ns / 1ps // Note: the simulation time unit must be set to 1 [ns]

module reset_sync_tb;

  // =============================================================================
  // TESTBENCH PARAMETERS AND CONSTANTS
  // =============================================================================
  // Testbench parameters - matching DUT's:
  localparam CLOCK_FREQ = 50_000_000; // External Clock source, in [Hz]
  localparam CLOCK_PERIOD = 20;  // External Clock source, in [ns]
  localparam SYNC_STAGES = 2;   // Number of synchronization stages
  localparam RESET_POLARITY = "LOW"; // Reset polarity: "LOW" for active low reset 
  // Testbench parameters - for simulation:
  localparam SIMULATION_TIME = 100_000_000; // Simulation time in [ns]

  // =============================================================================
  // TESTBENCH SIGNALS
  // =============================================================================
  logic clk;              // Clock signal
  logic async_rst;        // Asynchronous reset input 
  logic synced_rst;       // Synchronized reset output

  integer unsigned fail_count = 0; // Test fail counter
  // =============================================================================
  // CLOCK GENERATION
  // =============================================================================
  initial begin
    clk = 1'b0;
    forever #(CLOCK_PERIOD / 2) clk = ~clk; // Toggle clock every half period
  end   

  // =============================================================================
  // UNIT UNDER TEST (UUT) INSTANTIATION
  // =============================================================================
  reset_sync #(
      .SYNC_STAGES(SYNC_STAGES),
      .RESET_POLARITY(RESET_POLARITY)
  ) UUT (
      .clk_i(clk),
      .async_rst_i(async_rst),
      .synced_rst_o(synced_rst)
  );

  // =============================================================================
  // TEST SEQUENCE
  // =============================================================================
  initial begin
    // Display testbench header information
    $display("============================");
    $display("Reset Synchronizer Testbench");
    $display("============================");
    $display("Clock Frequency: %0d Hz", CLOCK_FREQ);    
    $display("Clock Period: %0d ns", CLOCK_PERIOD);
    $display("Reset Polarity: %s", RESET_POLARITY);
    $display("Synchronization Stages: %0d", SYNC_STAGES);
    $display("===========================");

    $display("=== Initializing signals: ===");
    async_rst = (RESET_POLARITY == "HIGH") ? 1'b0 : 1'b1; // Deassert reset based on polarity
    $display("  Time: %0t [ns] | 'async_rst' input initialized to %b (deasserted), 'synced_rst' output is %b", $time, async_rst, synced_rst);

    $display("=== Starting Test Sequence: ===");

    // Test 1: Observing 'synced_rst' over (SYNC_STAGES+1) clock cycles after initialization
    $display("Test 1: Observing 'synced_rst' behaviour - over %0d (SYNC_STAGES+1) clock cycles after initialization", SYNC_STAGES+1); 
    $display("  Time: %0t [ns] | 'async_rst' is deasserted", $time);
    #1; // Small delay to ensure initialization is registered
    $display("  Time: %0t [ns] | 'synced_rst' shortly after initialization: %b (should be deasserted)", $time, synced_rst);
    for(int i = 1; i <= (SYNC_STAGES + 1); i++)begin
      @(posedge clk);
      $display("  Time: %0t [ns] | Clock: %0d after initialization | 'synced_rst': %b", $time, i, synced_rst);
      if (synced_rst !== ((RESET_POLARITY == "HIGH") ? 1'b0 : 1'b1)) begin
        $display("    ERROR: 'synced_rst' is not deasserted as expected!");
        fail_count++;
      end
    end
    if (fail_count == 0) begin
      $display("  Test 1 PASSED: 'synced_rst' was kept deasserted during the test.");
    end else begin
      $display("  Test 1 FAILED: 'synced_rst' was not kept deasserted during the test!");
    end
    
    $display("");
    // Wait for a few clocke cycles
    repeat(3) @(posedge clk);

    // Test 2: Reset Synchronzier - check asynchronous reset (assertion) behaviour
    $display("Test 2: Checking 'synced_rst' behaviour - for asynchronous reset");
    fail_count = 0; // Reset fail count
    async_rst = (RESET_POLARITY == "HIGH") ? 1'b1 : 1'b0; // Assert reset based on polarity
    $display("  Time: %0t [ns] | 'async_rst' asserted", $time);
    #1; // Small delay to ensure reset assertion is propagated
    $display("  Time: %0t [ns] | 'synced_rst' shortly after 'async_rst' assertion : %b (should be asserted)", $time, synced_rst);
    if (synced_rst !== ((RESET_POLARITY == "HIGH") ? 1'b1 : 1'b0)) begin
      $display("    ERROR: 'synced_rst' did not assert immediately as expected!");
      fail_count++;
    end
    if (fail_count == 0) begin
      $display("  Test 2 PASSED: 'synced_rst' asserted immediately.");
    end else begin
      $display("  Test 2 FAILED: 'synced_rst' did not assert immediately!");
    end

    $display("");
    
    // Test 3: Reset Synchronzier - check reset output 'synced_rst' is kept asserted over multiple clock cycles, if the 'async_rst' is still held asserted
    $display("Test 3: Checking 'synced_rst' behaviour - keeping the reset asserted over multiple clock cycles");
    fail_count = 0; // Reset fail count
    for(int i = 1; i<= (SYNC_STAGES + 2); i++) begin
      @(posedge clk);
      $display("  Time: %0t [ns] | Clock: %0d while 'async_rst' is asserted | 'synced_rst': %b", $time, i, synced_rst);
      if (synced_rst !== ((RESET_POLARITY == "HIGH") ? 1'b1 : 1'b0)) begin
        $display("    ERROR: 'synced_rst' is not kept asserted as expected!");
        fail_count++;
      end
    end
    if (fail_count == 0) begin
      $display("  Test 3 PASSED: 'synced_rst' was kept asserted.");
    end else begin
      $display("  Test 3 FAILED: 'synced_rst' was not kept asserted during the test!");
    end
  
    $display("");
    // Wait for a few clocke cycles
    repeat(3) @(posedge clk);

    // Test 4: Reset Synchronzier - check synchronous reset (deassertion) behaviour
    $display("Test 4: Checking 'synced_rst' behaviour - for synchronous reset deassertion");
    fail_count = 0; // Reset fail count
    async_rst = (RESET_POLARITY == "HIGH") ? 1'b0 : 1'b1; // Deassert reset based on polarity
    $display("  Time: %0t [ns] | 'async_rst' deasserted", $time);
    #1; // Small delay to ensure reset deassertion is propagated
    $display("  Time: %0t [ns] | 'synced_rst' shortly after 'async_rst' deassertion : %b (should be asserted still)", $time, synced_rst);
    // Observe 'synced_rst' over SYNC_STAGES clock cycles
    for(int i = 1; i <= (SYNC_STAGES); i++) begin  
      @(posedge clk);
      $display("  Time: %0t [ns] | Clock: %0d after 'async_rst' deassertion | 'synced_rst': %b (expected to stay asserted)", $time, i, synced_rst);
      if (synced_rst !== ((RESET_POLARITY == "HIGH") ? 1'b1 : 1'b0)) begin
        $display("    ERROR: 'synced_rst' did not deassert as expected - deassertion too soon!");
        fail_count++;
      end
    end
    @(posedge clk);    // Final check after SYNC_STAGES cycles -  One more clock cycle
    $display("  Time: %0t [ns] | Clock: %0d (SYNC_STAGES + 1) after 'async_rst' deassertion | 'synced_rst': %b (expected to be deasserted now)", $time, i, synced_rst);
    if (synced_rst !== ((RESET_POLARITY == "HIGH") ? 1'b0 : 1'b1)) begin
      $display("    ERROR: 'synced_rst' did not deassert as expected after SYNC_STAGES cycles!");
      fail_count++;
    end
    if (fail_count == 0) begin
      $display("  Test 4 PASSED: 'synced_rst' deasserted correctly after SYNC_STAGES cycles.");
    end else begin
      $display("  Test 4 FAILED: 'synced_rst' did not deassert correctly!");
    end

    $display("");
    // Wait for a few clocke cycles
    repeat(3) @(posedge clk);

    // Test 5: Reset Synchonizer - Metastability test, asserting reset near clock edge
    $display("Test 5: Checking 'synced_rst' behaviour - Metastability issues");
    fail_count = 0; // Reset fail count
    @(posedge clk);
    $display("  Time: %0t [ns] | Keeping 'async_rst' asserted, till, close to clock edge", $time);
    async_rst = (RESET_POLARITY == "HIGH") ? 1'b1 : 1'b0; // Keep the reset asserted, till ...
    #(CLOCK_PERIOD - 0.5); //  ... right before (very close to) the clock edge, and then ...
    $display("  Time: %0t [ns] | Deasserting 'async_rst' shortly before the clock edge", $time);
    async_rst = (RESET_POLARITY == "HIGH") ? 1'b0 : 1'b1; //  ...deassert the reset input. All based on polarity.
    #1; // wait a small amount
    $display("  Time: %0t [ns] | Reset 'async_rst' toggled close around the clock edge", $time);
    for(int i = 1; i <= SYNC_STAGES; i++) begin 
      @(posedge clk);
      $display("  Time: %0t [ns] | Clock: %0d after 'async_rst' deassertion | 'synced_rst': %b (expected to stay asserted)", $time, i, synced_rst);
      if (synced_rst !== ((RESET_POLARITY == "HIGH") ? 1'b1 : 1'b0)) begin
        $display("    ERROR: 'synced_rst' did not deassert as expected - deassertion too soon!");
        fail_count++;
      end
    end
    
    
    
    
    
    $display("=== Test Sequence Completed! ===");
    $finish;
  end


endmodule