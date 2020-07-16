module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

/****************************************/
wire [4:0]                   es_waddr;
wire [4:0]                   ms_waddr;
wire                         es_wen;
wire                         ms_wen;
wire                         ws_is_valid;
wire                         ms_is_valid;
wire                         es_is_valid;

wire [31:0]                  es_forward_data;
wire [31:0]                  ms_forward_data;
wire [31:0]                  ws_forward_data;
wire                         is_lw;
wire                         is_branch;
wire                         reflush  ;
wire                         ex_occur ;
wire                         ms_exc;
wire                         ws_exc;
wire                         es_mfc0_read;
wire                         ms_mfc0_read;
wire                         ws_eret;
wire [31: 0]                 epc_reg;
wire                         ms_eret;
wire                         count_eq_compare;
wire                         cp0_status_exl_reg;
wire                         cp0_status_ie_reg;
wire [7: 0]                  int_req;
wire                         es_eret;
wire                         es_exc;
/****************************************/
// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .reflush(reflush),
    .is_branch(is_branch),
    .ex_occur(ex_occur),
    .eret(ws_eret),
    .epc_reg(epc_reg)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .es_waddr       (es_waddr),
    .es_wen         (es_wen),
    .ms_waddr       (ms_waddr),
    .ms_wen         (ms_wen),
    .es_is_valid    (es_is_valid),
    .ms_is_valid    (ms_is_valid),
    .ws_is_valid    (ws_is_valid),
    //forward data
    .es_forward_data  (es_forward_data),
    .ms_forward_data  (ms_forward_data),
    .ws_forward_data  (ws_forward_data),
    .is_lw(is_lw),
    .reflush(reflush),
    .is_branch(is_branch),
    .es_mfc0_read(es_mfc0_read),
    .ms_mfc0_read(ms_mfc0_read),
    .count_eq_compare(count_eq_compare),
    .cp0_status_exl_reg(cp0_status_exl_reg),
    .cp0_status_ie_reg(cp0_status_ie_reg),
    .int_req(int_req),
    .es_eret(es_eret),
    .es_ex(es_exc),
    .ms_eret(ms_eret),
    .ms_ex(ms_exc),
    .ws_ex(ws_exc),
    .ws_eret(ws_eret)
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),

    .es_waddr       (es_waddr),
    .es_wen         (es_wen),

    .es_is_valid(es_is_valid),
    .is_lw(is_lw),
    .es_forward_data(es_forward_data),
    .reflush(reflush),
    .ms_exc(ms_exc),
    .ws_exc(ws_exc),
    .es_mfc0_read(es_mfc0_read),
    .ws_eret(ws_eret),
    .ms_eret(ms_eret),
    .es_eret(es_eret),
    .es_exc(es_exc)//output
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),

    .ms_waddr       (ms_waddr),
    .ms_wen         (ms_wen),

    .ms_is_valid(ms_is_valid),

    .ms_forward_data(ms_forward_data),
    .reflush(reflush),
    .ms_exc(ms_exc),
    .ms_mfc0_read(ms_mfc0_read),
    .ms_eret(ms_eret)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .ws_is_valid(ws_is_valid),
    .ws_forward_data(ws_forward_data),
    .reflush(reflush),
    .ex_occur(ex_occur),
    .ws_exc(ws_exc),
    .ws_eret(ws_eret),
    .epc_reg(epc_reg),
    .count_eq_compare(count_eq_compare),
    .cp0_status_exl_reg(cp0_status_exl_reg),
    .cp0_status_ie_reg(cp0_status_ie_reg),
    .int_req(int_req)
);

endmodule
