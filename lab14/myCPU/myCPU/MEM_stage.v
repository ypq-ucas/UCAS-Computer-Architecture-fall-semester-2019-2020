`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,

    input                          reflush       ,
    output                         is_write_entryhi,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    //input  [31                 :0] data_sram_rdata,
    //data sram-like interface

    input [31:0]                   data_sram_rdata,
    input                          data_sram_data_ok,

    output [4:0]                   ms_waddr      ,
    output                         ms_wen        ,
    output                         ms_is_valid   ,
    output [31:0]                  ms_forward_data,
    output                         ms_exc         ,
    output                         ms_mfc0_read  ,
    output                         ms_eret       ,
    output                         is_mem_lw     ,
    output                         data_read_ok  ,
    output                         ms_refetch    
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [ 1:0] ms_vaddr;
wire [11:0] ms_load_store_op;
wire [31:0] ms_rt_value;
wire        tlbp_found ;
wire [ 3:0] cp0_windex ;
wire        es_refetch ;

wire       op_lw;
wire       op_lb;
wire       op_lbu;
wire       op_lh;
wire       op_lhu;
wire       op_lwl;
wire       op_lwr;
//lab7:
wire[31:0] lb_wb_data;
wire[31:0] lbu_wb_data;
wire[31:0] lh_wb_data;
wire[31:0] lhu_wb_data;
wire[31:0] lw_wb_data;

wire[ 3:0] lwl_byte_wen;
wire[ 3:0] lwr_byte_wen;
wire[31:0] lwl_wb_data ;
wire[31:0] lwr_wb_data ;
 
// lab8:
wire        es_ex;
wire [4: 0] es_excode;

wire        ms_ex      ;
wire [4: 0] ms_excode  ;

wire        mfc0_read  ;
wire        mtc0_we    ;
wire [7: 0] cp0_waddr  ;
wire [7: 0] cp0_raddr  ;
wire        es_bd      ;
wire        eret       ;
wire [7: 0] fs_vaddr   ;
wire [31:0] badvaddr   ;
wire        inst_tlbwi ;
wire        inst_tlbr  ;
wire        inst_tlbp  ;
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
wire              tlb_refill    ;

assign ms_exc = ms_ex;
assign ms_refetch   = (ms_valid) ? es_refetch : 1'b0;

assign {tlb_refill     ,  //184
        es_refetch     ,  //183
        cp0_windex     ,  //182:179
        tlbp_found     ,  //178
        inst_tlbwi     ,  //177
        inst_tlbr      ,  //176
        inst_tlbp      ,  //175
        badvaddr       ,  //174:143
        eret           ,  //142
        es_bd          ,  //141
        mfc0_read      ,  //140
        mtc0_we        ,  //139
        cp0_waddr      ,  //138:131
        cp0_raddr      ,  //130:123
        es_excode      ,  //122:118
        es_ex          ,  //117
        ms_rt_value     , //116:85
        ms_load_store_op, //84:73
        ms_vaddr       ,  //72:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

assign op_lw  = ms_load_store_op[11];
assign op_lb  = ms_load_store_op[10];
assign op_lbu = ms_load_store_op[ 9];
assign op_lh  = ms_load_store_op[ 8];
assign op_lhu = ms_load_store_op[ 7];
assign op_lwl = ms_load_store_op[ 6];
assign op_lwr = ms_load_store_op[ 5];

assign lw_wb_data  =  data_sram_rdata;

assign lb_wb_data  =  (ms_vaddr == 2'b00) ? {{24{data_sram_rdata[ 7]}}, data_sram_rdata[ 7: 0]} :
                      (ms_vaddr == 2'b01) ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15: 8]} :
                      (ms_vaddr == 2'b10) ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} :
                      (ms_vaddr == 2'b11) ? {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} : 32'b0;

assign lbu_wb_data =  (ms_vaddr == 2'b00) ? {24'b0, data_sram_rdata[ 7: 0]} :
                      (ms_vaddr == 2'b01) ? {24'b0, data_sram_rdata[15: 8]} :
                      (ms_vaddr == 2'b10) ? {24'b0, data_sram_rdata[23:16]} :
                      (ms_vaddr == 2'b11) ? {24'b0, data_sram_rdata[31:24]} : 32'b0;

assign lh_wb_data  =  (ms_vaddr == 2'b00) ? {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]} : 
                      (ms_vaddr == 2'b10) ? {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]} : 32'b0;

assign lhu_wb_data =  (ms_vaddr == 2'b00) ? {16'b0, data_sram_rdata[15:0]} : 
                      (ms_vaddr == 2'b10) ? {16'b0, data_sram_rdata[31:16]} : 32'b0;

assign lwl_wb_data  =  (ms_vaddr == 2'b00) ? ({data_sram_rdata[ 7:0], ms_rt_value[23:0]}):
                       (ms_vaddr == 2'b01) ? ({data_sram_rdata[15:0], ms_rt_value[15:0]}):
                       (ms_vaddr == 2'b10) ? ({data_sram_rdata[23:0], ms_rt_value[ 7:0]}):
                       (ms_vaddr == 2'b11) ? data_sram_rdata : 32'b0;

assign lwr_wb_data  =  (ms_vaddr == 2'b00) ? data_sram_rdata :
                       (ms_vaddr == 2'b01) ? ({ms_rt_value[31:24], data_sram_rdata[31: 8]}):
                       (ms_vaddr == 2'b10) ? ({ms_rt_value[31:16], data_sram_rdata[31:16]}):
                       (ms_vaddr == 2'b11) ? ({ms_rt_value[31: 8], data_sram_rdata[31:24]}):32'b0;
/*
assign lwl_byte_wen =  (ms_vaddr == 2'b00) ? 4'h8 :
                       (ms_vaddr == 2'b01) ? 4'hc :
                       (ms_vaddr == 2'b10) ? 4'he :
                       (ms_vaddr == 2'b11) ? 4'hf : 4'h0;

assign lwr_byte_wen =  (ms_vaddr == 2'b00) ? 4'hf :
                       (ms_vaddr == 2'b01) ? 4'h7 :
                       (ms_vaddr == 2'b10) ? 4'h3 :
                       (ms_vaddr == 2'b11) ? 4'h1 : 4'h0;
*/

wire [31:0] mem_result;
wire [31:0] ms_final_result;




assign ms_to_ws_bus =                   {tlb_refill & ms_valid    ,  //137
                                         ms_refetch     ,  //136
                                         cp0_windex     ,  //135:132 
                                         tlbp_found     ,  //131
                                         inst_tlbwi     ,  //130
                                         inst_tlbr      ,  //129 
                                         inst_tlbp      ,  //128
                                         badvaddr       ,  //127:96
                                         eret           ,  //95
                                         es_bd          ,  //94
                                         mfc0_read      ,  //93
                                         mtc0_we        ,  //92
                                         cp0_waddr      ,  //91:84
                                         cp0_raddr      ,  //83:76
                                         ms_ex          ,  // 75
                                         ms_excode      ,  //74:70
                                         ms_gr_we       ,  //69:69
                                         ms_dest        ,  //68:64
                                         ms_final_result,  //63:32
                                         ms_pc             //31:0
                                        };

/************************************************/

assign ms_waddr = ms_dest;
assign ms_wen   = ms_gr_we;
assign ms_is_valid = ms_valid;
assign ms_forward_data = ms_final_result;
/************************************************/

//assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (reflush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
// lab7:
assign mem_result = ({32{op_lw}}  & lw_wb_data )
                  | ({32{op_lb}}  & lb_wb_data )
                  | ({32{op_lbu}} & lbu_wb_data)
                  | ({32{op_lh}}  & lh_wb_data )
                  | ({32{op_lhu}} & lhu_wb_data)
                  | ({32{op_lwl}} & lwl_wb_data)
                  | ({32{op_lwr}} & lwr_wb_data);

// lab8:
assign ms_ex        = (ms_valid) ? es_ex : 1'b0     ;
assign ms_eret      = (ms_valid) ? eret  : 1'b0;
assign ms_excode    = (ms_valid) ? es_excode : 5'b0 ; 
assign ms_mfc0_read = mfc0_read;

//assign ms_final_result = ms_res_from_mem ? mem_result 
               //        :                     ms_alu_result;

wire        is_lw;
assign  is_lw = op_lw | op_lb | op_lbu | op_lh | op_lhu | op_lwl | op_lwr;
assign  ms_ready_go = (is_lw & ~data_sram_data_ok & ~ms_ex & ~ms_refetch) ? 1'b0 : 1'b1;

reg [31:0]   rdata_buf;
reg          rdata_buf_valid;

always@(posedge clk) begin
    if(reset) begin
        rdata_buf_valid <= 1'b0;
    end
    else if(ms_to_ws_valid && ws_allowin) begin
        rdata_buf_valid <= 1'b0;
    end
    else if(!rdata_buf_valid && !ws_allowin && is_lw) begin
        rdata_buf_valid <= 1'b1;
    end

    if(!rdata_buf_valid && !ws_allowin && is_lw) begin
        rdata_buf <= mem_result;
    end
end

assign ms_final_result = ms_res_from_mem ? (rdata_buf_valid ? rdata_buf : mem_result)
                                         : ms_alu_result;

assign is_mem_lw  = is_lw;

assign data_read_ok = data_sram_data_ok;

// this shows that this inst is writing entryhi register:
assign is_write_entryhi = mtc0_we && (cp0_waddr == 8'h50);

//assign ms_tlbr_tlbwi    = (inst_tlbr | inst_tlbwi) & ms_valid;

endmodule
