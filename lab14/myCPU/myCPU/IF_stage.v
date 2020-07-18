`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    input                          reflush        ,
    input                          ex_occur       ,
    input                          is_branch      ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,

    input                           refetch       ,
    input [31:0]                    refetch_pc    ,
    // inst sram interface
    /*
    output        inst_sram_en                    ,
    output [ 3:0] inst_sram_wen                   ,
    output [31:0] inst_sram_addr                  ,
    output [31:0] inst_sram_wdata                 ,
    input  [31:0] inst_sram_rdata                 ,
    */
    // sram like interface
    output        inst_sram_req                   ,
    output        inst_sram_wr                    ,
    output [ 1:0] inst_sram_size                  ,
    output [ 3:0] inst_sram_wstrb                 ,
    output [31:0] inst_sram_addr                  ,
    output [31:0] inst_sram_wdata                 ,
    // tlb read port0:
    output [18:0]       s0_vpn2                   ,
    output              s0_odd_page               ,
    output [7: 0]       s0_asid                   ,


    // tlb read port 0 input:
    input               s0_found                  ,
    input  [ 3:0]       s0_index                  ,
    input  [19:0]       s0_pfn                    ,
    input               s0_v                      ,

    input  [31:0]       cp0_entryhi_reg           ,

    
    input         inst_sram_addr_ok               ,
    input         inst_sram_data_ok               ,
    input  [31:0] inst_sram_rdata                 ,

    input         eret                            ,
    input  [31:0] epc_reg                         ,
    input         ds_tlbr_tlbwi                   ,
    input         refill_ex     
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        fs_refetch;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_target} = br_bus;

wire [31:0] fs_inst;
wire        tlb_refill   ;
wire        tlb_invalid  ;
reg  [31:0] fs_pc;
//wire        tlb_ex       ;

wire        fs_mapped       ;
wire        fs_tlb_refill   ;
wire        fs_tlb_invalid  ;

reg         fs_s0_found_reg ;
reg         fs_s0_v_reg     ;
reg         tlb_ex          ;


//lab8:
wire            invalid_addr_ex;
wire            if_ex          ;
wire [4: 0]     fs_excode      ;
wire            fs_bd          ;
wire [31: 0]    badvaddr       ;
wire [31:0]     true_npc       ;
wire [31:0]     true_fs_pc     ;
wire [31:0]     true_phy_pc    ;

assign badvaddr     = fs_pc    ;

assign fs_to_ds_bus =                    {fs_tlb_refill  ,// 136
                                          fs_refetch ,// 135
                                          true_fs_pc ,// 134:103
                                          badvaddr ,// 102:71
                                          fs_bd    ,// 70
                                          fs_excode,// 69:65
                                          if_ex   , // 64
                                          fs_inst , // 63:32
                                          fs_pc };// 31: 0

assign fs_bd        = (if_ex) ? 1'b0 : is_branch;


// pre-IF stage
assign to_fs_valid  = ~reset & (inst_sram_addr_ok | tlb_refill | tlb_invalid);
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = (ex_occur & ~refill_ex) ? 32'hbfc00380 :
                      (ex_occur &  refill_ex) ? 32'hbfc00200 :
                      (eret)     ? epc_reg      : 
                      (refetch)  ? refetch_pc   : (br_taken ? br_target : seq_pc); 

wire   mapped;


reg [31:0]      ex_addr_buf;
reg             ex_addr_buf_valid;

// IF stage
assign fs_ready_go    = (inst_sram_data_ok | rinst_buf_valid | tlb_ex) ;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~cancle ;

reg     cancle;

always@(posedge clk) begin
    if(reset) begin
        cancle <= 1'b0;
    end
    else if(~ex_addr_buf_valid && inst_sram_data_ok) begin
        cancle <= 1'b0;
    end 
    else if(ex_occur || eret || refetch) begin
        cancle <= 1'b1;
    end
end





always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    //else if (reflush) begin
    //    fs_valid <= 1'b0;
    //end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (fs_allowin && to_fs_valid) begin
        fs_pc <= true_npc;
    end
end
/***********exception test and handler ***********/

wire [4:0]              if_excode;
assign invalid_addr_ex = (fs_pc[1: 0] != 2'b0)             ;

assign if_ex           = (fs_valid) ? (invalid_addr_ex | fs_tlb_refill | fs_tlb_invalid) : 1'b0 ;

assign if_excode       = (if_ex & invalid_addr_ex) ? 5'h04 : 
                         (if_ex & fs_tlb_refill)      ? 5'h02 :
                         (if_ex & fs_tlb_invalid)     ? 5'h02 : 5'h0;

assign fs_excode       = (fs_valid) ? if_excode : 5'b0       ;

assign true_fs_pc      = (fs_valid) ? fs_pc : true_npc       ;

/*
assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
*/

/*********************** lab11 *********************/

reg [31:0]      branch_buf;
reg             branch_buf_valid;

always@(posedge clk) begin
    if(reset) begin
        branch_buf_valid <= 1'b0;
    end
    else if(br_taken) begin
        branch_buf_valid <= 1'b1;
    end
    else if(branch_buf_valid && !buf_valid) begin
        branch_buf_valid <= 1'b0;
    end

    if(br_taken) begin
        branch_buf <= br_target;
    end
end



always@(posedge clk) begin
    if(reset) begin
        ex_addr_buf_valid <= 1'b0;
    end
    else if(ex_occur || eret || refetch) begin
        ex_addr_buf_valid <= 1'b1;
    end
    else if(ex_addr_buf_valid && !buf_valid) begin
        ex_addr_buf_valid <= 1'b0;
    end

    if(ex_occur && !refill_ex) begin
        ex_addr_buf <= 32'hbfc00380;
    end
    else if(ex_occur && refill_ex) begin
        ex_addr_buf <= 32'hbfc00200;
    end
    else if(eret) begin
        ex_addr_buf <= epc_reg;
    end
    else if(refetch) begin
        ex_addr_buf <= refetch_pc;
    end
end
    



reg             buf_valid;
reg [31:0]      buf_npc  ;

always@(posedge clk) begin
    if(reset) begin
        buf_valid <= 1'b0;
    end
    else if(to_fs_valid && fs_allowin) begin
        buf_valid <= 1'b0;
    end
    else if(!buf_valid) begin
        buf_valid <= 1'b1;
    end
    
    if(!buf_valid) begin
        if(ex_addr_buf_valid) begin
            buf_npc <= ex_addr_buf;
        end
        else if(branch_buf_valid) begin
            buf_npc <= branch_buf;
        end
        else begin
            buf_npc <= nextpc;
        end
    end
end

assign s0_vpn2     = true_npc [31:13];
assign s0_odd_page = true_npc[12];
assign s0_asid     = cp0_entryhi_reg[7:0];
assign mapped      = !(true_npc[31:29] == 3'b100 || true_npc[31:29] == 3'b101);

assign true_npc = buf_valid ? buf_npc : nextpc;

assign true_phy_pc = (true_npc[31:29] == 3'b100 || true_npc[31:29] == 3'b101) ? {3'b0,true_npc[28:0]}:
                     (s0_found) ? {s0_pfn, true_npc[11:0]} : true_npc;


assign tlb_refill  = mapped & ~s0_found;
assign tlb_invalid = mapped & s0_found & ~s0_v;


assign inst_sram_addr = true_phy_pc;



reg             inst_req_reg;

always@(posedge clk) begin
    if(reset) begin
        inst_req_reg <= 1'b0;
    end
    else if(inst_req_reg && inst_sram_addr_ok) begin
        inst_req_reg <= 1'b0;
    end
    else if(fs_allowin) begin
        inst_req_reg <= 1'b1;
    end
end
//assign inst_sram_req = inst_req_reg ;
reg    handshake;

assign inst_sram_req = fs_allowin & ~handshake & (~reset) & (~tlb_refill) & (~tlb_invalid);

always@(posedge clk) begin
    if(reset) begin
        handshake <= 1'b0;
    end
    else if(inst_sram_addr_ok) begin
        handshake <= 1'b1;
    end
    else if(inst_sram_data_ok) begin
        handshake <= 1'b0;
    end
end




assign inst_sram_wr  = 1'b0         ;
assign inst_sram_size = 2'b10       ;
assign inst_sram_wstrb = 4'h0       ;
assign inst_sram_wdata = 32'b0      ;


reg             rinst_buf_valid ;
reg  [31: 0]    rinst_buf       ;
wire [31: 0]    true_inst       ;

always@(posedge clk) begin
    if(reset) begin
        rinst_buf_valid <= 1'b0;
    end
    else if(fs_to_ds_valid && ds_allowin) begin
        rinst_buf_valid <= 1'b0;
    end
    else if(!rinst_buf_valid && inst_sram_data_ok && !cancle) begin
        rinst_buf_valid <= 1'b1;
    end

    if(!rinst_buf_valid && inst_sram_data_ok && !cancle) begin
        rinst_buf <= inst_sram_rdata;
    end
end


assign fs_inst         = rinst_buf_valid ? rinst_buf : inst_sram_rdata;

//assign fs_refetch      = ds_tlbr_tlbwi | es_tlbr_tlbwi | ms_tlbr_tlbwi | ws_tlbr_tlbwi;

reg refetch_reg;

always@(posedge clk) begin
    if(reset) begin
        refetch_reg <= 1'b0;
    end
    else if(refetch_reg && inst_sram_data_ok && !cancle) begin
        refetch_reg <= 1'b0;
    end
    else if(ds_tlbr_tlbwi) begin
        refetch_reg <= 1'b1;
    end
end

assign fs_refetch = (rinst_buf_valid != 1'b1) ? refetch_reg : ds_tlbr_tlbwi;

/*
always@(posedge clk) begin
    if(reset) begin
        fs_tlb_refill <= 1'b0;
    end
    else if(fs_tlb_refill && reflush) begin
        fs_tlb_refill <= 1'b0;
    end
    else if(tlb_refill && fs_allowin) begin
        fs_tlb_refill <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        fs_tlb_invalid <= 1'b0;
    end
    else if(fs_tlb_invalid && reflush) begin
        fs_tlb_invalid <= 1'b0;
    end
    else if(tlb_invalid && fs_allowin) begin
        fs_tlb_invalid <= 1'b1;
    end
end
*/

always@(posedge clk) begin
    if(reset) begin
        tlb_ex <= 1'b0;
    end
    else if((tlb_invalid || tlb_refill) && fs_allowin) begin
        tlb_ex <= 1'b1;
    end
    else if(tlb_ex && reflush) begin
        tlb_ex <= 1'b0;
    end
end


assign fs_mapped   =  !(fs_pc[31:29] == 3'b100 || fs_pc[31:29] == 3'b101);
always@(posedge clk) begin
    if(reset) begin
        fs_s0_found_reg <= 1'b0;
        fs_s0_v_reg     <= 1'b0;
    end
    else if(fs_allowin && to_fs_valid) begin
        fs_s0_found_reg <= s0_found;
        fs_s0_v_reg     <= s0_v;
    end
end

assign fs_tlb_refill    = fs_mapped & ~fs_s0_found_reg;
assign fs_tlb_invalid   = fs_mapped &  fs_s0_found_reg & ~fs_s0_v_reg;







endmodule
