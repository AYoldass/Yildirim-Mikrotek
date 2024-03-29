`timescale 1ns / 1ps

module tb_bit_manipulasyon_birimi_zbb;

    // Test mod�l� giri�leri
    reg clk_i;
    reg rst_i;
    reg din_valid_i;
    reg [31:0] din_value1_i;
    reg [31:0] din_value2_i;
    reg [31:0] din_instruction_i;
    
    // Test mod�l� ��k��lar�
    wire din_ready_o;
    wire din_decoded_o;
    wire dout_valid_o;
    wire [31:0] dout_result_o;
    
    // UUT (Under Test Unit) �rne�i
    bit_manipulasyon_birimi_zbb uut (
        .clk_i                  (clk_i                ),
        .rst_i                  (rst_i                ),
        .din_valid_i            (din_valid_i          ),
        .din_value1_i           (din_value1_i         ),
        .din_value2_i           (din_value2_i         ),
        .din_instruction_i      (din_instruction_i    ),
        .din_ready_o            (din_ready_o          ),
        .din_decoded_o          (din_decoded_o        ),
        .dout_valid_o           (dout_valid_o         ),
        .dout_result_o          (dout_result_o        )
    );
    
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i; 
    end
    
    initial begin
        $dumpfile("tb_bit_manipulasyon_birimi_zbb.vcd");
        $dumpvars(0, tb_bit_manipulasyon_birimi_zbb);
        
        
        rst_i = 1;
        #20; 
        rst_i = 0;
        
        // Test durumu 1: ANDN i�lemi
        // NOT: ��lem kodlar� ve beklenen sonu�lar �rnek olarak verilmi�tir, ger�ek de�erler i�levsellik testine g�re ayarlanmal�d�r.
        din_valid_i = 1;
        din_value1_i = 32'hA5A5A5A5;
        din_value2_i = 32'h5A5A5A5A;
        din_instruction_i = 32'h40007033; // ANDN i�lemi i�in �rnek bir i�lem kodu
        #10; // Biraz bekleyin
        din_valid_i = 0;
        
        // Test durumu 2: ORN i�lemi
        #20;
        din_valid_i = 1'b1;
        din_value1_i = 32'hFFFF0000;
        din_value2_i = 32'h0F0F0F0F;
        din_instruction_i = 32'h40006033; // ORN i�lemi i�in �rnek bir i�lem kodu
        #10;
        din_valid_i = 1'b0;
        
        // Test durumu 3: XNOR i�lemi
        #20;
        din_valid_i = 1'b1;
        din_value1_i = 32'hFF00FF00;
        din_value2_i = 32'h00FF00FF;
        din_instruction_i = 32'h40004033; // XNOR i�lemi i�in �rnek bir i�lem kodu
        #10;
        din_valid_i = 1'b0;
        
        // Test durumu 4: SLL (Sol Kayd�rma) i�lemi
        #20;
        din_valid_i = 1'b1;
        din_value1_i = 32'h000F000F;
        din_value2_i = 32'h4; // 4 bit sola kayd�r
        din_instruction_i = 32'h00001033; // SLL i�lemi i�in �rnek bir i�lem kodu
        #10;
        din_valid_i = 1'b0;
        
        // Test durumu 5: SRA (Aritmetik Sa�a Kayd�rma) i�lemi
        #20;
        din_valid_i = 1'b1;
        din_value1_i = 32'hF00FF00F;
        din_value2_i = 32'h4; // 4 bit sa�a kayd�r
        din_instruction_i = 32'h40005033; // SRA i�lemi i�in �rnek bir i�lem kodu
        #10;
        din_valid_i = 1'b0;
        
        // Test durumu 6: MIN i�lemi
        #20;
        din_valid_i = 1'b1;
        din_value1_i = 32'h12345678;
        din_value2_i = 32'h87654321;
        din_instruction_i = 32'h08000033; // MIN i�lemi i�in �rnek bir i�lem kodu
        #10;
        din_valid_i = 1'b0;

        
        #100; 
        $display("Test tamamland�.");
        $finish;
    end

endmodule
