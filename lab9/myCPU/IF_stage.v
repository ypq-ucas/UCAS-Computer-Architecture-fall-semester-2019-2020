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
    // inst sram interface
    output        inst_sram_en                    ,
    output [ 3:0] inst_sram_wen                   ,
    output [31:0] inst_sram_addr                  ,
    output [31:0] inst_sram_wdata                 ,
    input  [31:0] inst_sram_rdata                 ,
    input         eret                            ,
    input  [31:0] epc_reg                         
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;

//lab8:
wire            invalid_addr_ex;
wire            if_ex          ;
wire [4: 0]     fs_excode      ;
wire            fs_bd          ;
wire [31: 0]    badvaddr       ;

assign badvaddr     = fs_pc   ;

assign fs_to_ds_bus =                    {badvaddr ,// 102:71
                                          fs_bd    ,// 70
                                          fs_excode,// 69:65
                                          if_ex   , // 64
                                          fs_inst , // 63:32
                                          fs_pc   };// 31: 0

assign fs_bd        = (if_ex) ? 1'b0 : is_branch;
                      //s_branch;
// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = (ex_occur) ? 32'hbfc00380 : 
                      (eret)     ? epc_reg      : (br_taken ? br_target : seq_pc); 

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
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
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end
/***********exception test and handler ***********/

wire [4:0]              if_excode;
assign invalid_addr_ex = (fs_pc[1: 0] != 2'b0);
assign if_ex           = (fs_valid) ? invalid_addr_ex : 1'b0 ;
assign if_excode       = (if_ex) ? 5'h04 : 5'h0; 
assign fs_excode       = (fs_valid) ? if_excode : 5'b0;

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

endmodule
