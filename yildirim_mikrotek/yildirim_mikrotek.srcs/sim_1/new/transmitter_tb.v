`timescale 1ns / 1ps

module tb_transmitter;

   // Declare signals
   reg clk_i;
   reg tx_tick_i;
   reg rst_i;
   reg [7:0] t_in_i;
   reg tx_en_i;
   wire tx_o;
   wire t_done_o;

   // Instantiate the transmitter module
   transmitter dut (
      .clk_i(clk_i),
      .tx_tick_i(tx_tick_i),
      .rst_i(rst_i),
      .t_in_i(t_in_i),
      .tx_en_i(tx_en_i),
      .tx_o(tx_o),
      .t_done_o(t_done_o)
   );

   // Clock generation
   always #5 clk_i = ~clk_i;

   // Initial values
   initial begin
      clk_i = 0;
      tx_tick_i = 0;
      rst_i = 1;
      t_in_i = 8'd65; // Initial value for t_in_i
      tx_en_i = 0; // Disable transmitter initially
      #10; // Wait for a few clock cycles

      // Reset
      rst_i = 0;
      #10;
      rst_i = 1;
   end

   // Stimulus
   always @ (posedge clk_i) begin
      // Toggle tx_tick_i every clock cycle
      tx_tick_i <= ~tx_tick_i;

      // Enable transmitter every 100 clock cycles
      if ($time % 100 == 0) begin
         tx_en_i <= 1;
      end else begin
         tx_en_i <= 0;
      end
   end

   // Monitor
   always @(posedge clk_i) begin
      $display("At time %t, tx_o = %b, t_done_o = %b", $time, tx_o, t_done_o);
   end

endmodule
