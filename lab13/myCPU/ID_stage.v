`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,

    output                         is_branch     ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    input                          reflush       ,

    input [4:0]                    es_waddr      ,
    input                          es_wen        ,
    input [4:0]                    ms_waddr      ,
    input                          ms_wen        ,
    input                          ws_is_valid   ,
    input                          ms_is_valid   ,
    input                          es_is_valid   ,
    input [31:0]                   es_forward_data  ,
    input                          is_lw ,
    input [31:0]                   ms_forward_data  ,
    input [31:0]                   ws_forward_data  ,
    input                          es_mfc0_read     ,
    input                          ms_mfc0_read     ,
    input                          count_eq_compare ,
    input                          cp0_status_exl_reg,
    input                          cp0_status_ie_reg,
    input [7: 0]                   int_req          ,
    input                          is_mem_lw        ,
    input                          data_read_ok     ,
    
    // see if ds has tlbr or tlbwi:
    output                         ds_tlbr_tlbwi   
);

reg           ds_valid   ;
wire          ds_ready_go;

wire [31:0]  true_fs_pc;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign true_fs_pc = fs_to_ds_bus[134:103];

wire [31:0] ds_inst ;
wire [31:0] ds_pc   ;
wire        fs_ex   ;
wire        ds_ex   ;
wire [4: 0] fs_excode;
wire [4: 0] ds_excode;
wire        fs_bd    ;
wire [31: 0] badvaddr;
wire [31: 0] true_npc;
wire         fs_refetch;
wire         ds_refetch;


assign {fs_refetch,
        true_npc,
        badvaddr,
        fs_bd   ,
        fs_excode,
        fs_ex  ,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire        ws_mfc0_read;
assign {ws_mfc0_read, //38
        rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [15:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire        hi_wen;
wire        lo_wen;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;
/**********************/
wire [ 9:0] mul_div_flag;
wire [ 9:0] mul_div_flag_d;
wire [ 9:0] mf_hi_lo_flag;
wire [14:0] mt_hi_lo_flag;
/**********************/
//lab7:
wire [11:0] load_store_op;




wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
// show if imm is 0-extended
wire        src2_is_imm0;
//lab6:
/*******************/
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
 
wire        inst_mult; // signed 
wire        inst_multu; // unsigned

wire        inst_div;   // signed
wire        inst_divu;  // unsigend
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
/*******************/
//lab7:
/****************************/
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j   ;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;


wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;
/****************************/

wire        inst_tlbp  ;
wire        inst_tlbwi ;
wire        inst_tlbr  ;



wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

wire        rs_lt_zero;
wire        rs_le_zero;
wire        rs_gt_zero;
wire        rs_ge_zero;

/****************************************/

/****excpetion handle instructions******/

wire        inst_syscall;
wire        inst_mfc0   ;
wire        inst_mtc0   ;
wire        inst_eret   ;
wire        inst_break  ;

wire [7: 0]       cp0_waddr ;      
wire              mtc0_we   ;
wire [7: 0]       cp0_raddr ;
wire              mfc0_read ;
wire              overflow_inst;
wire              valid_br_target;



assign  rs_value =  (rf_raddr1 == es_waddr && es_is_valid && es_wen) ? es_forward_data :
                    (rf_raddr1 == ms_waddr && ms_is_valid && ms_wen) ? ms_forward_data :
                    (rf_raddr1 == rf_waddr && ws_is_valid && rf_we ) ? ws_forward_data : rf_rdata1;
                   // (rf_raddr1 == rf_waddr && ws_is_valid && rf_we && ws_mfc0_read) ? rf_wdata : rf_rdata1;

assign  rt_value =  (rf_raddr2 == es_waddr && es_is_valid && es_wen) ? es_forward_data :
                    (rf_raddr2 == ms_waddr && ms_is_valid && ms_wen) ? ms_forward_data :
                    (rf_raddr2 == rf_waddr && ws_is_valid && rf_we ) ? ws_forward_data : rf_rdata2;
                   // (rf_raddr2 == rf_waddr && ws_is_valid && rf_we && ws_mfc0_read) ? rf_wdata : rf_rdata2;

//used to save destination registers


assign br_bus       = {br_taken,br_target};

wire [31:0]   hi_wdata;
wire [31:0]   lo_wdata;

assign ds_to_es_bus =                     { ds_refetch   , // 283
                                            inst_tlbwi   , // 282
                                            inst_tlbr    , // 281
                                            inst_tlbp    , // 280
                                            badvaddr     , // 279:248
                                            inst_eret    , // 247
                                            fs_bd        , // 246
                                            mfc0_read    , // 245
                                            mtc0_we      , // 244
                                            cp0_waddr    , //243:236
                                            cp0_raddr    , //235:228
                                            overflow_inst, //227
                                            ds_excode    , //226:222 
                                            ds_ex        , //221
                                            load_store_op, //220:209
                                            hi_read     ,  //208
                                            lo_read     ,  //207
                                            hi_wdata    ,  //206:175
                                            lo_wdata    ,  //174:143
                                            hi_wen      ,  //142       
                                            lo_wen      ,  //141
                                            src2_is_imm0,  //140
                                            alu_op      ,  //139:124
                                            load_op     ,  //123:123
                                            src1_is_sa  ,  //122:122
                                            src1_is_pc  ,  //121:121
                                            src2_is_imm ,  //120:120
                                            src2_is_8   ,  //119:119
                                            gr_we       ,  //118:118
                                            mem_we      ,  //117:117
                                            dest        ,  //116:112
                                            imm         ,  //111:96
                                            rs_value    ,  //95 :64
                                            rt_value    ,  //63 :32
                                            ds_pc          //31 :0
                                            };


assign ds_ready_go  =  (reflush)? 1'b1 : 
                       (is_lw == 1'b1 && es_is_valid && ((rf_raddr1 == es_waddr && es_wen) || (rf_raddr2 == es_waddr && es_wen))) ? 1'b0 : 
                       (is_mem_lw == 1'b1 && ms_is_valid && (rf_raddr1 == ms_waddr && ms_wen || rf_raddr2 == ms_waddr && ms_wen) && !data_read_ok) ? 1'b0:
                       (es_is_valid && es_mfc0_read && es_waddr != 5'b0 && (es_waddr == rf_raddr1 | es_waddr == rf_raddr2) && es_wen) ? 1'b0 : 
                       (ms_is_valid && ms_mfc0_read && ms_waddr != 5'b0 && (ms_waddr == rf_raddr1 | ms_waddr == rf_raddr2) && ms_wen) ? 1'b0 : 1'b1;

assign valid_br_target = ds_ready_go;


assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (reflush) begin
        ds_valid <= 1'b0;
    end
    else if(ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

assign mul_div_flag = ds_inst[15:6];
assign mf_hi_lo_flag = ds_inst[25:16];
assign mt_hi_lo_flag = ds_inst[20: 6];

//lab8:
wire   [7: 0] move_c0_flag  ;
wire   [2: 0] cp0_sel       ;

assign move_c0_flag = ds_inst[10: 3];
assign cp0_sel      = ds_inst[ 2: 0];



decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));


assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

/**************************************/
// lab6:
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];

assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];

assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];

assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[6'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[6'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[6'h00];

assign inst_mult   = op_d[6'h00] & func_d[6'h18] & (mul_div_flag == 10'b0);
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & (mul_div_flag == 10'b0);

assign inst_div    = op_d[6'h00] & func_d[6'h1a] & (mul_div_flag == 10'b0);
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & (mul_div_flag == 10'b0);

assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[6'h00] & (mf_hi_lo_flag == 10'b0);
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[6'h00] & (mf_hi_lo_flag == 10'b0);
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & (mt_hi_lo_flag == 15'b0);
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & (mt_hi_lo_flag == 15'h0);

// lab7:
assign inst_bgez   = op_d[6'h01] & rt_d[6'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[6'h00];
assign inst_blez   = op_d[6'h06] & rt_d[6'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[6'h00];
assign inst_j      = op_d[6'h02];
assign inst_bgezal = op_d[6'h01] & rt_d[6'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[6'h10];
assign inst_jalr   = op_d[6'h00] & rt_d[6'h00] & sa_d[6'h00] & func_d[6'h09];

assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];

// lab8:
assign inst_syscall = op_d[6'h00] & func_d[6'h0c];
assign inst_mfc0    = op_d[6'h10] & rs_d[6'h0] & (move_c0_flag == 8'b0);
assign inst_mtc0    = op_d[6'h10] & rs_d[6'h4] & (move_c0_flag == 8'b0);
assign inst_eret    = op_d[6'h10] & ds_inst[25] & (ds_inst[24: 6] == 19'b0) & func_d[6'h18];
assign inst_break   = op_d[6'h00] & func_d[6'h0d];

// lab13:
assign inst_tlbwi   = op_d[6'h10] & ds_inst[25] & (ds_inst[24:6] == 19'b0) & func_d[6'h02];
assign inst_tlbp    = op_d[6'h10] & ds_inst[25] & (ds_inst[24:6] == 19'b0) & func_d[6'h08];
assign inst_tlbr    = op_d[6'h10] & ds_inst[25] & (ds_inst[24:6] == 19'b0) & func_d[6'h01];
/***************************************/
assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_add | inst_addi | inst_bgezal | inst_bltzal | inst_jalr
                  | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sb | inst_sh | inst_swl | inst_swr;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;    //signed compare 
assign alu_op[ 3] = inst_sltu | inst_sltiu;   // unsigned compare
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor; 
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;    // v->value in  rs register
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_div;
assign alu_op[15] = inst_divu;

assign load_store_op[11] = inst_lw;
assign load_store_op[10] = inst_lb;
assign load_store_op[ 9] = inst_lbu;
assign load_store_op[ 8] = inst_lh;
assign load_store_op[ 7] = inst_lhu;
assign load_store_op[ 6] = inst_lwl;
assign load_store_op[ 5] = inst_lwr;
assign load_store_op[ 4] = inst_sw;
assign load_store_op[ 3] = inst_sb;
assign load_store_op[ 2] = inst_sh;
assign load_store_op[ 1] = inst_swl;
assign load_store_op[ 0] = inst_swr;



assign overflow_inst = inst_add | inst_addi | inst_sub;
assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal | inst_jalr | inst_bgezal | inst_bltzal;
assign src2_is_imm  = inst_addiu | inst_lui | inst_lw | inst_sw | inst_slti | inst_addi | inst_sltiu | load_op | inst_sb | inst_sh | inst_swl | inst_swr ;
assign src2_is_8    = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;
assign res_from_mem = inst_lw | inst_lwl | inst_lwr | inst_lb | inst_lbu | inst_lh | inst_lhu;
assign dst_is_r31   = inst_jal | inst_bltzal | inst_bgezal;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw | inst_addi | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | load_op | inst_mfc0;
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_j & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr & ~inst_mtc0;
assign mem_we       = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;
assign src2_is_imm0 = inst_andi | inst_ori | inst_xori;

assign hi_wen       = inst_mthi;
assign lo_wen       = inst_mtlo;

assign dest         = (inst_mult | inst_multu | inst_div | inst_divu) ? 5'd0: // do not write when mul or div
                      dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;
assign load_op = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;

assign hi_wdata = rs_value;
assign lo_wdata = rs_value;

assign hi_read  = inst_mfhi;
assign lo_read  = inst_mflo;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

// lab8:
wire              id_stage_ex;
wire [4: 0]       id_stage_excode;
wire              reserved_inst  ;
wire              time_interrupt ;
wire              interrupt      ;
reg               interrupt_reg  ;

assign reserved_inst   = ~inst_add & ~inst_addi & ~inst_addiu & ~inst_addu & ~inst_and & ~inst_andi
                       & ~inst_bne & ~inst_beq & ~inst_bgez & ~inst_bgezal & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_bltzal
                       & ~inst_j   & ~inst_jal  & ~inst_jalr   & ~inst_jr
                       & ~inst_div & ~inst_divu & ~inst_mult   & ~inst_multu
                       & ~inst_break & ~inst_eret & ~inst_syscall & ~inst_mfc0 & ~inst_mtc0 & ~inst_mfhi & ~inst_mflo & ~inst_mtlo & ~inst_mthi
                       & ~inst_lw & ~inst_lb & ~inst_lbu & ~inst_lh & ~inst_lhu & ~inst_lwl & ~inst_lwr
                       & ~inst_sw & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr
                       & ~inst_nor & ~inst_or & ~inst_ori & ~inst_sra & ~inst_srav & ~inst_srl & ~inst_srlv & ~inst_sll & ~inst_sllv
                       & ~inst_slt & ~inst_slti & ~inst_sltiu & ~inst_sltu & ~inst_sub & ~inst_subu & ~inst_xor & ~inst_xori & ~inst_lui
                       & ~inst_tlbp & ~inst_tlbr & ~inst_tlbwi;

assign time_interrupt  = count_eq_compare & ws_is_valid & cp0_status_ie_reg & ~cp0_status_exl_reg;
assign interrupt       = (int_req[0] | int_req[1] | int_req[2] | int_req[3] | int_req[4] | int_req[5] | int_req[6] | int_req[7]) & ws_is_valid & cp0_status_ie_reg & ~cp0_status_exl_reg;

always@(posedge clk) begin
    if(reset) begin
        interrupt_reg <= 1'b0;
    end
    else if(interrupt_reg && ds_to_es_valid && es_allowin) begin
        interrupt_reg <= 1'b0;
    end
    else if(interrupt) begin
        interrupt_reg <= 1'b1;
    end
end



assign id_stage_ex     = inst_syscall | inst_break | reserved_inst ;
assign id_stage_excode = ({5{inst_syscall}} & `EX_SYSCALL)
                       | ({5{inst_break  }} & `EX_BREAK)
                       | ({5{reserved_inst}} & `EX_RESERVED);

           

