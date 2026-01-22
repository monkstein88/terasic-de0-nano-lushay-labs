// This is a simple UART RX/TX module - it can receive and transmit data over UART 8-N-1 protocol - no handshaking (no flow control), 1 start bit, 8 data bits, no parity, 1 stop bit, full-duplex 
// (rx and tx parts are independent)
module uart_com #(
  parameter CLK_FREQ = 50_000_000, // The provided xernal Clock Source's frequency, in [Hz]
  parameter UART_BAUDRATE = 115200, // UART Baudrate, in [bps]
  parameter UART_DATA_BITS = 8 // Number of data bits in the UART frame
)(
  input  wire arst_n_i,  // Asynchronous reset (active low)
  input  wire clk_i,     // Clock input
  // UART RX interface:
  input  wire uart_rx_i, // UART receive (RX) signal - pin connected to the RX line
  output logic rx_ready_o, // Received data ready flag
  output logic [UART_DATA_BITS-1:0] rx_data_o, // Received data byte output
  // UART TX interface:
  input  wire tx_start_i, // Transmit start signal
  output logic tx_busy_o, // Transmit busy flag
  input  wire [UART_DATA_BITS-1:0] tx_data_i, // Data byte to transmit
  output logic uart_tx_o // UART transmit (TX) signal - pin connected to the TX line
);
// Calculate bit time parameters:
localparam  UART_BIT_TIME = (CLK_FREQ / UART_BAUDRATE) ;
localparam  UART_HALF_BIT_TIME = ((CLK_FREQ / UART_BAUDRATE) / 2) ;

