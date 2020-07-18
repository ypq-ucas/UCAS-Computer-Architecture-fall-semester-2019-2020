module mycpu_top(
    input         aclk,
    input         aresetn,
    input         int,
    // inst sram interface
    /*
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
    */
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    
    // AXI interface
    //ar
    output [3: 0]        arid       ,
    output [31:0]        araddr     ,
    output [ 7:0]        arlen      ,
    output [ 2:0]        arsize     ,
    output [ 1:0]        arburst    ,
    output [ 1:0]        arlock     ,
    output [ 3:0]        arcache    ,
    output [ 2:0]        arprot     ,
    output               arvalid    ,
    input                arready    ,
    //r
    input  [3:0]         rid        ,
    input [31:0]       rdata        ,
    input [2: 0]       rresp        ,
    input              rlast        ,
    input              rvalid       ,
    output             rready       ,

    //aw
    output [3: 0]      awid         ,
    output [31:0]      awaddr       ,
    output [7: 0]      awlen        ,
    output [2: 0]      awsize       ,
    output [1: 0]      awburst      ,
    output [1: 0]      awlock       ,
    output [3: 0]      awcache      ,
    output [2: 0]      awprot       ,
    output             awvalid      ,
    input              awready      ,

    //wdata
    output [3: 0]      wid          ,
    output [31:0]      wdata        ,
    output [3: 0]      wstrb        ,
    output             wlast        ,
    output             wvalid       ,
    input              wready       ,

    //w
    input  [3: 0]      bid          ,
    input  [1: 0]      bresp        ,
    input              bvalid       ,
    output             bready

);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

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

// inst-sram like wire:
wire                         inst_req  ;
wire                         inst_wr   ;
wire [1: 0]                  inst_size ;
wire [3: 0]                  inst_wstrb;
wire [31:0]                  inst_addr ;
wire [31:0]                  inst_wdata;
wire                         inst_addr_ok;
wire                         inst_data_ok;
wire [31:0]                  inst_rdata  ;      

// data-sram like wire:
wire                         data_req        ;
wire                         data_wr         ;
wire [2:0]                   data_size       ;
wire [31:0]                  data_addr       ;
wire [3:0]                   data_wstrb      ;
wire [31:0]                  data_wdata      ;
wire                         data_addr_ok    ;
wire [31:0]                  data_rdata      ;
wire                         data_data_ok    ;
wire                         data_read_ok    ;
wire                         is_mem_lw       ;

// tlb port:
wire [18:0]                  s0_vpn2         ;
wire                         s0_odd_page     ;
wire [7:0]                   s0_asid         ;        
wire                         s0_found        ;
wire [3:0]                   s0_index        ;
wire [19:0]                  s0_pfn          ;
wire [ 2:0]                  s0_c            ;
wire                         s0_d            ;
wire                         s0_v            ;

//tlb search port 1
    wire [18:0]              s1_vpn2         ;
    wire                     s1_odd_page     ;
    wire [7:0]               s1_asid         ;
    wire                     s1_found        ;
    wire [3:0]               s1_index        ;
    wire [19:0]              s1_pfn          ;
    wire [2:0]               s1_c            ;
    wire                     s1_d            ;
    wire                     s1_v            ;

    //write port
    wire                     we             ;
    wire  [3:0]              w_index        ;
    wire  [18:0]             w_vpn2         ;
    wire  [ 7:0]             w_asid         ;
    wire                     w_g            ;
    wire  [19:0]             w_pfn0         ;
    wire  [ 2:0]             w_c0           ;
    wire                     w_d0           ;
    wire                     w_v0           ;
    wire  [19:0]             w_pfn1         ;
    wire  [ 2:0]             w_c1           ;
    wire                     w_d1           ;
    wire                     w_v1           ;

    // read port
    wire  [3:0]              r_index        ;
    wire  [18:0]             r_vpn2         ;
    wire  [7:0]              r_asid         ;
    wire                     r_g            ;
    wire  [19:0]             r_pfn0         ;
    wire  [ 2:0]             r_c0           ;
    wire                     r_d0           ;
    wire                     r_v0           ;
    wire  [19:0]             r_pfn1         ;
    wire  [2:0]              r_c1           ;
    wire                     r_d1           ;
    wire                     r_v1           ;

    wire [31:0]              cp0_entryhi_reg ;
    wire                     is_write_entryhi;
    wire                     ds_tlbr_tlbwi   ;
    wire                     refetch        ;
    wire [31:0]              refetch_pc     ;
    wire                     ms_refetch     ;
    wire                     ws_refetch     ;
    wire                     refill_ex      ;

