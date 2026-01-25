module debounce #(
  parameter integer unsigned CLK_FREQ = 50_000_000, // Clock frequency in [Hz]
  parameter real DEBOUNCE_TIME = 1.0,  // Debounce time in [ms]
  parameter logic DEBOUNCE_INIT = 1'b0 // Initial (Idle) value (also reset-polarity) of the debounced output after reset
)(
  input  wire  arst_n_i, // Asynchronous reset (active low)
  input  wire  clk_i,    // Clock input
  input  wire  din_i,    // Raw digital input - active level does not matter
  output logic deb_o     // Debounced digital input - active level does not matter
);

// Calculate the number of clock cycles for the debounce time
localparam integer unsigned DEBOUNCE_CYCLES = (CLK_FREQ / 1000) * DEBOUNCE_TIME;
localparam integer unsigned DEBOUNCE_WIDTH = $clog2(DEBOUNCE_CYCLES + 1);

// Internal signals
logic deb_sync_0 = 1'b0;
logic deb_sync_1 = 1'b1; // Note: Initialized to opposite value of deb_sync_0 to ensure proper operation after reset
logic [DEBOUNCE_WIDTH-1:0] deb_counter = '0;

// Synchronize the digital input to the clock domain - note the two-stage synchronizer and that it supposed to work with any input active level (high or low)
always_ff @(negedge arst_n_i, posedge clk_i) begin
  if (arst_n_i != 1'b1) begin // Asynchronous reset - just pass through the input (bypass the debounce logic)
    deb_sync_0 <= 1'b0; // First stage of synchronization - assign '0' on reset and ...
    deb_sync_1 <= 1'b1; // ... for the second stage of synchronization - assign '1' on reset. Thus ensuring that, no matter the debouncer config, the two stages are different after reset, so that the counter logic will start working properly.
    deb_o <= DEBOUNCE_INIT; // But, for the output - initialize it to the specified initial value. This will ensure known (idle) state after reset, but also that, no matter what the initial value (type of polarity) is configured for the debouncer, and what the actual input value is actually incomming, ...
    deb_counter <= '0; // ... its counter will always start from 0 and be counting the same ways, for the different configurations. So, after reset, the debouncer shall start outputting its preset initial value and it will hold it, till the time delay have passed - in order to change the output state.
  end else begin
    deb_sync_0 <= din_i; // First stage of synchronization
    deb_sync_1 <= deb_sync_0; // Second stage of synchronization
    if(deb_sync_1 != deb_sync_0) begin // if input changed, reset the counter
      deb_counter <= '0; // Reset the counter
    end else begin // Input is stable - increment the counter and/or update the debounced output 
      if(deb_counter == DEBOUNCE_CYCLES - 2) begin // Debounce time has elapsed. Note: -2 because of the two-stage synchronizer delay one clock cycle is already counted (witdrawn).
        deb_o <= deb_sync_1; // Update the debounced output
      end else begin
        deb_counter <= deb_counter + 1'b1; // Increment the counter. 
      end
    end
  end
end

endmodule