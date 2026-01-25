 /* This is a reset generation circuit - it provides asyncrhonously asserted, and  
  * and syncrhonously deasserted - reset signal, to any system flip flops that are 
  * asyncrhonously cleared or set in the FPGA. 
  *
  * Note: This circuit allows the Quartus II Application' TimeQuest analisys tool 
  * to accurately measure the recovery and removal timing to the sytem flops. 
  */
module reset_sync #(
  parameter logic RESET_POLARITY = 1'b0, // Reset polarity: "1'b1" for active high reset, "1'b0" for active low reset. Default is active low.
  parameter integer SYNC_STAGES = 2 // Number of synchronization stages. Expected values are 2 or more.
)(
  input  wire  async_rst_i,   // Asynchronous reset input
  input  wire  clk_i,         // Clock input
  output logic synced_rst_o   // Synchronized reset output
);

  
logic [0:SYNC_STAGES-1] sync_ff = (RESET_POLARITY == 1'b1)? '1 : (RESET_POLARITY == 1'b0)? '0 : 'x; // Synchronizer flip-flops. Note: Bit 0 is the last stage (MSb), Bit SYNC_STAGES-1 is the first stage (LSb). So no matter the number of stages, the last stage (synced) output is always sync_ff[0].

// Conditional hdl generation:
generate 
  if(RESET_POLARITY == "HIGH") begin : GEN_SYNC_ACTIVE_HIGH // If the reset is active-high
    always_ff @(posedge async_rst_i, posedge clk_i) begin 
      if(async_rst_i != 1'b0) begin  // Asynchronous part - assert reset
        sync_ff <= '1;
      end else begin // Synchronous part - shift in '0's - deasserting reset
        sync_ff <= {sync_ff[1:SYNC_STAGES-1], 1'b0}; // Shift left, inserting '0' at LSb
      end
    end
  end else if(RESET_POLARITY == "LOW") begin : GEN_SYNC_ACTIVE_LOW // If the reset is active-low  
    always_ff @(negedge async_rst_i, posedge clk_i) begin
      if(async_rst_i != 1'b1) begin // Asynchronous part - assert reset
        sync_ff <= '0; 
      end else begin // Synchronous part - shift in '1's - deasserting reset
        sync_ff <= {sync_ff[1:SYNC_STAGES-1], 1'b1}; // Shift left, inserting '1' at LSb
      end
    end
  end else begin : GEN_SYNC_DEFAULT // If the reset is not specified accordingly, indicate a fatal error! Also fall to default behaviour - just pass it through (directly) 
    //$fatal(1, "ERROR in 'reset_sync': Invalid RESET_POLARITY parameter value! Supported values are: 'HIGH' and 'LOW'.");
    assign sync_ff[0] = async_rst_i; // Directly pass through the async reset input to the output
  end
endgenerate 

assign synced_rst_o = sync_ff[0]; // Output the last stage of the synchronizer

endmodule 