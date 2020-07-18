module cp0_regfile(
    input                   clk             ,
    input                   reset           ,
    // cp0 write data
    input [31: 0]           cp0_wdata       ,
    input                   mtc0_we         ,
    input  [ 7: 0]          cp0_waddr       ,
    input                   eret_flush      ,
    input                   wb_bd           ,
    input  [ 5: 0]          ext_int_in      ,
    input  [ 4: 0]          wb_excode       ,
    input  [31: 0]          wb_pc           ,
    input                   wb_ex           ,
    input  [31: 0]          wb_badvaddr     ,
    input                   ws_valid        ,

    // show the instruction 
    input                   inst_tlbp       ,
    input                   inst_tlbr       ,
    // if found in s1 search port:
    input  [ 3: 0]          cp0_windex      ,
    input                   tlbp_found      ,

    // read port, it needs to write into entrylo0 and entrylo1
    input  [18:0]           r_vpn2          ,
    input  [ 7:0]           r_asid          ,
    input                   r_g             ,
    input  [19:0]           r_pfn0          ,
    input  [ 2:0]           r_c0            ,
    input                   r_d0            ,
    input                   r_v0            ,
    input  [19:0]           r_pfn1          ,
    input  [ 2:0]           r_c1            ,
    input                   r_d1            ,
    input                   r_v1            ,
    input                   refetch         ,
    input                   refetch_pc      ,


    output [31: 0]          cp0_status_reg  ,
    output [31: 0]          cp0_cause_reg   ,
    output [31: 0]          cp0_epc_reg     ,
    output [31: 0]          cp0_badvaddr_reg,
    output [31: 0]          cp0_count_reg   ,
    output [31: 0]          cp0_compare_reg ,
    output                  o_count_eq_compare,
    output                  cp0_status_ie_reg,
    output                  cp0_status_exl_reg,
    output [31: 0]          cp0_entryhi_reg  ,
    output [31: 0]          cp0_entrylo0_reg ,
    output [31: 0]          cp0_entrylo1_reg ,
    output [7: 0]           int_req          ,
    output [31:0]           cp0_index_reg 

);

wire                   cp0_status_bev       ;
reg [ 7: 0]            cp0_status_im        ;
reg                    cp0_status_exl       ;
reg                    cp0_status_ie        ;
wire                   count_eq_compare     ;

//temperorily set count_eq_compare as 0

assign cp0_status_ie_reg = cp0_status_ie;
assign cp0_status_exl_reg = cp0_status_exl;

assign cp0_status_bev = 1'b1;

