module cp0_regfile(
    input                   clk             ,
    input                   reset           ,
    // cp0 write data
    input [31: 0]           cp0_wdata       ,
    input                   mtc0_we         ,
    input  [ 4: 0]          cp0_waddr       ,
    input                   eret_flush      ,
    input                   wb_bd           ,
    input  [ 5: 0]          ext_int_in      ,
    input  [ 4: 0]          wb_excode       ,
    input  [31: 0]          wb_pc           ,
    input                   wb_ex           ,

    output [31: 0]          cp0_status_reg  ,
    output [31: 0]          cp0_cause_reg   ,
    output [31: 0]          cp0_epc_reg     

);

wire                   cp0_status_bev       ;
reg [ 7: 0]            cp0_status_im        ;
reg                    cp0_status_exl       ;
reg                    cp0_status_ie        ;
wire                   count_eq_compare     ;

//temperorily set count_eq_compare as 0
assign count_eq_compare = 1'b0              ;

assign cp0_status_bev = 1'b1;

always@(posedge clk) begin
    if(reset)
        cp0_status_im <= 8'b0;
    else if(mtc0_we && cp0_waddr == 5'b01100) 
        cp0_status_im <= cp0_wdata[15: 8];
end 

always@(posedge clk) begin
    if(reset)
        cp0_status_exl <= 1'b0;
    else if(wb_ex)
        cp0_status_exl <= 1'b1;
    else if(eret_flush)
        cp0_status_exl <= 1'b0;
    else if(mtc0_we && cp0_waddr == 5'b01100)
        cp0_status_exl <= cp0_wdata[1];
end

always@(posedge clk) begin
    if(reset)
        cp0_status_ie <= 1'b0;
    else if(mtc0_we && cp0_waddr == 5'b01100)
        cp0_status_ie <= cp0_wdata[0];
end

assign cp0_status_reg = {
                          9'd0              ,      // 31:23      
                          cp0_status_bev    ,      // 22
                          6'd0              ,      // 21:16
                          cp0_status_im     ,      // 15:8
                          6'd0              ,      // 7: 2
                          cp0_status_exl    ,      // 1
                          cp0_status_ie            // 0
                        };


reg             cp0_cause_bd                ;   
reg             cp0_cause_ti                ;
reg [7 :0]      cp0_cause_ip                ;
reg [4 :0]      cp0_cause_excode            ;


always@(posedge clk) begin
    if(reset)
        cp0_cause_bd <= 1'b0;
    else if(wb_ex && !cp0_status_exl)
        cp0_cause_bd <= wb_bd;
end

always@(posedge clk) begin
    if(reset)
        cp0_cause_ti <= 1'b0;
    else if(mtc0_we && cp0_waddr == 5'b01011)
        cp0_cause_ti <= 1'b0;
    else if(count_eq_compare)
        cp0_cause_ti <= 1'b1;
end

always@(posedge clk) begin
    if(reset)
        cp0_cause_ip[7: 2] <= 6'b0;
    else begin
        cp0_cause_ip [7]    <= ext_int_in[5] | cp0_cause_ti;
        cp0_cause_ip [6: 2] <= ext_int_in[4: 0];
    end
end

always@(posedge clk) begin
    if(reset)
        cp0_cause_ip[1 :0] <= 2'b0;
    else if(mtc0_we && cp0_waddr == 5'b01101)
        cp0_cause_ip[1: 0] <= cp0_wdata[9: 8];
end

always@(posedge clk) begin
    if(reset)
        cp0_cause_excode <= 5'b0;
    else if(wb_ex)
        cp0_cause_excode <= wb_excode;
end

assign cp0_cause_reg = {
                        cp0_cause_bd            ,   // 31
                        cp0_cause_ti            ,   // 30
                        14'd0                   ,   // 29:16
                        cp0_cause_ip            ,   // 15: 8
                        1'd0                    ,  // 7
                        cp0_cause_excode        , // 6: 2
                        2'd0
                        };

reg [31: 0]             cp0_epc;

always@(posedge clk) begin
    if(wb_ex && !cp0_status_exl)
        cp0_epc <= wb_bd ? wb_pc - 3'h4 : wb_pc;
    else if(mtc0_we && cp0_waddr == 5'b01110)
        cp0_epc <= cp0_wdata;
end
assign cp0_epc_reg = cp0_epc;
endmodule
