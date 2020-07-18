module cpu_axi_interface(
    input        clk                 ,
    input        resetn             ,  

    //指令sram
    input              inst_req      ,
    input              inst_wr       ,
    input [1: 0]       inst_size     ,
    input [31:0]       inst_addr     ,
    input [3: 0]       inst_wstrb    ,
    input [31:0]       inst_wdata    ,
    //这三个信号将作为返回值返回给inst sram的类sram接口

    output             inst_addr_ok  ,
    output             inst_data_ok  ,
    output[31:0]       inst_rdata    ,

    //数据sram
    input              data_req      ,
    input              data_wr       ,
    input [2: 0]       data_size     ,
    input [31:0]       data_addr     ,
    input [3: 0]       data_wstrb    ,
    input [31:0]       data_wdata    ,

    //这三个信号将作为返回值返回给inst sram的类sram接口
    output             data_addr_ok  ,
    output             data_data_ok  ,
    output[31:0]       data_rdata    ,

    //AXI总线的相关信�??????????????????????????
    //读请求�?�道，以ar�??????????????????????????�??????????????????????????
    output [3: 0]      arid         ,
    output [31:0]      araddr       ,
    output [7: 0]      arlen        ,//固定�??????????????????????????0
    output [2: 0]      arsize       ,
    output [1: 0]      arburst      ,//固定�??????????????????????????2'b01
    output [1: 0]      arlock       ,//固定�??????????????????????????0
    output [3: 0]      arcache      ,//固定�??????????????????????????0
    output [2: 0]      arprot       ,//固定�??????????????????????????0
    output             arvalid      ,
    input              arready      ,

    //读响应�?�道，以r�??????????????????????????�??????????????????????????
    input [3: 0]       rid          ,
    input [31:0]       rdata        ,
    input [2: 0]       rresp        ,
    input              rlast        ,
    input              rvalid       ,
    output             rready       ,

    //写请求�?�道，以aw�??????????????????????????�??????????????????????????
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

    //写数据�?�道,以w�??????????????????????????�??????????????????????????
    output [3: 0]      wid          ,
    output [31:0]      wdata        ,
    output [3: 0]      wstrb        ,
    output             wlast        ,
    output             wvalid       ,
    input              wready       ,
    
    //写响应�?�道，以b�??????????????????????????�??????????????????????????
    input  [3: 0]      bid          ,
    input  [1: 0]      bresp        ,
    input              bvalid       ,
    output             bready

);

assign arlen                = 1'b0  ;
assign arburst              = 2'b01 ;
assign arlock               = 2'b0  ;
assign arcache              = 4'b0  ;
assign arprot               = 3'b0  ;
assign awid                 = 4'h1  ;
assign awlen                = 7'b0  ;
assign awburst              = 2'b01 ;
assign awlock               = 2'b0  ;
assign awcache              = 4'b0  ;
assign awprot               = 3'b0  ;
assign wid                  = 4'h1  ;
assign wlast                = 1'b1  ;

wire    data_write_addr_ok;
wire    data_read_addr_ok ;
wire    data_write_data_ok;
wire    data_read_data_ok ;

reg     ar_handshake;
reg     data_write  ;
reg [31:0]    inst_addr_reg;
reg [1: 0]    inst_size_reg;
reg [1: 0]    data_read_size;

reg[31: 0]     raddr_reg;

always@(posedge clk) begin
    
    if(~resetn) begin
        ar_handshake <= 1'b0;
    end
    else if(arvalid && arready) begin
        ar_handshake <= 1'b1;
    end
    else if(rready && rvalid) begin
        ar_handshake <= 1'b0;
    end

end

reg     inst_read;

always@(posedge clk) begin
    if(~resetn) begin
        inst_read <= 1'b0;
    end
    else if(~inst_read && inst_req && ~inst_wr && ~data_req && ~data_read && ~data_write) begin
        inst_read <= 1'b1;
    end
    else if(inst_read && rready && rvalid) begin
        inst_read <= 1'b0;
    end
end

reg     data_read;

always@(posedge clk) begin
    if(~resetn) begin
        data_read <= 1'b0;
    end
    else if(~data_read && data_req && ~data_wr && ~inst_read && ~data_write)  begin
        data_read <= 1'b1;
    end
    else if(data_read && rready && rvalid) begin
        data_read <= 1'b0;
    end
end

assign arid   =     data_read ? 4'h1 :
                    inst_read ? 4'h0 : 4'h2 ;

assign arvalid  =  ( data_read | inst_read ) & ~ar_handshake & ~data_write;
assign rready   =  ( data_read | inst_read ) &  ar_handshake & ~data_write;

assign araddr   =   data_read ? raddr_reg : 
                    inst_read ? inst_addr_reg : 32'b0;
                    