always@(posedge clk) begin
    if(reset)
        cp0_status_im <= 8'b0;
    else if(mtc0_we && cp0_waddr == 8'b01100000) 
        cp0_status_im <= cp0_wdata[15: 8];
end 

always@(posedge clk) begin
    if(reset)
        cp0_status_exl <= 1'b0;
    else if(wb_ex)
        cp0_status_exl <= 1'b1;
    else if(eret_flush)
        cp0_status_exl <= 1'b0;
    else if(mtc0_we && cp0_waddr == 8'b01100000)
        cp0_status_exl <= cp0_wdata[1];
end

always@(posedge clk) begin
    if(reset)
        cp0_status_ie <= 1'b0;
    else if(mtc0_we && cp0_waddr == 8'b01100000)
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
    else if(mtc0_we && cp0_waddr == 8'b01011000)
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
    else if(mtc0_we && cp0_waddr == 8'b01101000)
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
    else if(mtc0_we && cp0_waddr == 8'b01110000)
        cp0_epc <= cp0_wdata;
end
assign cp0_epc_reg = cp0_epc;


reg [31: 0]             cp0_badvaddr;

always@(posedge clk) begin
    if(wb_ex && wb_excode == 5'b00100) 
        cp0_badvaddr <= wb_badvaddr;
    else if(wb_ex && wb_excode == 5'b00101)
        cp0_badvaddr <= wb_badvaddr;
    else if(wb_ex && ((wb_excode == 5'h02) || (wb_excode == 5'h03) || (wb_excode == 5'h01)))
        cp0_badvaddr <= wb_badvaddr;
end

assign cp0_badvaddr_reg = cp0_badvaddr;

reg                     tick;
reg [31: 0]             cp0_count;
always@(posedge clk) begin
    if(reset)   tick <= 1'b0;
    else        tick <= ~tick;
    if(reset) begin
        cp0_count <= 32'b0;
    end
    else if(mtc0_we && cp0_waddr == 8'b01001000) begin
        cp0_count <= cp0_wdata;
     end
    else if(tick)
        cp0_count <= cp0_count + 1'b1;
end
assign cp0_count_reg  = cp0_count;


reg [31: 0]            cp0_compare;
always@(posedge clk) begin
    if(reset) begin
        cp0_compare <= 32'b0;
    end
    else if(mtc0_we && cp0_waddr == 8'b01011000) begin
        cp0_compare <= cp0_wdata;
    end
end

assign cp0_compare_reg = cp0_compare;

assign count_eq_compare = (cp0_compare == cp0_count);
assign o_count_eq_compare = count_eq_compare;

assign int_req = cp0_status_im & cp0_cause_ip;


reg [18:0]  cp0_entryhi_vpn2;
reg [ 7:0]  cp0_entryhi_asid;

always@(posedge clk) begin
    if(reset) begin
        cp0_entryhi_vpn2 <= 19'b0;
        cp0_entryhi_asid <= 8'b0;
    end
    else if(wb_ex && ((wb_excode == 5'h02) || (wb_excode == 5'h03) || (wb_excode == 5'h01))) begin
        cp0_entryhi_vpn2 <= wb_badvaddr[31:13];
    end
    else if(mtc0_we && cp0_waddr == 8'h50) begin
        cp0_entryhi_vpn2 <= cp0_wdata[31:13];
        cp0_entryhi_asid <= cp0_wdata[ 7: 0];
    end
    else if(inst_tlbr && ws_valid)  begin
        cp0_entryhi_vpn2 <= r_vpn2;
        cp0_entryhi_asid <= r_asid;
    end
end

assign cp0_entryhi_reg = {
                            cp0_entryhi_vpn2, // 31:13
                            5'b0,             // 12:8
                            cp0_entryhi_asid  // 7:0
                         };

reg [19:0]  cp0_entrylo0_pfn0   ;
reg [ 2:0]  cp0_entrylo0_c0     ;
reg         cp0_entrylo0_d0     ;
reg         cp0_entrylo0_v0     ;
reg         cp0_entrylo0_g0     ;

always@(posedge clk) begin
    if(reset) begin
        cp0_entrylo0_pfn0 <= 20'b0  ;
        cp0_entrylo0_c0   <= 3'b0   ;
        cp0_entrylo0_d0   <= 1'b0   ;
        cp0_entrylo0_v0   <= 1'b0   ;
        cp0_entrylo0_g0   <= 1'b0   ;
    end
    else if(mtc0_we && cp0_waddr == 8'h10) begin
        cp0_entrylo0_pfn0 <= cp0_wdata[25:6] ;
        cp0_entrylo0_c0   <= cp0_wdata[ 5:3] ;
        cp0_entrylo0_d0   <= cp0_wdata[2]    ;
        cp0_entrylo0_v0   <= cp0_wdata[1]    ;
        cp0_entrylo0_g0   <= cp0_wdata[0]    ;
    end
    else if(inst_tlbr && ws_valid) begin
        cp0_entrylo0_pfn0 <= r_pfn0 ;
        cp0_entrylo0_c0   <= r_c0   ;
        cp0_entrylo0_d0   <= r_d0   ;
        cp0_entrylo0_v0   <= r_v0   ;
        cp0_entrylo0_g0   <= r_g    ;
    end
end


assign cp0_entrylo0_reg =   {
                                6'b0                , // 31:26
                                cp0_entrylo0_pfn0   , // 25:6 
                                cp0_entrylo0_c0     , // 5:3
                                cp0_entrylo0_d0     , // 2
                                cp0_entrylo0_v0     , // 1
                                cp0_entrylo0_g0      // 0
                            };

reg [19:0]  cp0_entrylo1_pfn1   ;
reg [ 2:0]  cp0_entrylo1_c1     ;
reg         cp0_entrylo1_d1     ;
reg         cp0_entrylo1_v1     ;
reg         cp0_entrylo1_g1     ;

always@(posedge clk) begin
    if(reset) begin
        cp0_entrylo1_pfn1 <= 20'b0  ;
        cp0_entrylo1_c1   <= 3'b0   ;
        cp0_entrylo1_d1   <= 1'b0   ;
        cp0_entrylo1_v1   <= 1'b0   ;
        cp0_entrylo1_g1   <= 1'b0   ;
    end
    else if(mtc0_we &&cp0_waddr == 8'h18) begin
        cp0_entrylo1_pfn1 <= cp0_wdata[25:6] ;
        cp0_entrylo1_c1   <= cp0_wdata[ 5:3] ;
        cp0_entrylo1_d1   <= cp0_wdata[2]  ;
        cp0_entrylo1_v1   <= cp0_wdata[1]  ;
        cp0_entrylo1_g1   <= cp0_wdata[0]  ;
    end
    else if(inst_tlbr && ws_valid) begin
        cp0_entrylo1_pfn1 <= r_pfn1        ;
        cp0_entrylo1_c1   <= r_c1          ;
        cp0_entrylo1_d1   <= r_d1          ;
        cp0_entrylo1_v1   <= r_v1          ;
        cp0_entrylo1_g1   <= r_g           ;
    end
end

assign cp0_entrylo1_reg =   {
                                6'b0                , // 31:26
                                cp0_entrylo1_pfn1   , // 25:6 
                                cp0_entrylo1_c1     , // 5:3
                                cp0_entrylo1_d1     , // 2
                                cp0_entrylo1_v1     , // 1
                                cp0_entrylo1_g1       // 0
                            };


reg       cp0_index_p;
reg [3:0] cp0_index_Index;

always@(posedge clk) begin
    if(reset) begin
        cp0_index_p <= 1'b0;
    end
    else if(mtc0_we  && cp0_waddr == 8'h00) begin
        cp0_index_Index <= cp0_wdata[3:0];
        //cp0_index_p     <= cp0_wdata[31] ;
        cp0_index_p     <= 1'b0;
    end
    else if(inst_tlbp && tlbp_found && ws_valid) begin
        cp0_index_Index <= cp0_windex;
        cp0_index_p     <= 1'b0;
    end
    else if(inst_tlbp && !tlbp_found && ws_valid) begin
        cp0_index_p     <= 1'b1;
    end
end

assign cp0_index_reg = {cp0_index_p, 27'b0, cp0_index_Index};

endmodule
