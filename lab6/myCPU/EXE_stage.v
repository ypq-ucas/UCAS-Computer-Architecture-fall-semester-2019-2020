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
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    
    //dest
    output [4:0] es_dest,
    output es_val,
    output es_gr_we,
    output [31:0] es_result,
    
    output es_res_from_mem
);

reg         es_valid      ;
wire        es_ready_go   ;


assign es_val = es_valid;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src1_is_rs_part;
wire        es_src2_is_imm; 
wire        es_src2_is_imm_zero;
wire        es_src2_is_8  ;

wire        es_mem_we     ;

wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire es_div;
wire es_divu;
wire es_mthi;
wire es_mtlo;
wire es_mfhi;
wire es_mflo;
wire es_mult;
wire es_multu;


reg [31:0] hi;
reg [31:0] lo;

wire [63:0] unsigned_prod;
wire [63:0] signed_prod;

assign {es_multu,         //145:145
        es_mult,         //144:144
        es_mflo,         //143:143
        es_mfhi,         //142:142
        es_mtlo,         //141:141
        es_mthi,         //140:140
        es_divu,         //139:139
        es_div,         //138:138
        es_src1_is_rs_part ,  //137:137
        es_src2_is_imm_zero ,  //136:136
        es_alu_op      ,  //135:124
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


assign es_result = (es_mfhi) ? hi :
                   (es_mflo) ? lo :  es_alu_result;


assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result  ,  //63:32
                       es_pc             //31:0
                      };
                      
                      
wire signed_dout_tvalid;
wire unsigned_dout_tvalid;
assign es_ready_go    = (~(es_div | es_divu)) | (signed_dout_tvalid & es_div) | (unsigned_dout_tvalid & es_divu);
//assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
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
                     es_src1_is_rs_part ? {27'b0, es_rs_value[4:0]} :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_8   ? 32'd8 :
                     es_src2_is_imm_zero ? {16'b0, es_imm[15:0]} :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );
   
reg [5:0] count;
   

   
   
   
    
//signed div
reg signed_divisor_tvalid;
wire signed_divisor_tready;
wire [31:0] signed_divisor_tdata;
reg signed_dividend_tvalid;
wire signed_dividend_tready;
wire [31:0] signed_dividend_tdata;

wire [63:0] signed_div_result;

assign signed_divisor_tdata = es_alu_src2;
assign signed_dividend_tdata = es_alu_src1;
always @(posedge clk)
    begin
        if(reset) begin
            signed_divisor_tvalid <= 1'b0;
            //divisor_tready = 1'b0;
            signed_dividend_tvalid <= 1'b0;
            //dividend_tready = 1'b0;
        end
        else
        begin
            signed_divisor_tvalid <= es_div & ~signed_divisor_tready & ~signed_dividend_tready & (count == 0);
            signed_dividend_tvalid <= es_div & ~signed_divisor_tready & ~signed_dividend_tready & (count == 0);
        end
    end

mydiv_signed u_mydiv_signed(
    .aclk                       (clk),
    .s_axis_divisor_tvalid      (signed_divisor_tvalid),
    .s_axis_divisor_tready      (signed_divisor_tready),
    .s_axis_divisor_tdata       (signed_divisor_tdata),
    .s_axis_dividend_tvalid     (signed_dividend_tvalid),
    .s_axis_dividend_tready     (signed_dividend_tready),
    .s_axis_dividend_tdata      (signed_dividend_tdata),
    .m_axis_dout_tvalid         (signed_dout_tvalid),
    .m_axis_dout_tdata          (signed_div_result)
    
    );
    
    
    
   
//unsigned div
reg unsigned_divisor_tvalid;
wire unsigned_divisor_tready;
wire [31:0] unsigned_divisor_tdata;
reg unsigned_dividend_tvalid;
wire unsigned_dividend_tready;
wire [31:0] unsigned_dividend_tdata;

wire [63:0] unsigned_div_result;


assign unsigned_divisor_tdata = es_alu_src2;
assign unsigned_dividend_tdata = es_alu_src1;
always @(posedge clk)
    begin
        if(reset) begin
            unsigned_divisor_tvalid <= 1'b0;
            //divisor_tready = 1'b0;
            unsigned_dividend_tvalid <= 1'b0;
            //dividend_tready = 1'b0;
        end
        else
        begin
            unsigned_divisor_tvalid <= es_divu & ~unsigned_divisor_tready & ~unsigned_dividend_tready & (count == 0);
            unsigned_dividend_tvalid <= es_divu & ~unsigned_divisor_tready & ~unsigned_dividend_tready & (count == 0);
        end
    end

mydiv_unsigned u_mydiv_unsigned(
    .aclk                       (clk),
    .s_axis_divisor_tvalid      (unsigned_divisor_tvalid),
    .s_axis_divisor_tready      (unsigned_divisor_tready),
    .s_axis_divisor_tdata       (unsigned_divisor_tdata),
    .s_axis_dividend_tvalid     (unsigned_dividend_tvalid),
    .s_axis_dividend_tready     (unsigned_dividend_tready),
    .s_axis_dividend_tdata      (unsigned_dividend_tdata),
    .m_axis_dout_tvalid         (unsigned_dout_tvalid),
    .m_axis_dout_tdata          (unsigned_div_result)
    
    );    
    
    
    
    
    
    
    
    
    
    
always@(posedge clk)
    begin
       if(es_mthi)
       begin
            hi <= es_rs_value;
       end
       else if(es_div & signed_dout_tvalid)
       begin
            hi <= signed_div_result[31:0];
       end
       else if(es_divu & unsigned_dout_tvalid)
       begin
            hi <= unsigned_div_result[31:0];        
       end
       else if(es_mult)
       begin
            hi <= signed_prod[63:32];
       end
       else if(es_multu)
       begin
            hi <= unsigned_prod[63:32];
       end         
    end


always@(posedge clk)
    begin
       if(es_mtlo)
       begin
            lo <= es_rs_value;
       end
       else if(es_div & signed_dout_tvalid)
       begin
            lo <= signed_div_result[63:32];
       end
       else if(es_divu & unsigned_dout_tvalid)
       begin
            lo <= unsigned_div_result[63:32];
       end
       else if(es_mult)
       begin
            lo <= signed_prod[31:0];
       end
       else if(es_multu)
       begin
            lo <= unsigned_prod[31:0];
       end               
    end





always@ (posedge clk)
    begin
        if(reset) begin
            count<=0;
        end
        else if(signed_dout_tvalid | unsigned_dout_tvalid)
        begin
             count<=0;
        end
        else if( (es_div & signed_divisor_tready) | (es_divu & unsigned_divisor_tready) )
        begin
            count <= count + 1;
        end
        else
        begin
            count <= count;
        end
    end
      
   

assign unsigned_prod = es_alu_src1 * es_alu_src2;
assign signed_prod = $signed(es_alu_src1) * $signed(es_alu_src2);





assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rt_value;

endmodule
