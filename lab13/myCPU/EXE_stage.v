`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,

    // see if there exists exception in ms and ws:
    input                          ms_exc        ,
    input                          ws_exc        ,
    // pipline reflush signal                   
    input                          reflush       , 
    input                          ms_eret       ,
    input                          ws_eret       ,
    input                          ms_is_valid   ,
    input                          is_write_entryhi ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    /*
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    */
    // data sram like interface
    output         data_sram_req    ,
    output         data_sram_wr     ,
    output [2:0]   data_sram_size   ,
    output [31:0]  data_sram_addr   ,
    output [3:0]   data_sram_wstrb  ,
    output [31:0]  data_sram_wdata  ,
    
    input              data_sram_addr_ok,
    input              data_sram_data_ok,
    input  [31:0]      cp0_entryhi_reg  ,

    // tlb search port 1:
    output [18:0]  s1_vpn2          ,
    output         s1_odd_page      ,
    output [7:0]   s1_asid          ,

    input          s1_found         ,
    input  [3:0]   s1_index         ,
    input  [19:0]  s1_pfn           ,
    input  [2:0]   s1_c             ,
    input          s1_d             ,
    input          s1_v             ,




    //data and waddr for hold
    output [4:0]  es_waddr  ,
    output        es_wen,
    output        es_is_valid,
    output [31:0] es_forward_data,
    output        is_lw,
    output        es_mfc0_read      ,

    // refetch judgement:
    input         ms_refetch        ,
    input         ws_refetch        
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

// two regsiter for mult and div
reg  [31:0]  hi_reg;
reg  [31:0]  lo_reg;

wire [15:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
// show if imm is 0-extended
wire        es_src2_is_imm0;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
wire        hi_wen;
wire        lo_wen;
wire [31:0] hi_wdata;
wire [31:0] lo_wdata;
wire        hi_read;
wire        lo_read;
wire [11:0] es_load_store_op;
wire [ 1:0] vaddr;
wire [31:0] fs_badvaddr;
wire        no_ms_ws_eret;

wire        op_sw;
wire        op_sb;
wire        op_sh;
wire        op_swl;
wire        op_swr;

wire [31:0] swl_wdata;
wire [31:0] swr_wdata;

wire [ 3:0] sw_byte_wen;
wire [ 3:0] sb_byte_wen;
wire [ 3:0] sh_byte_wen;
wire [ 3:0] swl_byte_wen;
wire [ 3:0] swr_byte_wen;
wire [ 3:0] byte_wen;

wire [31:0] write_data;

//lab8:
wire            ds_ex                     ;
wire [4: 0]     ds_excode                 ;
wire            exe_stage_ex              ; 
wire [4: 0]     exe_stage_excode          ;
wire            ex_invalid_store_addr     ;
wire            ex_invalid_load_addr      ;
wire            overflow                  ;
wire            ex_overflow               ; 
wire            es_ex                     ;
wire [4: 0]     es_excode                 ;
wire            mtc0_we                   ;
wire            mfc0_read                 ;
wire [7: 0]     cp0_waddr                 ;
wire [7: 0]     cp0_raddr                 ;
wire            id_bd                     ;
wire            overflow_inst             ;
wire            eret                      ;
wire            inst_tlbwi                ;
wire            inst_tlbr                 ;
wire            inst_tlbp                 ;
wire            ds_refetch                ;
wire            no_ms_ws_refetch          ;

assign {ds_refetch      , // 283
        inst_tlbwi      , // 282
        inst_tlbr       , // 281
        inst_tlbp       , // 280
        fs_badvaddr     , // 279:248
        eret            , // 247
        id_bd           , // 246
        mfc0_read       , // 245
        mtc0_we         , // 244
        cp0_waddr       , // 243:236
        cp0_raddr       , // 235:228
        overflow_inst   , // 227
        ds_excode       , // 226:222
        ds_ex           , // 221
        es_load_store_op, // 220:209
        hi_read        ,  // 208
        lo_read        ,  // 207
        hi_wdata       ,  // 206:175
        lo_wdata       ,  // 174:143
        hi_wen         ,  // 142
        lo_wen         ,  // 141
        es_src2_is_imm0,  // 140
        es_alu_op      ,  //139:124
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_to_ms_result;

wire         es_res_from_mem;
wire [31:0]  true_addr;

wire [31:0]  badvaddr;
wire [31:0]  true_phy_addr;
wire         tlbp_found;
wire [3:0]   cp0_windex;
wire         es_refetch;

//assign badvaddr = (ds_ex && ds_excode == 5'h04) ? fs_badvaddr : es_to_ms_result;


assign es_res_from_mem = es_load_op;
assign es_refetch  = (es_valid) ? ds_refetch : 1'b0;

assign es_to_ms_bus =                    {es_refetch     ,  //183
                                          cp0_windex     ,  //182:179
                                          tlbp_found     ,  //178 
                                          inst_tlbwi     ,  //177
                                          inst_tlbr      ,  //176 
                                          inst_tlbp      ,  //175
                                          badvaddr       ,  //174:143
                                          eret           ,  //142
                                          id_bd          ,  //141
                                          mfc0_read      ,  //140
                                          mtc0_we        ,  //139
                                          cp0_waddr      ,  //138:131 
                                          cp0_raddr      ,  //130:123
                                          es_excode      ,  //122:118
                                          es_ex           , //117
                                          es_rt_value     , //116:85
                                          es_load_store_op, //84:73
                                          vaddr          ,  //72:71
                                          es_res_from_mem,  //70:70
                                          es_gr_we       ,  //69:69
                                          es_dest        ,  //68:64
                                          es_to_ms_result  ,  //63:32
                                          es_pc             //31:0
                                        };

assign op_sw    = es_load_store_op[4];
assign op_sb    = es_load_store_op[3];
assign op_sh    = es_load_store_op[2];
assign op_swl   = es_load_store_op[1];
assign op_swr   = es_load_store_op[0];

wire   is_store;
assign is_store = op_sw | op_sb | op_sh | op_swl | op_swr;

/**************************************/
assign es_waddr = es_dest;
assign es_wen   = es_gr_we; 
assign es_is_valid = es_valid;
assign is_lw = es_load_op;
/**************************************/


//assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (reflush) begin
        es_valid <= 1'b0;
    end    
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end


assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_imm0? {16'b0, es_imm[15:0]}:
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .overflow   (overflow     )   
    );

/**********************************/
wire op_mult;
wire op_multu;
wire op_div;
wire op_divu;

wire [63:0] mult_result;
wire [63:0] multu_result;
wire [63:0] div_result;
wire [63:0] divu_result;
wire [63:0] mult_div_result;

wire [31:0] final_hi_wdata;
wire [31:0] final_lo_wdata;

wire [31:0] hi_read_data;
wire [31:0] lo_read_data;



assign op_mult      = es_alu_op[12];
assign op_multu     = es_alu_op[13];
assign op_div       = es_alu_op[14];
assign op_divu      = es_alu_op[15];

assign mult_result  = $signed(es_alu_src1) * $signed(es_alu_src2);
assign multu_result = es_alu_src1 * es_alu_src2; 

assign mult_div_result = ({64{op_mult}}   & mult_result)
                       | ({64{op_multu}}  & multu_result)
                       | ({64{op_div}}    & div_result)
                       | ({64{op_divu}}   & divu_result);

assign hi_read_data    = hi_reg;
assign lo_read_data    = lo_reg;

wire   no_ms_es_ex;

assign no_ms_es_ex        = ~ms_exc & ~ws_exc;
assign no_ms_ws_eret      = ~ms_eret & ~ws_eret;
assign no_ms_ws_refetch   = ~ms_refetch & ~ws_refetch;

always@(posedge clk) begin
    if(reset) begin
        hi_reg <= 32'b0;
    end
    else if(hi_wen & no_ms_es_ex & es_valid) begin
        hi_reg <= hi_wdata;
    end
    else if((op_div | op_divu) & no_ms_es_ex & es_valid) begin
        hi_reg <= mult_div_result[31:0];
    end
    else if((op_mult | op_multu) & no_ms_es_ex & es_valid) begin
        hi_reg <= mult_div_result[63:32];
    end
end

always@(posedge clk) begin
    if(reset) begin
        lo_reg <= 32'b0;
    end
    else if(lo_wen & no_ms_es_ex & es_valid) begin
        lo_reg <= lo_wdata;
    end
    else if((op_div | op_divu) & no_ms_es_ex & es_valid) begin
        lo_reg <= mult_div_result[63:32];
    end
    else if((op_mult | op_multu) & no_ms_es_ex & es_valid) begin
        lo_reg <= mult_div_result[31: 0];
    end
end

/******************divisor module*************************/

reg           s_axis_divisor_tvalid_signed;
reg           s_axis_dividend_tvalid_signed;
wire          s_axis_divisor_tready_signed;
wire          s_axis_dividend_tready_signed;
wire          m_axis_dout_tvalid_signed;
reg           is_dividing_signed;


mydiv_signed divsor1(
    .s_axis_divisor_tdata   (es_alu_src2),
    .s_axis_divisor_tready  (s_axis_divisor_tready_signed),
    .s_axis_divisor_tvalid  (s_axis_divisor_tvalid_signed),
    .s_axis_dividend_tdata  (es_alu_src1),
    .s_axis_dividend_tready (s_axis_dividend_tready_signed),
    .s_axis_dividend_tvalid (s_axis_dividend_tvalid_signed),
    .m_axis_dout_tvalid     (m_axis_dout_tvalid_signed),
    .m_axis_dout_tdata      (div_result),
    .aclk                   (clk)
);

always@(posedge clk) begin
    if(reset) begin
        s_axis_dividend_tvalid_signed <= 1'b0;
    end
    else if(is_dividing_signed && es_valid) begin
        s_axis_dividend_tvalid_signed <= 1'b0;
    end
    else if(s_axis_dividend_tready_signed && es_valid) begin
        s_axis_dividend_tvalid_signed <= 1'b0;
    end
    else if(op_div && !is_dividing_signed && no_ms_es_ex && es_valid && no_ms_ws_eret && no_ms_ws_refetch) begin
        s_axis_dividend_tvalid_signed <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        s_axis_divisor_tvalid_signed <= 1'b0;
    end
    else if(is_dividing_signed && es_valid) begin
        s_axis_divisor_tvalid_signed <= 1'b0;
    end
    else if(s_axis_divisor_tready_signed && es_valid) begin
        s_axis_divisor_tvalid_signed <= 1'b0;
    end
    else if(op_div && !is_dividing_signed && no_ms_es_ex && es_valid && no_ms_ws_eret && no_ms_ws_refetch) begin
        s_axis_divisor_tvalid_signed <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        is_dividing_signed <= 1'b0;
    end
    else if(s_axis_divisor_tready_signed && s_axis_divisor_tvalid_signed && es_valid) begin
        is_dividing_signed <= 1'b1;
    end
    else if(op_div && m_axis_dout_tvalid_signed && no_ms_es_ex && es_valid) begin
        is_dividing_signed <= 1'b0;
    end
end

reg           s_axis_divisor_tvalid_unsigned;
reg           s_axis_dividend_tvalid_unsigned;
wire          s_axis_divisor_tready_unsigned;
wire          s_axis_dividend_tready_unsigned;
wire          m_axis_dout_tvalid_unsigned;
reg           is_dividing_unsigned;


// unsigned divider
mydiv_unsigned divsor2(
    .s_axis_divisor_tdata   (es_alu_src2),
    .s_axis_divisor_tready  (s_axis_divisor_tready_unsigned),
    .s_axis_divisor_tvalid  (s_axis_divisor_tvalid_unsigned),
    .s_axis_dividend_tdata  (es_alu_src1),
    .s_axis_dividend_tready (s_axis_dividend_tready_unsigned),
    .s_axis_dividend_tvalid (s_axis_dividend_tvalid_unsigned),
    .m_axis_dout_tvalid     (m_axis_dout_tvalid_unsigned),
    .m_axis_dout_tdata      (divu_result),
    .aclk                   (clk)
);


always@(posedge clk) begin
    if(reset) begin
        s_axis_dividend_tvalid_unsigned <= 1'b0;
    end
    else if(is_dividing_unsigned && es_valid) begin
        s_axis_dividend_tvalid_unsigned <= 1'b0;
    end
    else if(s_axis_dividend_tready_unsigned && es_valid) begin
        s_axis_dividend_tvalid_unsigned <= 1'b0;
    end
    else if(op_divu && !is_dividing_unsigned && no_ms_es_ex && es_valid && no_ms_ws_eret && no_ms_ws_refetch) begin
        s_axis_dividend_tvalid_unsigned <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        s_axis_divisor_tvalid_unsigned <= 1'b0;
    end
    else if(is_dividing_unsigned && es_valid) begin
        s_axis_divisor_tvalid_unsigned <= 1'b0;
    end
    else if(s_axis_divisor_tready_unsigned && es_valid) begin
        s_axis_divisor_tvalid_unsigned <= 1'b0;
    end
    else if(op_divu && !is_dividing_unsigned && no_ms_es_ex && es_valid && no_ms_ws_eret && no_ms_ws_refetch) begin
        s_axis_divisor_tvalid_unsigned <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        is_dividing_unsigned <= 1'b0;
    end
    else if(s_axis_divisor_tready_unsigned && s_axis_divisor_tvalid_unsigned && es_valid) begin
        is_dividing_unsigned <= 1'b1;
    end
    else if(op_divu && m_axis_dout_tvalid_unsigned && no_ms_es_ex && es_valid) begin
        is_dividing_unsigned <= 1'b0;
    end
end

//lab7:
/**********************************/
assign es_ready_go = (reflush)? 1'b1 :
                     ((es_load_op | is_store) & ~data_sram_addr_ok & ~es_ex & ~es_refetch) ? 1'b0 :  
                     (op_div  & ~m_axis_dout_tvalid_signed & ~es_refetch) ? 1'b0 : 
                     (op_divu & ~m_axis_dout_tvalid_unsigned & ~es_refetch) ? 1'b0 : 
                     (inst_tlbp && ms_is_valid && is_write_entryhi && !es_refetch) ? 1'b0 : 1'b1;

assign es_to_ms_result = (hi_read) ? hi_read_data :
                         (lo_read) ? lo_read_data : 
                         (mtc0_we) ? es_rt_value  : es_alu_result;

assign badvaddr = (ds_ex && ds_excode == 5'h04) ? fs_badvaddr : es_to_ms_result;

assign es_forward_data = (hi_read) ? hi_read_data : 
                         (lo_read) ? lo_read_data : es_alu_result;
assign vaddr           = true_addr[1:0];

assign swl_wdata       = (vaddr == 2'b00) ? ({24'b0, es_rt_value[31:24]}):
                         (vaddr == 2'b01) ? ({16'b0, es_rt_value[31:16]}):
                         (vaddr == 2'b10) ? ({ 8'b0, es_rt_value[31: 8]}):
                         (vaddr == 2'b11) ? es_rt_value : es_rt_value;

assign swr_wdata       = (vaddr == 2'b00) ? es_rt_value:
                         (vaddr == 2'b01) ? ({es_rt_value[23: 0], 8'b0}):
                         (vaddr == 2'b10) ? ({es_rt_value[15: 0], 16'b0}):
                         (vaddr == 2'b11) ? ({es_rt_value[ 7: 0], 24'b0}):es_rt_value;

assign write_data      = op_sb  ? {4{es_rt_value[7:0]}}  : 
                         op_sh  ? {2{es_rt_value[15:0]}} : 
                         op_swl ? swl_wdata              :
                         op_swr ? swr_wdata              : es_rt_value;

assign sw_byte_wen     = 4'hf;

assign sb_byte_wen     = (vaddr == 2'b00) ? 4'h1 : 
                         (vaddr == 2'b01) ? 4'h2 : 
                         (vaddr == 2'b10) ? 4'h4 :
                         (vaddr == 2'b11) ? 4'h8 : 4'h0;

assign sh_byte_wen     = (vaddr == 2'b00) ? 4'h3 :
                         (vaddr == 2'b10) ? 4'hc : 4'h0; 

assign swl_byte_wen    = (vaddr == 2'b00) ? 4'h1 :
                         (vaddr == 2'b01) ? 4'h3 : 
                         (vaddr == 2'b10) ? 4'h7 : 
                         (vaddr == 2'b11) ? 4'hf : 4'h0;

assign swr_byte_wen    = (vaddr == 2'b00) ? 4'hf :
                         (vaddr == 2'b01) ? 4'he :
                         (vaddr == 2'b10) ? 4'hc :
                         (vaddr == 2'b11) ? 4'h8 : 4'h0;

assign byte_wen        = ({4{op_sw}} & sw_byte_wen)
                       | ({4{op_sb}} & sb_byte_wen)
                       | ({4{op_sh}} & sh_byte_wen)
                       | ({4{op_swl}} & swl_byte_wen)
                       | ({4{op_swr}} & swr_byte_wen);
/************************************************/

//lab8:
assign ex_overflow           = overflow_inst & overflow;
assign ex_invalid_store_addr = (op_sh & vaddr[0])                       //sh
                             | (op_sw & (vaddr != 2'b0));               //sw

assign ex_invalid_load_addr  = (es_load_store_op[11] & (vaddr != 2'b00))//lw
                             | (es_load_store_op[ 8] & vaddr[0]        )//lh
                             | (es_load_store_op[ 7] & vaddr[0]        );//lhu

assign exe_stage_ex          = ex_overflow | ex_invalid_load_addr | ex_invalid_store_addr;

assign exe_stage_excode      = ({5{ex_overflow}}           & 5'h0c)
                             | ({5{ex_invalid_load_addr}}  & 5'h04)
                             | ({5{ex_invalid_store_addr}} & 5'h05);

assign es_ex                 = (es_valid) ? (exe_stage_ex | ds_ex) : 1'b0;

assign es_excode             = (es_valid) ? ((ds_ex)        ? ds_excode :
                                            (exe_stage_ex) ? exe_stage_excode : 5'b0)
                                          : 5'b0;

assign es_mfc0_read          = mfc0_read;

/*
assign data_sram_en    = 1'b1;
assign data_sram_wen   = (es_mem_we && es_valid && no_ms_es_ex && ~es_ex && no_ms_ws_eret )?  byte_wen : 4'h0;
assign data_sram_addr  = {es_alu_result[31:2],2'b0};
assign data_sram_wdata = write_data;
*/

reg         buf_addr_valid;
reg [31:0]  buf_addr;


always@(posedge clk) begin
    if(reset) begin
        buf_addr_valid <= 1'b0;
    end
    else if(es_to_ms_valid && ms_allowin) begin
        buf_addr_valid <= 1'b0;
    end
    else if(!buf_addr_valid && (is_store || is_lw) && es_valid) begin
        buf_addr_valid <= 1'b1;
    end

    if(!buf_addr_valid && (is_store || is_lw) && es_valid) begin
        buf_addr <= es_alu_result;
    end
end

assign s1_vpn2   = (inst_tlbp) ? cp0_entryhi_reg[31:13] : true_addr[31:13];
assign s1_odd_page = (inst_tlbp) ? cp0_entryhi_reg[12] : true_addr[12];
assign s1_asid     = cp0_entryhi_reg[7:0];
assign tlbp_found  = s1_found   ;
assign cp0_windex  = s1_index   ;

assign true_addr = buf_addr_valid ? buf_addr : es_alu_result;
assign true_phy_addr = (true_addr[31:29] == 3'b100 || true_addr[31:29] == 3'b101) ? {3'b0,true_addr[28:0]}:
                       (s1_found) ? {s1_pfn, true_addr[11:0]} : true_addr;

assign data_sram_addr = true_addr ;

reg data_req_reg;
reg handshake   ;

always@(posedge clk) begin
    if(reset) begin
        data_req_reg <= 1'b0;
    end
    else if(data_req_reg && data_sram_addr_ok) begin
        data_req_reg <= 1'b0;
    end
    else if(ms_allowin && (es_load_op || is_store)) begin
        data_req_reg <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        handshake <= 1'b0;
    end
    else if(data_sram_addr_ok) begin
        handshake <= 1'b1;
    end
    else if(data_sram_data_ok) begin
        handshake <= 1'b0;
    end
end




assign data_sram_req  = (is_store | es_load_op) & ms_allowin & ~handshake & es_valid & no_ms_es_ex & no_ms_ws_eret & ~es_ex & ~es_refetch & no_ms_ws_refetch; 
assign data_sram_size =  (op_sb) ? 3'b000 : 
                         (op_sh) ? 3'b001 :
                         (op_sw) ? 3'b010 : 
                         (op_swl)? 3'b110 :
                         (op_swr)? 3'b010 : 3'b000;

assign data_sram_wstrb = (es_mem_we && es_valid && no_ms_es_ex && !es_ex && no_ms_ws_eret && !es_refetch && no_ms_ws_refetch)?  byte_wen : 4'h0;
assign data_sram_wr = is_store ? 1'b1 : 1'b0;
assign data_sram_wdata = write_data;

//assign es_tlbr_tlbwi   = (inst_tlbr | inst_tlbwi) & es_valid;



endmodule   
