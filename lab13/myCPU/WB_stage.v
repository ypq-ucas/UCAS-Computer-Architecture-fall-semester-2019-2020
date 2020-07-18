`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output        ws_is_valid      ,
    output [31:0] ws_forward_data  ,
    output        reflush          ,
    output        ex_occur         ,
    output         ws_exc           ,
    output         ws_eret          ,
    output [31: 0] epc_reg         ,
    output          count_eq_compare,
    output          cp0_status_exl_reg,
    output          cp0_status_ie_reg,
    output [31: 0]  cp0_entryhi_reg ,

    // tlb read port:
    output [ 3: 0]  r_index         ,
    input [18:0]    r_vpn2         ,
    input [ 7:0]    r_asid         ,
    input           r_g            ,
    input [19:0]    r_pfn0         ,
    input [ 2:0]    r_c0           ,
    input           r_d0           ,
    input           r_v0           ,
    input [19:0]    r_pfn1         ,
    input [ 2:0]    r_c1           ,
    input           r_d1           ,
    input           r_v1           ,

    // write port:
    output           tlb_we         ,
    output [3:0]     w_index        ,
    output [18:0]    w_vpn2         ,
    output [ 7:0]    w_asid         ,
    output           w_g            ,
    output [19:0]    w_pfn0         ,
    output [ 2:0]    w_c0           ,
    output           w_d0           ,
    output           w_v0           ,
    output [19:0]    w_pfn1         ,
    output [ 2:0]    w_c1           ,
    output           w_d1           ,
    output           w_v1           ,
    
    output [7: 0]   int_req         ,

    // refetch op:
    output          refetch         ,
    output [31:0]   refetch_pc      ,
    output          ws_refetch      
);

reg         ws_valid;
wire        ws_ready_go ;
wire        refetch     ;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire           ws_gr_we;
wire [ 4:0]    ws_dest;
wire [31:0]    ws_final_result;
wire [31:0]    ws_pc;

wire              ms_ex;
wire [4: 0]       ms_excode;
wire              ws_ex;
wire [4: 0]       ws_excode;
wire              ws_reflush  ;

wire              mfc0_read ;
wire              mtc0_we   ;
wire [7: 0]       cp0_waddr ;
wire [7: 0]       cp0_raddr ;
wire [31: 0]      cp0_read_data;

wire [31: 0]      cp0_wdata     ;
wire              eret_flush ;
wire              wb_bd;
wire [ 5: 0]      ext_int_in    ;

wire [31: 0]      cp0_status_reg;
wire [31: 0]      cp0_cause_reg ;
wire [31: 0]      cp0_epc_reg   ;
wire              eret;
wire [31: 0]      cp0_compare_reg;
wire [31: 0]      cp0_count_reg  ;
wire [31: 0]      cp0_badvaddr_reg ;

wire              inter_mtc0_we ;
wire [31: 0]      badvaddr      ;
wire              o_count_eq_compare;
wire              inst_tlbwi    ;
wire              inst_tlbr     ;
wire              inst_tlbp     ;
wire              tlbp_found    ;
wire [3:0]        cp0_windex    ;
wire [31:0]       cp0_entrylo0_reg;
wire [31:0]       cp0_entrylo1_reg;
wire              ms_refetch      ;
wire              inter_inst_tlbp ;
wire              inter_inst_tlbr ;

/*
wire [18:0]       r_vpn2        ;
wire [7:0]        r_asid        ;
wire              r_g           ;
wire [19:0]       r_pfn0        ;
wire [ 2:0]       r_c0          ;
wire              r_d0          ;
wire              r_v0          ;
wire [19:0]       r_pfn1        ;
wire [ 2:0]       r_c1          ;
wire              r_d1          ;
wire              r_v1          ;
*/



assign ext_int_in   = 6'b0;
assign epc_reg      = cp0_epc_reg;
assign count_eq_compare = o_count_eq_compare;
assign ws_refetch   = (ws_valid) ? ms_refetch : 1'b0;

assign {ms_refetch        ,  //136
        cp0_windex     ,  //135:132 
        tlbp_found     ,  //131
        inst_tlbwi     ,  //130
        inst_tlbr      ,  //129
        inst_tlbp      ,  //128
        badvaddr       ,  //127:96
        eret           ,  //95
        wb_bd          ,  //94
        mfc0_read      ,  //93
        mtc0_we        ,  //92
        cp0_waddr      ,  //91:84
        cp0_raddr      ,  //83:76
        ms_ex          ,  //75
        ms_excode      ,  //74:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

assign refetch        = ws_refetch;
assign refetch_pc     = (ws_valid) ? ws_pc : 32'b0;
assign ws_ex          = (ws_valid) ? ms_ex : 1'b0     ;
assign ws_excode      = (ws_valid) ? ms_excode : 5'b0 ;
assign ws_reflush     = (ws_valid == 1'b0) ? 1'b0 : ms_ex;
assign reflush        = (ws_valid) & (ws_reflush | eret | refetch);
assign ws_exc         = ws_valid & ws_ex;
assign ws_eret        = (ws_valid) ? eret : 1'b0;
assign eret_flush     = ws_eret;
/*******************************************/
assign ws_is_valid = ws_valid;
//assign ws_forward_data = rf_wdata;
/*******************************************/
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus =                   { mfc0_read, //38
                                           rf_we   ,  //37:37
                                           rf_waddr,  //36:32
                                           rf_wdata   //31:0
                                         };
assign ws_forward_data = rf_wdata;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
	else if (reflush) begin
	    ws_valid <= 1'b0;
	end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

wire    o_cp0_status_ie_reg;
wire    o_cp0_status_exl_reg;
wire [7:0]   o_int_req;
wire [31:0]  cp0_index_reg;

assign cp0_status_ie_reg = o_cp0_status_ie_reg;
assign cp0_status_exl_reg = o_cp0_status_exl_reg;
assign int_req            = o_int_req;
assign cp0_wdata  = ws_final_result;

cp0_regfile u_cp0_regfile(
    .clk(clk),
    .reset(reset),
    .cp0_wdata(ws_final_result),
    .mtc0_we(inter_mtc0_we),
    .cp0_waddr(cp0_waddr),
    .eret_flush(eret_flush),
    .wb_bd(wb_bd),
    .ext_int_in(ext_int_in),
    .wb_excode(ws_excode),
    .wb_pc(ws_pc),
    .wb_ex(ws_ex),
    .cp0_status_reg(cp0_status_reg),
    .cp0_cause_reg(cp0_cause_reg),
    .cp0_epc_reg(cp0_epc_reg),
    .cp0_badvaddr_reg(cp0_badvaddr_reg),
    .cp0_count_reg(cp0_count_reg),
    .cp0_compare_reg(cp0_compare_reg),
    .wb_badvaddr(badvaddr),
    .o_count_eq_compare(o_count_eq_compare),
    .cp0_status_exl_reg(o_cp0_status_exl_reg),
    .cp0_status_ie_reg(o_cp0_status_ie_reg),
    .int_req(o_int_req),
    .cp0_entryhi_reg(cp0_entryhi_reg),
    .cp0_index_reg(cp0_index_reg),
    .tlbp_found(tlbp_found),
    .cp0_windex(cp0_windex),
    .inst_tlbp(inter_inst_tlbp),
    .inst_tlbr(inter_inst_tlbr),
    .r_vpn2 (r_vpn2),
    .r_asid (r_asid),
    .r_g    (r_g),
    .r_pfn0 (r_pfn0),
    .r_c0   (r_c0),
    .r_d0   (r_d0),
    .r_v0   (r_v0),
    .r_pfn1 (r_pfn1),
    .r_c1   (r_c1),
    .r_d1   (r_d1),
    .r_v1   (r_v1),
    .cp0_entrylo0_reg(cp0_entrylo0_reg),
    .cp0_entrylo1_reg(cp0_entrylo1_reg),
    .ws_valid(ws_valid)

);

wire [31: 0] mfc0_read_data;

assign mfc0_read_data = (cp0_raddr == 8'b01100000) ? cp0_status_reg
                      : (cp0_raddr == 8'b01101000) ? cp0_cause_reg
                      : (cp0_raddr == 8'b01110000) ? cp0_epc_reg
                      : (cp0_raddr == 8'b01011000) ? cp0_compare_reg
                      : (cp0_raddr == 8'b01001000) ? cp0_count_reg
                      : (cp0_raddr == 8'b01000000) ? cp0_badvaddr_reg
                      : (cp0_raddr == 8'h50)       ? cp0_entryhi_reg
                      : (cp0_raddr == 8'h18)       ? cp0_entrylo1_reg
                      : (cp0_raddr == 8'h10)       ? cp0_entrylo0_reg
                      : (cp0_raddr == 8'h00)       ? cp0_index_reg
                      : 32'b0;


assign rf_we    = (ws_valid & ~ws_ex & ~refetch) & (ws_gr_we | mfc0_read);
assign rf_waddr = ws_dest;
assign rf_wdata = (mfc0_read) ? mfc0_read_data : ws_final_result;
assign inter_mtc0_we = ws_valid && mtc0_we && !ws_ex && !refetch;
assign inter_inst_tlbp = ws_valid && inst_tlbp && !ws_ex && !refetch;
assign inter_inst_tlbr = ws_valid && inst_tlbr && !ws_ex && !refetch;
assign ex_occur = ws_ex;

assign tlb_we   = inst_tlbwi & ws_valid & ~refetch;
assign w_index  = cp0_index_reg[3:0];
assign r_index  = cp0_index_reg[3:0];
assign w_vpn2   = cp0_entryhi_reg[31:13];
assign w_asid   = cp0_entryhi_reg[ 7: 0];
assign w_g      = cp0_entrylo0_reg[0] & cp0_entrylo1_reg[0];
assign w_pfn0   = cp0_entrylo0_reg[25:6];
assign w_c0     = cp0_entrylo0_reg[5:3];
assign w_d0     = cp0_entrylo0_reg[2];
assign w_v0     = cp0_entrylo0_reg[1];
assign w_pfn1   = cp0_entrylo1_reg[25:6];
assign w_c1     = cp0_entrylo1_reg[5:3];
assign w_d1     = cp0_entrylo1_reg[2];
assign w_v1     = cp0_entrylo1_reg[1];


// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = (mfc0_read) ? mfc0_read_data : ws_final_result;

//assign ws_tlbr_tlbwi     = (inst_tlbr | inst_tlbwi) & ws_valid  ;




endmodule