assign arsize   =   data_read ? {1'b0 ,data_read_size} :
                    inst_read ? {1'b0, inst_size_reg } : 3'b0;

assign inst_addr_ok  =  ~inst_read & ~data_write & ~data_read & inst_req & ~inst_wr & ~data_req;
assign inst_data_ok  =  inst_read & rready & rvalid  & (rid == 4'h0)    ;
assign inst_rdata    =  rdata ;
assign data_rdata    =  rdata ;


always@(posedge clk) begin
    if(~resetn) begin
        inst_addr_reg <= 32'b0;
    end
    else if(inst_addr_ok) begin
        inst_addr_reg <= inst_addr;
    end
end


always@(posedge clk) begin
    if(~resetn) begin
        data_write <= 1'b0;
    end
    else if(~data_write && data_req && data_wr && ~data_read && ~inst_read) begin
        data_write <= 1'b1;
    end
    else if(data_write && bready && bvalid) begin
        data_write <= 1'b0;
    end
end

reg     aw_handshake ;

always@(posedge clk) begin
    if(~resetn) begin
        aw_handshake <= 1'b0;
    end
    else if(awvalid && awready) begin
        aw_handshake <= 1'b1;
    end
    else if(bready && bvalid) begin
        aw_handshake <= 1'b0;
    end
end

reg    wdata_handshake ;

always@(posedge clk) begin
    if(~resetn) begin
        wdata_handshake <= 1'b0;
    end
    else if(wvalid && wready) begin
        wdata_handshake <= 1'b1;
    end
    else if(bready && bvalid) begin
        wdata_handshake <= 1'b0;
    end
end


reg   data_write_addr_ok_reg;
reg   data_read_addr_ok_reg;
reg [31: 0]    wdata_reg;
reg [31: 0]    waddr_reg;
reg [2:  0]    data_size_reg; 
/*
always@(posedge clk) begin
    if(~resetn) begin
        data_write_addr_ok_reg <= 1'b0;
    end
    else if(awvalid && awready) begin
        data_write_addr_ok_reg <= 1'b0;
    end
    else begin
        data_write_addr_ok_reg <= awready & ~aw_handshake;
    end
end

always@(posedge clk) begin
    if(~resetn) begin
        data_read_addr_ok_reg <= 1'b0;
    end
    else if(rready && rvalid) begin
        data_read_addr_ok_reg <= 1'b0;
    end
    else begin 
        data_read_addr_ok_reg <= arready & ~ar_handshake;
    end
end
*/

assign awvalid  =  data_write & ~aw_handshake ;
assign wvalid   =  data_write & ~wdata_handshake ;
assign bready   =  data_write & wdata_handshake ;

//assign data_write_addr_ok   =   data_write & data_write_addr_ok_reg & data_req & data_wr;
//assign data_read_addr_ok    =   data_read  & data_read_addr_ok_reg & data_req & ~data_wr;
assign data_write_addr_ok   =   ~data_write & ~data_read & ~inst_read & data_req & data_wr;
assign data_read_addr_ok    =   ~data_read  & ~data_write & ~inst_read & data_req & ~data_wr;
assign data_addr_ok         =   data_write_addr_ok | data_read_addr_ok ;

assign data_write_data_ok   =   data_write & bready & bvalid    ;
assign data_read_data_ok    =   data_read  & rready & rvalid  & (rid == 4'h1);
assign data_data_ok         =   (data_write & data_write_data_ok) | (data_read & data_read_data_ok) ;

/*
assign wstrb        = (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b00)?  4'b1111: //swr && sw
                      (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b01)?  4'b1110:
                      (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b10)?  4'b1100:
                      (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b11)?  4'b1000:
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b00)?  4'b0001: //swl
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b01)?  4'b0011:
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b10)?  4'b0111:
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b11)?  4'b1111:
                      (data_size_reg == 3'b001 && waddr_reg[1:0] == 2'b00)?  4'b0011: // other
                      (data_size_reg == 3'b001 && waddr_reg[1:0] == 2'b10)?  4'b1100:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b00)?  4'b0001:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b01)?  4'b0010:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b10)?  4'b0100:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b11)?  4'b1000 : 4'b0000;                                                                     4'b0000;  
*/
assign wstrb        = (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b00)?  4'b1111: 
                      (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b01)?  4'b1110:
                      (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b10)?  4'b1100:
                      (data_size_reg == 3'b010 && waddr_reg[1:0] == 2'b11)?  4'b1000:
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b00)?  4'b0001: 
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b01)?  4'b0011:
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b10)?  4'b0111:
                      (data_size_reg == 3'b110 && waddr_reg[1:0] == 2'b11)?  4'b1111:
                      (data_size_reg == 3'b001 && waddr_reg[1:0] == 2'b00)?  4'b0011: 
                      (data_size_reg == 3'b001 && waddr_reg[1:0] == 2'b10)?  4'b1100:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b00)?  4'b0001:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b01)?  4'b0010:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b10)?  4'b0100:
                      (data_size_reg == 3'b000 && waddr_reg[1:0] == 2'b11)?  4'b1000 : 4'b0000;


always@(posedge clk) begin
    if(~resetn) begin
        wdata_reg <= 32'b0;
    end
    else if(data_write_addr_ok) begin
        wdata_reg <= data_wdata;
    end
end

always@(posedge clk) begin
    if(~resetn) begin
        waddr_reg <= 32'b0;
    end
    else if(data_write_addr_ok) begin
        waddr_reg <= data_addr;
    end
end

always@(posedge clk) begin
    if(~resetn) begin
        raddr_reg <= 32'b0;
    end
    else if(data_read_addr_ok) begin
        raddr_reg <= data_addr;
    end
end

always@(posedge clk) begin
    if(~resetn) begin
        data_size_reg <= 3'b0;
    end
    else if(data_write_addr_ok) begin
        data_size_reg <= data_size;
    end
end

always@(posedge clk) begin
    if(~resetn) begin
        inst_size_reg <= 2'b0;
    end
    else if(inst_addr_ok) begin
        inst_size_reg <= inst_size;
    end
end

always@(posedge clk) begin
    if(~resetn) begin
        data_read_size <= 2'b0;
    end
    else if(data_read_addr_ok) begin
        data_read_size <= data_size[1:0];
    end
end

assign wdata = wdata_reg;
assign awaddr = waddr_reg;
assign awsize = data_size_reg;




endmodule