// ==== This section will take care of the RX part of the UART communication ====
byte unsigned rx_bit_counter = 0;
logic [UART_DATA_BITS-1:0] rx_data_buf = '0; 
shortint unsigned rx_clk_counter = 0;
enum logic [2:0] {UART_RX_STATE_IDLE, UART_RX_STATE_START_BIT, UART_RX_STATE_WAIT, UART_RX_STATE_READ_BIT, UART_RX_STATE_STOP_BIT } uart_rx_fsm = UART_RX_STATE_IDLE;
// Note: In UART the receiving is as follows:  START-BIT => DATA (LSb -> MSb) => STOP-BIT
always_ff @(negedge arst_n_i, posedge clk_i) begin
  if(arst_n_i != 1'b1) begin // Asyncrhonous part - reset  
    rx_ready_o <= 1'b0;
    rx_data_o <= '0;
    uart_rx_fsm <= UART_RX_STATE_IDLE;
    // Optional: clear internal counters/buffers
    rx_clk_counter <= 0;
    rx_bit_counter <= 0;
    rx_data_buf <= '0;
  end else begin // Syncrhonous part - fsm processing
    case(uart_rx_fsm)
      UART_RX_STATE_IDLE: begin 
        rx_ready_o <= 1'b0; // Clear the data ready flag immediately when in IDLE state
        if(uart_rx_i == 1'b0) begin // Start bit detected (line went low) - go to START_BIT state
          rx_clk_counter = 0;
          uart_rx_fsm <= UART_RX_STATE_START_BIT;
        end
      end 
      UART_RX_STATE_START_BIT: begin 
        if(rx_clk_counter == UART_HALF_BIT_TIME - 1) begin // wait for half bit time, in the middle of the start bit
          rx_clk_counter <= 0; 
          rx_bit_counter <= 0;
          uart_rx_fsm <= UART_RX_STATE_WAIT;
        end else begin 
          rx_clk_counter++;
        end
      end
      UART_RX_STATE_WAIT: begin 
        if(rx_clk_counter == UART_BIT_TIME - 1) begin // wait for full bit time, then ... 
          rx_clk_counter <= 0;
          uart_rx_fsm <= UART_RX_STATE_READ_BIT;
        end else begin 
          rx_clk_counter++;
        end
      end
      UART_RX_STATE_READ_BIT: begin
        rx_data_buf[rx_bit_counter] <= uart_rx_i; // ... Sample the data bit (LSb -> MSb)
        if(rx_bit_counter == UART_DATA_BITS - 1) begin
          rx_bit_counter++; 
          uart_rx_fsm <= UART_RX_STATE_WAIT;
        end else begin
          uart_rx_fsm <= UART_RX_STATE_STOP_BIT;
        end
      end
      UART_RX_STATE_STOP_BIT:  begin 
        if(rx_clk_counter == UART_BIT_TIME - 1) begin 
          rx_data_o <= rx_data_buf;
          rx_ready_o <= 1'b1; // Indicate that new data is ready, after the full byte has been received. Note: this flag will be cleared when going back to IDLE state
          uart_rx_fsm <= UART_RX_STATE_IDLE;
        end else begin 
          rx_clk_counter++;
        end 
      end
      default: uart_rx_fsm <= UART_RX_STATE_IDLE; // Safety/default case: go to IDLE state
    endcase
  end
end

// ==== This section will take care of the TX part of the UART communication ====
byte unsigned tx_bit_counter = 0;
logic [UART_DATA_BITS-1:0] tx_data_buf = '0; 
shortint unsigned tx_clk_counter = 0;
enum logic [2:0] {UART_TX_STATE_IDLE, UART_TX_STATE_START_BIT, UART_TX_STATE_WRITE_BIT, UART_TX_STATE_STOP_BIT, UART_TX_STATE_DONE } uart_tx_fsm = UART_TX_STATE_IDLE;
// Note: In UART the transmission is as follows:  START-BIT => DATA (LSb -> MSb) => STOP-BIT
always_ff @(negedge arst_n_i, posedge clk_i) begin 
  if(arst_n_i != 1'b1) begin // Asyncrhonous part - reset  
    tx_busy_o <= 1'b0;
    uart_tx_o <= 1'b1; // Idle state of UART TX line is high
    uart_tx_fsm <= UART_TX_STATE_IDLE;
    // Optional: clear internal counters/buffers
    tx_clk_counter <= 0;
    tx_bit_counter <= 0;
    tx_data_buf = '0; 
  end else begin // Syncrhonous part - fsm processing
    case(uart_tx_fsm) 
      UART_TX_STATE_IDLE: begin 
        uart_tx_o <= 1'b1; // Idle state of UART TX line is high
        tx_busy_o <= 1'b0;
        if(tx_start_i == 1'b1)begin
          tx_clk_counter <= 0; 
          tx_data_buf <= tx_data_i;
          tx_busy_o <= 1'b1;
          uart_tx_fsm <= UART_TX_STATE_START_BIT;
        end
      end
      UART_TX_STATE_START_BIT: begin 
        uart_tx_o <= 1'b0; // Keep line low during Start bit
        if(tx_clk_counter == UART_BIT_TIME) begin
          tx_clk_counter <= 0;
          tx_bit_counter <= 0;
          uart_tx_fsm <= UART_TX_STATE_WRITE_BIT;
        end else begin
          tx_clk_counter++;
        end
      end
      UART_TX_STATE_WRITE_BIT: begin 
        uart_tx_o <= tx_data_buf[tx_bit_counter]; // Start shifting out the data bits (LSb -> MSB)
        if(tx_clk_counter == UART_BIT_TIME) begin 
          tx_clk_counter <= 0;
          if(tx_bit_counter == UART_DATA_BITS - 1) begin 
            uart_tx_fsm <= UART_TX_STATE_STOP_BIT;
          end else begin 
            tx_bit_counter++;
          end
        end else begin 
          tx_clk_counter++;
        end
      end
      UART_TX_STATE_STOP_BIT: begin 
        uart_tx_o <= 1'b1; // Stop bit must be high
        if(tx_clk_counter == UART_BIT_TIME) begin 
          tx_busy_o <= 1'b0; 
          uart_tx_fsm <= UART_TX_STATE_DONE;
        end else begin 
          tx_clk_counter++;
        end
      end
      UART_TX_STATE_DONE: begin 
        uart_tx_fsm <= UART_TX_STATE_IDLE;
      end
      default: uart_tx_fsm <= UART_TX_STATE_IDLE;
    endcase
  end
end
endmodule