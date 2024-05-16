`timescale 1ns / 1ps

module tb_baud_rate_generator;

   // Declare signals
   reg clk_i;
   reg rst_i;
   wire tx_tick_o;
   reg [15:0] baud_div_i;
   reg [15:0] tx_counter; // Added tx_counter for monitoring

   // Instantiate the baud_rate_generator module
   baud_rate_generator dut (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .tx_tick_o(tx_tick_o),
      .baud_div_i(baud_div_i)
   );

   // Clock generation
   always #5 clk_i = ~clk_i;

   // Initial values
   initial begin
      clk_i = 0;
      rst_i = 1;
      baud_div_i = 16'hFFFF; // Set baud_div_i to maximum value initially
      #10; // Wait for a few clock cycles

      // Reset
      rst_i = 0;
      #10;
      rst_i = 1;
   end

   // Stimulus
   initial begin
      // Test case: Set baud_div_i to a value and adjust tx_counter to make tx_tick_o high
      #20;
      baud_div_i = 16'h0010; // Set baud_div_i to a small value

      // Adjust tx_counter to make tx_tick_o high
      tx_counter = baud_div_i / 2;
      #100;

      // Add more test cases as needed
   end

   // Monitor
   always @(posedge clk_i) begin
      $display("At time %t, tx_tick_o = %b, tx_counter = %d", $time, tx_tick_o, tx_counter);
   end

   // Monitor tx_counter
   always @(posedge clk_i) begin
      tx_counter <= dut.tx_counter; // Update tx_counter with the value from the DUT
   end

endmodule
