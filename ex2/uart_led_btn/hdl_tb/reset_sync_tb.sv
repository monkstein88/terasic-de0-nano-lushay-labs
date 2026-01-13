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
    $display("===============================================");
    $display("RESET SYNCHRONIZER TESTBENCH - 'reset_sync_tb'");
    $display("Clock Frequency: %0d Hz", CLOCK_FREQ);    
    $display("Clock Period: %0d ns", CLOCK_PERIOD);
    $display("Reset Polarity: %s", RESET_POLARITY);
    $display("Synchronization Stages: %0d", SYNC_STAGES);
    $display("===============================================");

    // Initialize signals - set async_rst to inactive (deasserted) state
    async_rst = (RESET_POLARITY == "LOW") ? 1'b1 : 1'b0; // Set to inactive state
    // Check immediate state of synced_rst (note: it undefined at time 0) :  
    $display("Time: %0t ns | Initial (immediate) value of 'synced_rst': %b", $time, synced_rst);
    // Check the state of synced_rst after 1st clock edge:
    @(posedge clk); 
    $display("Time: %0t ns | 'synced_rst' value at 1st clock: %b", $time, synced_rst);
    // Check the state of synced_rst after SYNC_STAGES clock edges, to allow reset synchronization to settle:
    repeat (SYNC_STAGES-1) @(posedge clk); // Note: already waited for 1 clock above, thus SYNC_STAGES-1 here
    $display("Time: %0t ns | 'synced_rst' value at '#SYNC_STAGES' clocks: %b", $time, synced_rst);  // At this point, still 'synced_rst' should be still asserted
    if (RESET_POLARITY == "LOW") begin
      if (synced_rst !== 1'b0) begin
        $display("ERROR: 'synced_rst' should be asserted (0) at '#SYNC_STAGES' clocks when reset is active low!");
      end else begin
        $display("SUCCESS: 'synced_rst' is correctly asserted (0) at '#SYNC_STAGES' clocks, when reset is active low!");
      end
    end else begin
      if (synced_rst !== 1'b1) begin
        $display("ERROR: 'synced_rst' should be asserted (1) at '#SYNC_STAGES' clocks, when reset is active high!");
      end else begin
        $display("SUCCESS: 'synced_rst' is correctly asserted (1) at '#SYNC_STAGES' clocks, when reset is active high!");
      end
    end
    #1 ; // Put small delay to check the value after the clock edge
    $display("Time: %0t ns | 'synced_rst' value just #1 after '#SYNC_STAGES' clocks: %b", $time, synced_rst); // Just after the clock edge, 'synced_rst' should be deasserted
    if(RESET_POLARITY == "LOW") begin
      if (synced_rst !== 1'b0) begin
        $display("ERROR: 'synced_rst' should be still asserted (0) just after '#SYNC_STAGES' clocks when reset is active low!");
      end else begin
        $display("SUCCESS: 'synced_rst' is correctly still asserted (0) just after '#SYNC_STAGES' clocks, when reset is active low!");
      end
    end else begin
      if (synced_rst !== 1'b1) begin
        $display("ERROR: 'synced_rst' should be still asserted (1) just after '#SYNC_STAGES' clocks, when reset is active high!");
      end else begin
        $display("SUCCESS: 'synced_rst' is correctly still asserted (1) just after '#SYNC_STAGES' clocks, when reset is active high!");
      end
    end

    // Wait for a few clock cycles
    #(CLOCK_PERIOD * 5);

    // Assert reset
    async_rst = (RESET_POLARITY == "LOW") ? 1'b0 : 1'b1;
    #(CLOCK_PERIOD * 5);

    // Deassert reset
    async_rst = (RESET_POLARITY == "LOW") ? 1'b1 : 1'b0;

    // Wait for some time to observe synchronized reset deassertion
    #(CLOCK_PERIOD * 20);

    // Finish simulation
    $finish;
  end

  task check_reset_behavior;



  endtask


endmodule