/****************************************/
// axi-sramlike bridge
cpu_axi_interface cpu_axi_interface0 (
    .clk            (aclk            ),
    .resetn         (aresetn         ),

    //inst-sram like:
    .inst_req       (inst_req       ),
    .inst_wr        (inst_wr        ),
    .inst_size      (inst_size      ),
    .inst_addr      (inst_addr      ),
    .inst_wstrb     (inst_wstrb     ),
    .inst_wdata     (inst_wdata     ),
    // output 
    .inst_addr_ok   (inst_addr_ok   ),
    .inst_data_ok   (inst_data_ok   ),
    .inst_rdata     (inst_rdata     ),
    
    // data-sram like:
    .data_req       (data_req       ),
    .data_wr        (data_wr        ),
    .data_size      (data_size      ),
    .data_addr      (data_addr      ),
    .data_wstrb     (data_wstrb     ),
    .data_wdata     (data_wdata     ),
    //output
    .data_addr_ok   (data_addr_ok   ),
    .data_data_ok   (data_data_ok   ),
    .data_rdata     (data_rdata     ),
    
    //ar
    .arid            (arid           ),
    .araddr          (araddr         ),
    .arlen           (arlen          ),
    .arsize          (arsize         ),
    .arburst         (arburst        ),
    .arlock          (arlock         ),
    .arcache         (arcache        ),
    .arprot          (arprot         ),
    .arvalid         (arvalid        ),
    //ar input:
    .arready         (arready        ),
    
    //r:
    .rid             (rid            ),
    .rdata           (rdata          ),
    .rresp           (rresp          ),
    .rlast           (rlast          ),
    .rvalid          (rvalid         ),
    //r output
    .rready          (rready         ),

    //aw:
    .awid            (awid           ),
    .awaddr          (awaddr         ),
    .awlen           (awlen          ),
    .awsize          (awsize         ),
    .awburst         (awburst        ),
    .awlock          (awlock         ),
    .awcache         (awcache        ),
    .awprot          (awprot         ),
    .awvalid         (awvalid        ),
    .awready         (awready        ),

    //wdata
    .wid             (wid            ),
    .wdata           (wdata          ),
    .wstrb           (wstrb          ),
    .wlast           (wlast          ),
    .wvalid          (wvalid         ),
    .wready          (wready         ),
    
    // w
    .bid             (bid            ),
    .bresp           (bresp          ),
    .bvalid          (bvalid         ),
    .bready          (bready         )

);



