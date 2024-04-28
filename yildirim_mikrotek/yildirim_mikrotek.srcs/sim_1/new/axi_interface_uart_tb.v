`timescale 1ns / 1ps

module tb_axi_interface_uart;
    parameter UART_BASE_ADDR = 32'h2000_0000;  // Ensure this matches the module definition

    reg s_axi_aclk_i;
    reg s_axi_aresetn_i;
    reg [31:0] s_axi_araddr_i;
    reg s_axi_arvalid_i;
    reg s_axi_rready_i;
    reg [31:0] s_axi_awaddr_i;
    reg s_axi_awvalid_i;
    reg [31:0] s_axi_wdata_i;
    reg [3:0] s_axi_wstrb_i;
    reg s_axi_wvalid_i;
    reg s_axi_bready_i;
    reg r_done_i;
    reg t_done_i;
    reg [7:0] rx_i;
    reg [3:0] read_size_i;

    wire s_axi_arready_o;
    wire s_axi_rvalid_o;
    wire [31:0] s_axi_rdata_o;
    wire s_axi_awready_o;
    wire s_axi_wready_o;
    wire s_axi_bvalid_o;
    wire rx_en_o;
    wire tx_en_o;
    wire [7:0] tx_o;
    wire [15:0] baud_div_o;

    // Instantiate the UART module
    axi_interface_uart DUT (
        .s_axi_aclk_i(s_axi_aclk_i), 
        .s_axi_aresetn_i(s_axi_aresetn_i),
        .s_axi_araddr_i(s_axi_araddr_i),  
        .s_axi_arready_o(s_axi_arready_o),  
        .s_axi_arvalid_i(s_axi_arvalid_i),     
        .s_axi_rready_i(s_axi_rready_i),
        .s_axi_rvalid_o(s_axi_rvalid_o), 
        .s_axi_rdata_o(s_axi_rdata_o), 
        .s_axi_awaddr_i(s_axi_awaddr_i),
        .s_axi_awready_o(s_axi_awready_o),
        .s_axi_awvalid_i(s_axi_awvalid_i),  
        .s_axi_wdata_i(s_axi_wdata_i),
        .s_axi_wready_o(s_axi_wready_o),
        .s_axi_wstrb_i(s_axi_wstrb_i),
        .s_axi_wvalid_i(s_axi_wvalid_i),     
        .s_axi_bready_i(s_axi_bready_i),
        .s_axi_bvalid_o(s_axi_bvalid_o),    
        .r_done_i(r_done_i),
        .t_done_i(t_done_i),
        .rx_i(rx_i),
        .rx_en_o(rx_en_o),
        .tx_en_o(tx_en_o),
        .tx_o(tx_o),
        .baud_div_o(baud_div_o),
        .read_size_i(read_size_i)
    );

    // Clock generation
    initial begin
        s_axi_aclk_i = 0;
        forever #5 s_axi_aclk_i = ~s_axi_aclk_i;  // 100MHz clock
    end

    // Reset process
    initial begin
        s_axi_aresetn_i = 0;
        #100;
        s_axi_aresetn_i = 1;
    end

    // Stimulus here
    initial begin
        // Initialize inputs
        s_axi_araddr_i = 0;
        s_axi_arvalid_i = 0;
        s_axi_rready_i = 0;
        s_axi_awaddr_i = 0;
        s_axi_awvalid_i = 0;
        s_axi_wdata_i = 0;
        s_axi_wstrb_i = 0;
        s_axi_wvalid_i = 0;
        s_axi_bready_i = 0;
        r_done_i = 0;
        t_done_i = 0;
        rx_i = 0;
        read_size_i = 0;

        // Test cases
        #200;  // Wait for reset to deassert
        // Example: Write and read back from UART control register
        s_axi_awaddr_i = UART_BASE_ADDR;
        s_axi_wdata_i = 32'h2000_0000;
        s_axi_wstrb_i = 4'b1111;  // Write all bytes
        s_axi_awvalid_i = 1;
        s_axi_wvalid_i = 1;
        s_axi_bready_i = 1;
        #10;
        s_axi_awvalid_i = 0;
        s_axi_wvalid_i = 0;
        s_axi_bready_i = 0;
        
         #10;
        s_axi_awvalid_i = 0;
        s_axi_wvalid_i = 0;
        s_axi_bready_i = 1;
        
         #10;
        s_axi_awvalid_i = 0;
        s_axi_wvalid_i = 1;
        s_axi_bready_i = 0;
        
         #10;
        s_axi_awvalid_i = 0;
        s_axi_wvalid_i = 1;
        s_axi_bready_i = 1;
        
         #10;
        s_axi_awvalid_i = 1;
        s_axi_wvalid_i = 0;
        s_axi_bready_i = 0;
        
         #10;
        s_axi_awvalid_i = 1;
        s_axi_wvalid_i = 0;
        s_axi_bready_i = 1;
        
         #10;
        s_axi_awvalid_i = 1;
        s_axi_wvalid_i = 1;
        s_axi_bready_i = 0;
        
         #10;
        s_axi_awvalid_i = 1;
        s_axi_wvalid_i = 1;
        s_axi_bready_i = 1;
         #10;
        s_axi_awvalid_i = 0;
        s_axi_wvalid_i = 0;
        s_axi_bready_i = 0;
        
        
        
        // More test cases can be added here to cover different scenarios
    end

endmodule
