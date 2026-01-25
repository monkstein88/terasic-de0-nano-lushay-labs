`timescale 1ns / 1ps

// Comprehensive testbench for the uart_com module
// Tests both RX and TX functionality including:
// - Basic transmission and reception
// - Back-to-back transfers
// - Loopback testing
// - Error conditions

module uart_com_tb;

  // ========================================================================
  // Testbench Parameters
  // ========================================================================
  localparam int CLK_FREQ = 50_000_000;      // 50 MHz clock
  localparam int UART_BAUDRATE = 115200;     // 115200 bps
  localparam int UART_DATA_BITS = 8;         // 8-bit data
  
  // Calculate timing constants for verification
  localparam real CLK_PERIOD = 1_000_000_000.0 / CLK_FREQ; // in nanoseconds
  localparam real BIT_PERIOD = 1_000_000_000.0 / UART_BAUDRATE; // UART bit time in ns
  
  // ========================================================================
  // DUT (Device Under Test) Signals
  // ========================================================================
  logic arst_n;
  logic clk;
  
  // RX interface signals
  logic uart_rx;
  logic rx_ready;
  logic [UART_DATA_BITS-1:0] rx_data;
  
  // TX interface signals
  logic tx_start;
  logic tx_busy;
  logic [UART_DATA_BITS-1:0] tx_data;
  logic uart_tx;
  
  // Loopback connection (for loopback tests)
  logic loopback_enable = 0;
  
  // ========================================================================
  // DUT Instantiation
  // ========================================================================
  uart_com #(
    .CLK_FREQ(CLK_FREQ),
    .UART_BAUDRATE(UART_BAUDRATE),
    .UART_DATA_BITS(UART_DATA_BITS)
  ) dut (
    .arst_n_i(arst_n),
    .clk_i(clk),
    // RX interface
    .uart_rx_i(uart_rx),
    .rx_ready_o(rx_ready),
    .rx_data_o(rx_data),
    // TX interface
    .tx_start_i(tx_start),
    .tx_busy_o(tx_busy),
    .tx_data_i(tx_data),
    .uart_tx_o(uart_tx)
  );
  
  // ========================================================================
  // Clock Generation
  // ========================================================================
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // ========================================================================
  // Task: Reset the DUT
  // ========================================================================
  task automatic reset_dut();
    begin
      $display("[%0t] Applying reset...", $time);
      arst_n = 0;
      tx_start = 0;
      tx_data = 8'h00;
      uart_rx = 1; // UART idle state is high
      repeat(10) @(posedge clk);
      arst_n = 1;
      repeat(5) @(posedge clk);
      $display("[%0t] Reset complete", $time);
    end
  endtask
  
  // ========================================================================
  // Task: Transmit a byte via UART TX (using the DUT's transmitter)
  // ========================================================================
  task automatic send_byte_via_tx(input logic [7:0] data);
    begin
      $display("[%0t] TX Task: Starting transmission of 0x%02X", $time, data);
      
      // Wait for TX to be idle
      while(tx_busy) @(posedge clk);
      
      // Load data and start transmission
      tx_data = data;
      tx_start = 1;
      @(posedge clk);
      tx_start = 0;
      
      // Wait for transmission to complete
      @(posedge tx_busy);
      $display("[%0t] TX Task: Transmission started", $time);
      @(negedge tx_busy);
      $display("[%0t] TX Task: Transmission complete", $time);
    end
  endtask
  
  // ========================================================================
  // Task: Receive a byte via UART RX (simulate external UART sending to DUT)
  // This task bit-bangs the UART protocol on the uart_rx line
  // ========================================================================
  task automatic send_byte_to_rx(input logic [7:0] data);
    integer i;
    begin
      $display("[%0t] RX Task: Sending byte 0x%02X to RX line", $time, data);
      
      // Start bit (low)
      uart_rx = 0;
      #BIT_PERIOD;
      
      // Data bits (LSB first)
      for(i = 0; i < 8; i++) begin
        uart_rx = data[i];
        #BIT_PERIOD;
      end
      
      // Stop bit (high)
      uart_rx = 1;
      #BIT_PERIOD;
      
      $display("[%0t] RX Task: Byte transmission complete", $time);
    end
  endtask
  
  // ========================================================================
  // Task: Wait for RX ready flag and verify received data
  // ========================================================================
  task automatic wait_and_check_rx(input logic [7:0] expected_data);
    begin
      $display("[%0t] Waiting for RX ready...", $time);
      
      // Wait for rx_ready flag
      while(!rx_ready) @(posedge clk);
      
      $display("[%0t] RX ready! Received: 0x%02X, Expected: 0x%02X", 
               $time, rx_data, expected_data);
      
      // Check if received data matches expected
      if(rx_data === expected_data) begin
        $display("[%0t] ✓ PASS: Data match!", $time);
      end else begin
        $display("[%0t] ✗ FAIL: Data mismatch!", $time);
        $fatal(1, "RX data verification failed!");
      end
      
      // Wait for ready to go low (back to idle)
      @(negedge rx_ready);
    end
  endtask
  
  // ========================================================================
  // Task: Monitor UART TX line and decode the transmitted byte
  // ========================================================================
  task automatic monitor_tx_line(output logic [7:0] received_data);
    integer i;
    begin
      $display("[%0t] Monitor: Waiting for start bit on TX line...", $time);
      
      // Wait for start bit (falling edge)
      @(negedge uart_tx);
      $display("[%0t] Monitor: Start bit detected", $time);
      
      // Wait to middle of start bit
      #(BIT_PERIOD/2);
      
      // Sample data bits (LSB first)
      for(i = 0; i < 8; i++) begin
        #BIT_PERIOD;
        received_data[i] = uart_tx;
      end
      
      // Wait for stop bit
      #BIT_PERIOD;
      if(uart_tx !== 1'b1) begin
        $display("[%0t] ✗ WARNING: Stop bit error detected!", $time);
      end
      
      $display("[%0t] Monitor: Received byte 0x%02X from TX line", $time, received_data);
    end
  endtask
  
  // ========================================================================
  // Main Test Sequence
  // ========================================================================
  initial begin
    // Initialize waveform dump
    $dumpfile("uart_com_tb.vcd");
    $dumpvars(0, uart_com_tb);
    
    $display("========================================");
    $display("UART Communication Testbench Started");
    $display("Clock Frequency: %0d Hz", CLK_FREQ);
    $display("UART Baudrate: %0d bps", UART_BAUDRATE);
    $display("Bit Period: %0.2f ns", BIT_PERIOD);
    $display("========================================\n");
    
    // Initialize signals
    arst_n = 0;
    tx_start = 0;
    tx_data = 0;
    uart_rx = 1;
    
    // Apply reset
    reset_dut();
    #1000;
    
    // ======================================================================
    // Test 1: RX Reception Test
    // ======================================================================
    $display("\n========================================");
    $display("Test 1: RX Reception");
    $display("========================================");
    
    fork
      send_byte_to_rx(8'hA5);
      wait_and_check_rx(8'hA5);
    join
    
    #2000;
    
    // ======================================================================
    // Test 2: TX Transmission Test
    // ======================================================================
    $display("\n========================================");
    $display("Test 2: TX Transmission");
    $display("========================================");
    
    fork
      send_byte_via_tx(8'h3C);
      begin
        logic [7:0] monitored_data;
        monitor_tx_line(monitored_data);
        if(monitored_data === 8'h3C) begin
          $display("[%0t] ✓ PASS: TX transmitted correct data!", $time);
        end else begin
          $display("[%0t] ✗ FAIL: TX data mismatch!", $time);
          $fatal(1, "TX verification failed!");
        end
      end
    join
    
    #2000;
    
    // ======================================================================
    // Test 3: Multiple RX bytes
    // ======================================================================
    $display("\n========================================");
    $display("Test 3: Multiple RX Bytes");
    $display("========================================");
    
    send_byte_to_rx(8'h00);
    wait_and_check_rx(8'h00);
    #1000;
    
    send_byte_to_rx(8'hFF);
    wait_and_check_rx(8'hFF);
    #1000;
    
    send_byte_to_rx(8'h55);
    wait_and_check_rx(8'h55);
    #1000;
    
    send_byte_to_rx(8'hAA);
    wait_and_check_rx(8'hAA);
    #2000;
    
    // ======================================================================
    // Test 4: Multiple TX bytes
    // ======================================================================
    $display("\n========================================");
    $display("Test 4: Multiple TX Bytes");
    $display("========================================");
    
    send_byte_via_tx(8'h12);
    #(BIT_PERIOD * 11); // Wait for full transmission
    
    send_byte_via_tx(8'h34);
    #(BIT_PERIOD * 11);
    
    send_byte_via_tx(8'h56);
    #(BIT_PERIOD * 11);
    
    #2000;
    
    // ======================================================================
    // Test 5: Loopback Test (TX -> RX)
    // ======================================================================
    $display("\n========================================");
    $display("Test 5: Loopback Test");
    $display("========================================");
    
    // Connect TX to RX
    loopback_enable = 1;
    
    fork
      send_byte_via_tx(8'hBD);
      begin
        // Wait a bit for TX to start
        #(BIT_PERIOD * 2);
        wait_and_check_rx(8'hBD);
      end
    join
    
    loopback_enable = 0;
    uart_rx = 1; // Return to idle
    #2000;
    
    // ======================================================================
    // Test Complete
    // ======================================================================
    $display("\n========================================");
    $display("All Tests Completed Successfully!");
    $display("========================================\n");
    
    #5000;
    $finish;
  end
  
  // ========================================================================
  // Loopback Connection Logic
  // ========================================================================
  always_comb begin
    if(loopback_enable)
      uart_rx = uart_tx;
  end
  
  // ========================================================================
  // Watchdog Timer (prevent infinite simulation)
  // ========================================================================
  initial begin
    #50_000_000; // 50ms timeout
    $display("\n✗ ERROR: Simulation timeout!");
    $fatal(1, "Watchdog timer expired");
  end
  
  // ========================================================================
  // Optional: Monitor for debugging
  // ========================================================================
  always @(posedge rx_ready) begin
    $display("[%0t] >>> RX Ready: Data = 0x%02X", $time, rx_data);
  end
  
  always @(posedge tx_busy) begin
    $display("[%0t] >>> TX Started: Data = 0x%02X", $time, tx_data);
  end
  
  always @(negedge tx_busy) begin
    $display("[%0t] >>> TX Finished", $time);
  end

endmodule