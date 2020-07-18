`define IDLE     3'b000
`define LOOKUP   3'b001
`define MISS     3'b010
`define REPLACE  3'b011
`define REFILL   3'b100


module cache(
    input           resetn, 
    input           clk,

//cache-CPU
    input           valid,
    input           op,
    input [ 7:0]    index,
    input [19:0]    tlb_tag,
    input [ 3:0]    offset,
    input [ 3:0]    wstrb,
    input [31:0]    wdata,
    output          addr_ok,
    output          data_ok,
    output[31:0]    rdata,
    
    //cache-bridge
    
    //read
    output          rd_req,
    output[ 2:0]    rd_type,
    output[31:0]    rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input [31:0]    ret_data,
                
    //write
    output          wr_req,
    output[ 2:0]    wr_type,
    output[31:0]    wr_addr,
    output[ 3:0]    wr_wstrb,
    output[127:0]   wr_data,
    input           wr_rdy    
);

reg   [2:0]	current_state;
reg   [2:0]	next_state;

//random
wire  replace_way; 
reg [ 22:0] pseudo_random_23;
always @ (posedge clk)
begin
   if (!resetn)
       pseudo_random_23 <= {7'b1010101,16'h00FF};
   else
       pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};
end
assign replace_way = pseudo_random_23[0];

reg [31:0] wdata_reg;
reg op_reg;
reg [31:0] addr_reg;
reg replace_way_reg;
reg [3:0] wstrb_reg;

wire way0_hit;
wire way1_hit;
wire cache_hit;
wire [23:0] way0_TV;
wire [23:0] way1_TV;
wire way0_v;
wire way1_v;
wire d_0;
wire d_1;
wire [19:0] way0_tag;
wire [19:0] way1_tag;
wire [31:0] way0_bank0;
wire [31:0] way0_bank1;
wire [31:0] way0_bank2;
wire [31:0] way0_bank3;
wire [31:0] way1_bank0;
wire [31:0] way1_bank1;
wire [31:0] way1_bank2;
wire [31:0] way1_bank3;
wire [31:0] way0_load_word;
wire [31:0] way1_load_word;
wire [31:0] load_res;
wire [127:0] way0_data;
wire [127:0] way1_data;
wire [127:0] replace_data;
wire dirty0_en;
wire dirty1_en;
wire [31:0] write_in_data;

wire way0_bank0_we;
wire way0_bank1_we;
wire way0_bank2_we;
wire way0_bank3_we;
wire way1_bank0_we;
wire way1_bank1_we;
wire way1_bank2_we;
wire way1_bank3_we;
wire [31:0] way0_bank0_in;
wire [31:0] way0_bank1_in;
wire [31:0] way0_bank2_in;
wire [31:0] way0_bank3_in;
wire [31:0] way1_bank0_in;
wire [31:0] way1_bank1_in;
wire [31:0] way1_bank2_in;
wire [31:0] way1_bank3_in;

wire miss_request;
wire TV0_en;
wire TV1_en;
wire [23:0] TV_in;
wire [127:0] write_buffer;
wire [3:0] offset_reg;
wire [19:0] tlb_tag_reg;


assign offset_reg = addr_reg[3:0];
assign tlb_tag_reg = addr_reg[31:12];

assign write_buffer[31:0] = (offset_reg[3:2] == 2'b00)? wdata_reg : read_buffer[31:0];
assign write_buffer[63:32] = (offset_reg[3:2] == 2'b01)? wdata_reg : read_buffer[63:32];
assign write_buffer[95:64] = (offset_reg[3:2] == 2'b10)? wdata_reg : read_buffer[95:64];
assign write_buffer[127:96] = (offset_reg[3:2] == 2'b11)? {8'hff,wdata_reg[23:0]} : read_buffer[127:96];


assign write_in_data = wdata;
assign dirty0_en = way0_hit & op & (current_state == `LOOKUP); 
assign dirty1_en = way1_hit & op & (current_state == `LOOKUP); 


assign way0_v = way0_TV[0];
assign way0_tag = way0_TV[20:1];

assign way1_v = way1_TV[0];
assign way1_tag = way1_TV[20:1];


assign way0_hit = way0_v && (way0_tag == tlb_tag_reg);
assign way1_hit = way1_v && (way1_tag == tlb_tag_reg);
assign cache_hit = way0_hit || way1_hit;

assign way0_data = {way0_bank3,way0_bank2,way0_bank1,way0_bank0};
assign way1_data = {way1_bank3,way1_bank2,way1_bank1,way1_bank0};

assign way0_load_word = way0_data[offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[offset[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word
 | {32{way1_hit}} & way1_load_word;
 
assign rdata = (cache_hit)? load_res : 32'b0 ;
 
assign way0_bank0_we = ((offset_reg[3:2] == 2'b00) & way0_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & ~replace_way_reg)) ;
assign way0_bank1_we = ((offset_reg[3:2] == 2'b01) & way0_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & ~replace_way_reg));
assign way0_bank2_we = ((offset_reg[3:2] == 2'b10) & way0_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & ~replace_way_reg));
assign way0_bank3_we = ((offset_reg[3:2] == 2'b11) & way0_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & ~replace_way_reg)); 

assign way1_bank0_we = ((offset_reg[3:2] == 2'b00) & way1_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & replace_way_reg));
assign way1_bank1_we = ((offset_reg[3:2] == 2'b01) & way1_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & replace_way_reg));
assign way1_bank2_we = ((offset_reg[3:2] == 2'b10) & way1_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & replace_way_reg));
assign way1_bank3_we = ((offset_reg[3:2] == 2'b11) & way1_hit & op_reg & (current_state == `LOOKUP)) | ( (current_state == `REFILL & replace_way_reg)); 

//assign way0_bank0_in = ((offset[3:2] == 2'b00) & way0_hit & op_reg & (current_state == `LOOKUP))? wdata : 
assign way0_bank0_in = (current_state == `LOOKUP) ?  wdata_reg : write_buffer[31:0];
assign way0_bank1_in = (current_state == `LOOKUP) ?  wdata_reg : write_buffer[63:32];
assign way0_bank2_in = (current_state == `LOOKUP) ?  wdata_reg : write_buffer[95:64];
assign way0_bank3_in = (current_state == `LOOKUP) ?  {8'hff,wdata_reg[23:0]} : write_buffer[127:96]; 

assign way1_bank0_in = (current_state == `LOOKUP) ?  wdata_reg : write_buffer[31:0];
assign way1_bank1_in = (current_state == `LOOKUP) ?  wdata_reg : write_buffer[63:32];
assign way1_bank2_in = (current_state == `LOOKUP) ?  wdata_reg : write_buffer[95:64];
assign way1_bank3_in = (current_state == `LOOKUP) ?  {8'hff,wdata_reg[23:0]} : write_buffer[127:96]; 

 
assign replace_data = replace_way_reg ? way1_data : way0_data;

assign addr_ok = ((current_state == `IDLE) | (current_state == `LOOKUP & cache_hit & ~op_reg) |
  (current_state == `LOOKUP & cache_hit & op_reg & wr_req) | (current_state == `LOOKUP & cache_hit & op_reg & ((offset[3:2]!=rd_addr[3:2]) | (offset[3:2]!=wr_addr[3:2])))) & valid;
//assign data_ok = (current_state == `LOOKUP & cache_hit) | (current_state != `IDLE & current_state != `LOOKUP & op_reg) | 
//               (current_state == `REFILL & ret_valid & ~op_reg);
assign data_ok = (current_state == `LOOKUP & cache_hit) | (current_state == `MISS  & op_reg) 
                |(current_state == `REFILL & ret_last & ~op_reg);
reg wr_req_reg;
assign rd_req = (current_state == `MISS);
assign rd_type = (current_state == `MISS)? 3'b100 : 3'b0;
assign rd_addr = addr_reg;
assign wr_req = wr_req_reg & miss_request;
//assign wr_req = wr_req_reg ;
assign wr_data =  replace_data;
assign wr_type = 3'b100;
//assign wr_addr = addr_reg;
assign wr_addr = (replace_way_reg)? {way1_tag,index,offset_reg} :  {way0_tag,index,offset_reg};
assign wr_wstrb = wstrb_reg;
assign miss_request = (replace_way_reg & way1_v & d_1) | (~replace_way_reg & way0_v & d_0);

assign TV_in ={3'b0,addr_reg[31:12],1'b1};
assign TV0_en = ~replace_way_reg  & (current_state == `REPLACE) ;
assign TV1_en = replace_way_reg & (current_state == `REPLACE);

always @(posedge clk)
begin
    if(!resetn)
    begin
        wr_req_reg <= 1'b0;
    end
    else if(wr_rdy & rd_req)
    begin
        wr_req_reg <= 1'b1;
    end
    else if(wr_rdy)
    begin
        wr_req_reg <= 1'b0;        
    end
end 

//request buffer
reg [127:0] read_buffer;
reg [1:0] count;

always @(posedge clk)
begin
    if(!resetn)
    begin
        count <= 2'b0; 
    end
    else if(ret_valid & ~ret_last)
    begin
        count <= count + 1'b1;
    end   
    else if(ret_valid & ret_last)
    begin
        count <= 2'b0;
    end
end
always @(posedge clk)
begin
    if(ret_valid && (count == 2'b00) )
    begin
        read_buffer[31:0] <= ret_data; 
    end   
    if(ret_valid && (count == 2'b01) )
    begin
        read_buffer[63:32] <= ret_data; 
    end
    if(ret_valid && (count == 2'b10) )
    begin
        read_buffer[95:64] <= ret_data; 
    end
    if(ret_valid && (count == 2'b11) )
    begin
        read_buffer[127:96] <= ret_data; 
    end            
end


always @(posedge clk)
begin
    if(wr_rdy & rd_req)
    begin
        replace_way_reg <= replace_way; 
    end   
end

always @(posedge clk)
begin
    if(!resetn)
    begin
        wdata_reg <= 32'b0;
    end
    else if(addr_ok)
    begin
        wdata_reg <= wdata; 
    end   
end 
reg ret_last_reg;
always @(posedge clk)
begin
    if(!resetn)
    begin
        ret_last_reg <= 32'b0;
    end
    else 
    begin
        ret_last_reg <= ret_last; 
    end   
end 

always @(posedge clk)
begin
    if(current_state == `IDLE)
    begin
        op_reg <= op; 
    end   
end

always @(posedge clk)
begin
    if(addr_ok)
    begin
        wstrb_reg <= wstrb; 
    end   
end

always @(posedge clk)
begin
    if(addr_ok)
    begin
        addr_reg <= {tlb_tag,index,offset}; 
    end   
end
reg [31:0] addr_use_reg;

always @(posedge clk)
begin
    if(current_state == `IDLE)
    begin
        addr_use_reg <= {tlb_tag,index,offset}; 
    end   
end
always @(posedge clk)
begin
    if(addr_ok)
    begin
        addr_reg <= {tlb_tag,index,offset}; 
    end   
end

//ram
TV_ram0 my_TV_ram0(
  .clka(clk),
  .ena(TV0_en),
  .wea(3'b111),
  .addra(index),
  .dina(TV_in),
  .douta(way0_TV)
);

TV_ram1 my_TV_ram1(
  .clka(clk),
  .ena(TV1_en),
  .wea(3'b111),
  .addra(index),
  .dina(TV_in),
  .douta(way1_TV)
);


data_ram0_bank0 my_data_ram0_bank0(
  .clka(clk),
  .ena(way0_bank0_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way0_bank0_in),
  .douta(way0_bank0)
);

data_ram0_bank1 my_data_ram0_bank1(
  .clka(clk),
  .ena(way0_bank1_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way0_bank1_in),
  .douta(way0_bank1)
);

data_ram0_bank2 my_data_ram0_bank2(
  .clka(clk),
  .ena(way0_bank2_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way0_bank2_in),
  .douta(way0_bank2)
);

data_ram0_bank3 my_data_ram0_bank3(
  .clka(clk),
  .ena(way0_bank3_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way0_bank3_in),
  .douta(way0_bank3)
);

data_ram1_bank0 my_data_ram1_bank0(
  .clka(clk),
  .ena(way1_bank0_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way1_bank0_in),
  .douta(way1_bank0)
);

data_ram1_bank1 my_data_ram1_bank1(
  .clka(clk),
  .ena(way1_bank1_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way1_bank1_in),
  .douta(way1_bank1)
);

data_ram1_bank2 my_data_ram1_bank2(
  .clka(clk),
  .ena(way1_bank2_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way1_bank2_in),
  .douta(way1_bank2)
);

data_ram1_bank3 my_data_ram1_bank3(
  .clka(clk),
  .ena(way1_bank3_we),
  .wea(4'b1111),
  .addra(index),
  .dina(way1_bank3_in),
  .douta(way1_bank3)
);

regfile d_reg0(
    .clk(clk),
    .resetn(resetn),
    .raddr(index),
    .rdata(d_0),
    .we(dirty0_en & valid),      
    .waddr(index)
);

regfile d_reg1(
    .clk(clk),
    .resetn(resetn),    
    .raddr(index),
    .rdata(d_1),
    .we(dirty1_en & valid),      
    .waddr(index)
);

//state


always@(posedge clk)
begin
	if(!resetn)
	begin
		current_state<=`IDLE;
	end
	else
	begin
		current_state <= next_state;
	end
end

always@(*)
begin
	case(current_state)

	`IDLE:
	begin
		if(valid)
			next_state=`LOOKUP;
		else
			next_state=`IDLE;
	end

	`LOOKUP:
	begin
		if(~cache_hit)
			next_state=`MISS;
		else if(valid & cache_hit)
			next_state=`LOOKUP;
		else
		    next_state=`IDLE;
	end

	`MISS:
	begin
		if(wr_rdy & rd_req)
			next_state=`REPLACE;
		else
			next_state=`MISS;
	end

	`REPLACE:
	begin
		if(ret_valid)
			next_state=`REFILL;
		else
			next_state=`REPLACE;
	end

	`REFILL:
	begin
		if(ret_last_reg)
			next_state=`IDLE;
		else
			next_state=`REFILL;
	end


	default: next_state=`IDLE; 
	endcase  
end

endmodule