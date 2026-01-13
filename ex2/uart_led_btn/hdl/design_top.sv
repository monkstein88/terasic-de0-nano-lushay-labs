module design_top #(
  parameter EXT_CLK_FREQ_HZ = 50_000_000, // External Clock Source's frequency, in [Hz]
  parameter EXT_CLK_PERIOD_NS = 20, // External Clock Source's period, in [ns]
  parameter LEDG_WIDTH = 8,  // The number of (green) LEDs on the board 
  parameter KEY_WIDTH = 2,   // The number of buttons on the board
  parameter UART_BAUDRATE_BPS = 115200 // UART Baudrate, in [bps]
)(
  input  wire                   EXTCLK_i,  // External Clock Source
  input  wire  [KEY_WIDTH-1:0]  KEY_n_i,   // Buttons (active low) : KEY[0] is reset button, KEY[1] is user button
  input  wire                   UART_RX_i, // UART receive (RX)
  output logic                  UART_TX_o, // UART transmit (TX)
  output logic [LEDG_WIDTH-1:0] LEDG_o     // (green) LEDs (active high)
);

// Internal (helper) signals:
wire arst_n; // Asynchronous reset (active low) - synchronized (filtered) version of the reset button input
wire btn_n; // Debounced User button (active low) - this will be used to control the UART transmission, sending an ASCII character when pressed

logic uart_rx_ready = 1'b0; // UART received data ready flag
logic [7:0] uart_rx_data = '0; // Buffer to hold the received UART data
logic uart_tx_busy = 1'b0; // UART transmit busy flag
logic uart_tx_start = 1'b0; // UART transmit start signal
logic [7:0] uart_tx_data = 8'h41; // Data to send via UART - default to ASCII character 'A' (0x41) and increment on each button press

// Instantiate the reset synchronization module:
reset_sync #(
  .RESET_POLARITY("LOW"), // Active low reset
  .SYNC_STAGES(2)
) reset_sync_inst (
  .async_rst_i(KEY_n_i[0]), // Pass the reset button input - KEY[0] and synchronize it
  .clk_i(EXTCLK_i),
  .synced_rst_o(arst_n) // "Synchronized" asynchronous reset output (active low)
);

// Instantiate the button debouncer module:
debounce #(
  .CLK_FREQ(EXT_CLK_FREQ_HZ),
  .DEBOUNCE_TIME_MS(10), // 10 [ms] debounce time
  .DEBOUNCE_INIT_VAL(1'b1) // Initial (Idle) value of the debounced output after reset - the button idles at high (not pressed)
) debounce_btn_inst (
  .arst_n_i(arst_n), // Asynchronous reset (active low)
  .clk_i(EXTCLK_i),
  .din_i(KEY_n_i[1]), // Pass the user button input - KEY[1]
  .deb_o(btn_n) // Debounced button output (active low)
);

// Instantiate the UART communication module:
uart_com #(
  .CLK_FREQ(EXT_CLK_FREQ_HZ),
  .UART_BAUDRATE(UART_BAUDRATE_BPS),
  .UART_DATA_BITS(8)
) uart_com_inst (
  .arst_n_i(arst_n),
  .clk_i(EXTCLK_i),
  .uart_rx_i(UART_RX_i),
  .rx_ready_o(uart_rx_ready), 
  .rx_data_o(uart_rx_data),  
  .tx_start_i(uart_tx_start), 
  .tx_busy_o(uart_tx_busy), 
  .tx_data_i(uart_tx_data), 
  .uart_tx_o(UART_TX_o)
);



endmodule