assign ds_ex           = (ds_valid) ? (fs_ex | id_stage_ex | interrupt_reg) : 1'b0;
assign ds_excode       = (ds_valid) ? ((interrupt_reg)    ? 5'b0 :
                                       (fs_ex)        ? fs_excode :
                                       (id_stage_ex)  ? id_stage_excode : 5'b0)
                                    : 5'b0; 
assign ds_refetch      = (ds_valid) ? fs_refetch : 1'b0;

assign cp0_waddr       = {rd, cp0_sel};     
assign mtc0_we         = inst_mtc0;
assign cp0_raddr       = {rd, cp0_sel};
assign mfc0_read       = inst_mfc0;               




assign rs_eq_rt = (rs_value == rt_value);
assign rs_le_zero = rs_value[31] | (rs_value == 32'b0);
assign rs_lt_zero = rs_value[31];

assign br_taken = (   inst_beq    &&   rs_eq_rt
                   || inst_bne    &&   !rs_eq_rt
                   || inst_bgez   &&   !rs_lt_zero
                   || inst_bgtz   &&   !rs_le_zero
                   || inst_blez   &&   rs_le_zero
                   || inst_bltz   &&   rs_lt_zero
                   || inst_bltzal &&   rs_lt_zero
                   || inst_bgezal &&   !rs_lt_zero
                   || inst_jalr
                   || inst_jal
                   || inst_jr
                   || inst_j
                  ) && ds_valid && valid_br_target;

wire [31:0] bd_pc;
assign bd_pc = ds_pc + 32'd4;

assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bltzal || inst_bgezal) ? 
                                                    (bd_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr  || inst_jalr)              ? rs_value :
                  /*inst_jal*/              {bd_pc[31:28], jidx[25:0], 2'b0};

assign is_branch = inst_beq | inst_bne | inst_bgez | inst_blez | inst_bltz | inst_bgtz | inst_bgezal | inst_bltzal | inst_j | inst_jal | inst_jr | inst_jalr;

assign ds_tlbr_tlbwi = (inst_tlbr | inst_tlbwi) & ds_valid;

endmodule
