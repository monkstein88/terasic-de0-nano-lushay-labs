module debounce #(
  parameter CLK_FREQ = 50_000_000, // Clock frequency in [Hz]
  parameter DEBOUNCE_TIME = 1,  // Debounce time in [ms]
  parameter DEBOUNCE_INIT = 1'b0 // Initial (Idle) value (also reset-polarity) of the debounced output after reset
)(
  input  wire  arst_n_i, // Asynchronous reset (active low)
  input  wire  clk_i,    // Clock input
  input  wire  din_i,    // Raw digital input - active level does not matter
  output logic deb_o     // Debounced digital input - active level does not matter
);

// Calculate the number of clock cycles for the debounce time
localparam DEBOUNCE_CYCLES = (CLK_FREQ / 1000) * DEBOUNCE_TIME;
localparam DEBOUNCE_WIDTH = $clog2(DEBOUNCE_CYCLES + 1);

// Internal signals
logic deb_sync_0;
logic deb_sync_1;  
logic [DEBOUNCE_WIDTH-1:0] deb_counter = '0;

// Synchronize the digital input to the clock domain - note the two-stage synchronizer and that it supposed to work with any input active level (high or low)
always_ff @(negedge arst_n_i, posedge clk_i) begin
  if (arst_n_i != 1'b1) begin // Asynchronous reset - just pass through the input (bypass the debounce logic)
    deb_sync_0 <= DEBOUNCE_INIT;
    deb_sync_1 <= DEBOUNCE_INIT;
    deb_o <= DEBOUNCE_INIT;
    deb_counter <= '0;
  end else begin
    deb_sync_0 <= din_i; // First stage of synchronization
    deb_sync_1 <= deb_sync_0; // Second stage of synchronization
    if(deb_sync_1 != deb_sync_0) begin // if input changed, reset the counter
      deb_counter <= '0; // Reset the counter
    end else begin // Input is stable - increment the counter and/or update the debounced output 
      if(deb_counter == DEBOUNCE_CYCLES - 2) begin // Debounce time has elapsed. Note: -2 because of the two-stage synchronizer delay one clock cycle is already counted (witdrawn).
        deb_o <= deb_sync_1; // Update the debounced output
      end else begin
        deb_counter <= deb_counter + 1'b1; // Increment the counter
      end
    end
  end
end


endmodule