// IF stage
if_stage if_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    /*
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    */
    // inst-sram like interface
    .inst_sram_req(inst_req),
    .inst_sram_wr(inst_wr),
    .inst_sram_size(inst_size),
    .inst_sram_wstrb(inst_wstrb),
    .inst_sram_addr(inst_addr),
    .inst_sram_wdata(inst_wdata),
    .inst_sram_addr_ok(inst_addr_ok),
    .inst_sram_data_ok(inst_data_ok),
    .inst_sram_rdata(inst_rdata),
    
    // tlb read port:
    .s0_vpn2(s0_vpn2),
    .s0_odd_page(s0_odd_page),
    .s0_asid(s0_asid),
    // tlb read response:
    .s0_found(s0_found)     ,
    .s0_index(s0_index)     ,
    .s0_pfn(s0_pfn)         ,
    .cp0_entryhi_reg(cp0_entryhi_reg),

    .reflush(reflush),
    .is_branch(is_branch),
    .ex_occur(ex_occur),
    .eret(ws_eret),
    .epc_reg(epc_reg),
    .ds_tlbr_tlbwi(ds_tlbr_tlbwi),
    .refetch(refetch),
    .refetch_pc(refetch_pc),
    .s0_v(s0_v),

    .refill_ex(refill_ex)
);
// ID stage
id_stage id_stage(
    .clk            (aclk            ),
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
    .is_mem_lw(is_mem_lw),
    .data_read_ok(data_read_ok),
    .ds_tlbr_tlbwi(ds_tlbr_tlbwi)
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk            ),
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
    /*
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    */
    // data sram like interface
    .data_sram_req  (data_req),
    .data_sram_wr   (data_wr),
    .data_sram_size (data_size),
    .data_sram_addr (data_addr),
    .data_sram_wstrb(data_wstrb),
    .data_sram_wdata(data_wdata),
    .data_sram_addr_ok(data_addr_ok),

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
    .data_sram_data_ok(data_data_ok),

    .ms_is_valid(ms_is_valid),
    .is_write_entryhi(is_write_entryhi),

    // tlb search port 1:
    .s1_vpn2    (s1_vpn2),
    .s1_odd_page (s1_odd_page),
    .s1_asid     (s1_asid),
    .cp0_entryhi_reg(cp0_entryhi_reg),

    // tlb search port1 response:
    .s1_found   (s1_found),
    .s1_index   (s1_index),
    .s1_pfn     (s1_pfn),
    .s1_c       (s1_c),
    .s1_d       (s1_d),
    .s1_v       (s1_v),

    .ms_refetch(ms_refetch),
    .ws_refetch(ws_refetch)

);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk            ),
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
    //.data_sram_rdata(data_sram_rdata),
    .data_sram_rdata (data_rdata),
    .data_sram_data_ok(data_data_ok),

    .ms_waddr       (ms_waddr),
    .ms_wen         (ms_wen),

    .ms_is_valid(ms_is_valid),

    .ms_forward_data(ms_forward_data),
    .reflush(reflush),
    .ms_exc(ms_exc),
    .ms_mfc0_read(ms_mfc0_read),
    .ms_eret(ms_eret),
    .is_mem_lw(is_mem_lw),
    .data_read_ok(data_read_ok),
    .is_write_entryhi(is_write_entryhi),

    .ms_refetch(ms_refetch)
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk            ),
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
    .int_req(int_req),
    .cp0_entryhi_reg(cp0_entryhi_reg),
    
    .r_index(r_index),
    .r_vpn2(r_vpn2),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_pfn0(r_pfn0),
    .r_c0  (r_c0),
    .r_d0  (r_d0),
    .r_v0   (r_v0),
    .r_pfn1 (r_pfn1),
    .r_c1   (r_c1),
    .r_d1   (r_d1),
    .r_v1   (r_v1),

    .tlb_we (we),
    .w_index (w_index),
    .w_vpn2 (w_vpn2),
    .w_asid (w_asid),
    .w_g    (w_g),
    .w_pfn0 (w_pfn0),
    .w_c0   (w_c0),
    .w_d0   (w_d0),
    .w_v0   (w_v0),
    .w_pfn1  (w_pfn1),
    .w_c1    (w_c1),
    .w_d1    (w_d1),
    .w_v1    (w_v1),
    
    .ws_refetch(ws_refetch),
    .refetch(refetch),
    .refetch_pc(refetch_pc),
    .refill_ex(refill_ex)

);

// tlb module:
tlb tlb(
    .clk            (aclk)              ,
    // search port 0
    .s0_vpn2        (s0_vpn2)           ,
    .s0_odd_page    (s0_odd_page)       ,
    .s0_asid        (s0_asid)           ,
    .s0_found       (s0_found)          ,
    .s0_index       (s0_index)          ,
    .s0_pfn         (s0_pfn)            ,
    .s0_c           (s0_c)              ,
    .s0_d           (s0_d)              ,
    .s0_v           (s0_v)              ,

    //search port 1
    .s1_vpn2        (s1_vpn2)           ,
    .s1_odd_page    (s1_odd_page)       ,
    .s1_asid        (s1_asid)           ,
    .s1_found       (s1_found)          ,
    .s1_index       (s1_index)          ,
    .s1_pfn         (s1_pfn)            ,
    .s1_c           (s1_c)              ,
    .s1_d           (s1_d)              ,
    .s1_v           (s1_v)              ,

    // write port 1
    .we             (we)                ,
    .w_index        (w_index)           ,
    .w_vpn2         (w_vpn2)            ,
    .w_asid         (w_asid)            ,
    .w_g            (w_g)               ,
    .w_pfn0         (w_pfn0)            ,
    .w_c0           (w_c0)              ,
    .w_d0           (w_d0)              ,
    .w_v0           (w_v0)              ,
    .w_pfn1         (w_pfn1)            ,
    .w_c1           (w_c1)              ,
    .w_d1           (w_d1)              ,
    .w_v1           (w_v1)              ,

    // read port 
    .r_index        (r_index)           ,
    .r_vpn2         (r_vpn2)            ,
    .r_asid         (r_asid)            ,
    .r_g            (r_g)               ,
    .r_pfn0         (r_pfn0)            ,
    .r_c0           (r_c0)              ,
    .r_d0           (r_d0)              ,
    .r_v0           (r_v0)              ,
    .r_pfn1         (r_pfn1)            ,
    .r_c1           (r_c1)              ,
    .r_d1           (r_d1)              ,
    .r_v1           (r_v1)  
);

endmodule
