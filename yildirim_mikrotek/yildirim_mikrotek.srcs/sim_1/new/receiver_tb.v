`timescale 1ns / 1ps

module receiver_tb;

   // Declare signals
   reg clk_i;
   reg rst_i;
   reg rx_i;
   reg rx_en_i;
   reg [15:0] baud_div_i;
   wire [7:0] r_out_o;
   wire r_done_o;

   // Instantiate the receiver module
   receiver dut (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .rx_i(rx_i),
      .baud_div_i(baud_div_i),
      .r_out_o(r_out_o),
      .r_done_o(r_done_o),
      .rx_en_i(rx_en_i)
   );

   // Clock generation
   always #5 clk_i = ~clk_i;

   // Initial values
   initial begin
      clk_i = 0;
      rst_i = 1;
      rx_i = 1; // Initialize rx_i to high
      rx_en_i = 0; // Disable receiver initially
      baud_div_i = 16'hFFFF; // Set baud_div_i to maximum value initially
      #10; // Wait for a few clock cycles

      // Reset
      rst_i = 0;
      #10;
      rst_i = 1;
   end

   // Stimulus
   initial begin
      // Test case 1: Enable receiver and send a byte
      rx_en_i = 1; // Enable receiver
      baud_div_i = 16'h0100; // Set baud_div_i to a different value
      #200; // Wait for receiver to process data

      // Test case 2: Disable receiver
      rx_en_i = 0; // Disable receiver
      #200; // Wait for a few clock cycles

      // Add more test cases as needed
   end

   // Monitor
   always @(posedge clk_i) begin
      $display("At time %t, r_out_o = %d, r_done_o = %b", $time, r_out_o, r_done_o);
   end

   // Monitor state machine steps
   always @(posedge clk_i) begin
      $display("At time %t, State: %b", $time, dut.state);
   end

endmodule
