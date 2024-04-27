`timescale 1ns / 1ps

//Bazi durumlarda sonuc x donuyor

module tb_bolme_birimi();

	reg        clk_i=1;
	reg        rst_i=0;
	
	reg        start_i=1;
	reg [1:0]  islem_i;
	reg [31:0] bolen_i;
	reg [31:0] bolunen_i;

	wire [31:0] result_o;
	wire bitti_o;

	// Instantiate the Unit Under Test (UUT)
	bolme_birimi bbt (
	    .clk_i(clk_i),
	    .rst_i(rst_i),
	    
	    .start_i(start_i),
	    .islem_i(islem_i),
       	    .bolunen_i(bolunen_i),
	    .bolen_i(bolen_i),
		 
	    .result_o(result_o),
	    .bitti_o(bitti_o)
	);
	
      always begin
      clk_i=~clk_i;
      #1;
      end
      
	initial begin
	    
	    start_i=1;
	    rst_i=0;
	    
	    //DIVU
	    bolunen_i = 32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b00;
	    #66;
	    if(result_o==32'd4) $display("passed"); else $display("FAILED!: %d",result_o);#1;
	
	    bolunen_i = 32'd9; 
	    bolen_i =   32'd41;
 	    islem_i =   2'b00;
	    #70;
	    if(result_o==32'd0) $display("passed"); else $display("FAILED!: %d",result_o);
	    
	    bolunen_i =-32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b00;
	    #70;
	    if(result_o==32'd477218583) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd41; 
	    bolen_i =  -32'd9;
 	    islem_i =   2'b00;
	    #70;
            if(result_o==32'd0) $display("passed"); else $display("FAILED!: %d",result_o);
        
            bolunen_i = 32'd41; 
	    bolen_i =   32'd0;
 	    islem_i =   2'b00;
	    #70;
            if(result_o==32'd0) $display("passed"); else $display("FAILED!: %d",result_o);
  
            //DIV
            bolunen_i = 32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b10;
	    #70;
	    if(result_o==32'd4) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd9; 
	    bolen_i =   32'd41;
 	    islem_i =   2'b10;
	    #70;
	    if(result_o==32'd0) $display("passed"); else $display("FAILED!: %d",result_o);
	    
	    bolunen_i =-32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b10;
	    #70;
	    if(result_o==-32'd4) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd41; 
	    bolen_i =  -32'd9;
 	    islem_i =   2'b10;
	    #70;
            if(result_o==-32'd4) $display("passed"); else $display("FAILED!: %d",result_o);
        
            bolunen_i = 32'd41; 
	    bolen_i =   32'd0;
 	    islem_i =   2'b00;
	    #70;
            if(result_o==32'd0) $display("passed"); else $display("FAILED!: %d",result_o);
        
            //REMU
            bolunen_i = 32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b01;
	    #70;
	    if(result_o== 32'd5) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd9; 
	    bolen_i =   32'd41;
 	    islem_i =   2'b01;
	    #70;
	    if(result_o== 32'd9) $display("passed"); else $display("FAILED!: %d",result_o);
	   
	    bolunen_i =-32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b01;
	    #70;
	    if(result_o== 32'd8) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd41; 
	    bolen_i =   -32'd9;
 	    islem_i =   2'b01;
	    #70;
            if(result_o== 32'd0) $display("passed"); else $display("FAILED!: %d",result_o);
        
            bolunen_i = 32'd41; 
	    bolen_i =   32'd0;
 	    islem_i =   2'b00;
	    #70;
            if(result_o== -32'd1) $display("passed"); else $display("FAILED!: %d",result_o);
        
       	    //REM
            bolunen_i = 32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b11;
	    #70;
	    if(result_o== 32'd5) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd9; 
	    bolen_i =   32'd41;
 	    islem_i =   2'b11;
	    #70;
	    if(result_o== 32'd9) $display("passed"); else $display("FAILED!: %d",result_o);
	    
	    bolunen_i =-32'd41; 
	    bolen_i =   32'd9;
 	    islem_i =   2'b11;
	    #70;
	    if(result_o== -32'd5) $display("passed"); else $display("FAILED!: %d",result_o);
		
	    bolunen_i = 32'd41; 
	    bolen_i =  -32'd9;
 	    islem_i =   2'b11;
	    #70;
            if(result_o== 32'd5) $display("passed"); else $display("FAILED!: %d",result_o);
        
            bolunen_i = 32'd41; 
	    bolen_i =   32'd0;
 	    islem_i =   2'b00;
	    #70;
            if(result_o== -32'd1) $display("passed"); else $display("FAILED!: %d",result_o);
        
	end
      
	
endmodule