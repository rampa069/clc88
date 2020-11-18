`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    vga_char 
// Descriptin:     ROM中存储了2个字体，字体大小为56*75,字体显示为单色             
//////////////////////////////////////////////////////////////////////////////////
module vga_char(
			input clk,
			input reset_n,
			output vga_hs,
			output vga_vs,
			output [4:0] vga_r,
			output [5:0] vga_g,
			output [4:0] vga_b

    );
//-----------------------------------------------------------//
// 水平扫描参数的设定1024*768 60Hz VGA
//-----------------------------------------------------------//
//parameter LinePeriod =1344;            //行周期数
//parameter H_SyncPulse=136;             //行同步脉冲（Sync a）
//parameter H_BackPorch=160;             //显示后沿（Back porch b）
//parameter H_ActivePix=1024;            //显示时序段（Display interval c）
//parameter H_FrontPorch=24;             //显示前沿（Front porch d）
//parameter Hde_start=296;
//parameter Hde_end=1320;

// Hde_start = H_SyncPulse+H_BackPorch
// Hde_end   = H_SyncPulse+H_BackPorch + H_ActivePix
// LinePeriod = Hde_end + H_FrontPorch

//-----------------------------------------------------------//
// 垂直扫描参数的设定1024*768 60Hz VGA
//-----------------------------------------------------------//
//parameter FramePeriod =806;           //列周期数
//parameter V_SyncPulse=6;              //列同步脉冲（Sync o）
//parameter V_BackPorch=29;             //显示后沿（Back porch p）
//parameter V_ActivePix=768;            //显示时序段（Display interval q）
//parameter V_FrontPorch=3;             //显示前沿（Front porch r）
//parameter Vde_start=35;
//parameter Vde_end=803;

//-----------------------------------------------------------//
// 水平扫描参数的设定800*600 VGA
//-----------------------------------------------------------//
parameter LinePeriod =1056;           //行周期数
parameter H_SyncPulse=128;            //行同步脉冲（Sync a）
parameter H_BackPorch=88;             //显示后沿（Back porch b）
parameter H_ActivePix=800;            //显示时序段（Display interval c）
parameter H_FrontPorch=40;            //显示前沿（Front porch d）
parameter Hde_start=216;
parameter Hde_end=1016;

//-----------------------------------------------------------//
// 垂直扫描参数的设定800*600 VGA
//-----------------------------------------------------------//
parameter FramePeriod =628;           //列周期数
parameter V_SyncPulse=4;              //列同步脉冲（Sync o）
parameter V_BackPorch=23;             //显示后沿（Back porch p）
parameter V_ActivePix=600;            //显示时序段（Display interval q）
parameter V_FrontPorch=1;             //显示前沿（Front porch r）
parameter Vde_start=27;
parameter Vde_end=627;

  reg[10 : 0] x_cnt;
  reg[9 : 0]  y_cnt;
  reg hsync_r;
  reg vsync_r; 
  reg hsync_de;
  reg vsync_de;
  
  
  wire vga_clk;
  wire CLK_OUT1;
  wire CLK_OUT2;
  wire CLK_OUT3;
  wire CLK_OUT4; 
  
parameter	Pos_X1	=	500;        //第一个字在VGA上显示的X坐标
parameter	Pos_Y1	=	300;        //第一个字在VGA上显示的Y坐标

parameter	Pos_X2	=	650;        //第二个字在VGA上显示的X坐标
parameter	Pos_Y2	=	300;        //第二个字在VGA上显示的Y坐标
 
//----------------------------------------------------------------
////////// 水平扫描计数
//----------------------------------------------------------------
always @ (posedge vga_clk)
       if(~reset_n)    x_cnt <= 1;
       else if(x_cnt == LinePeriod) x_cnt <= 1;
       else x_cnt <= x_cnt+ 1;
		 
//----------------------------------------------------------------
////////// 水平扫描信号hsync,hsync_de产生
//----------------------------------------------------------------
always @ (posedge vga_clk)
   begin
       if(~reset_n) hsync_r <= 1'b1;
       else if(x_cnt == 1) hsync_r <= 1'b0;            //产生hsync信号
       else if(x_cnt == H_SyncPulse) hsync_r <= 1'b1;
		 
		 		 
	    if(~reset_n) hsync_de <= 1'b0;
       else if(x_cnt == Hde_start) hsync_de <= 1'b1;    //产生hsync_de信号
       else if(x_cnt == Hde_end) hsync_de <= 1'b0;	
	end

//----------------------------------------------------------------
////////// 垂直扫描计数
//----------------------------------------------------------------
always @ (posedge vga_clk)
       if(~reset_n) y_cnt <= 1;
       else if(y_cnt == FramePeriod) y_cnt <= 1;
       else if(x_cnt == LinePeriod) y_cnt <= y_cnt+1;

//----------------------------------------------------------------
////////// 垂直扫描信号vsync, vsync_de产生
//----------------------------------------------------------------
always @ (posedge vga_clk)
  begin
       if(~reset_n) vsync_r <= 1'b1;
       else if(y_cnt == 1) vsync_r <= 1'b0;    //产生vsync信号
       else if(y_cnt == V_SyncPulse) vsync_r <= 1'b1;
		 
	    if(~reset_n) vsync_de <= 1'b0;
       else if(y_cnt == Vde_start) vsync_de <= 1'b1;    //产生vsync_de信号
       else if(y_cnt == Vde_end) vsync_de <= 1'b0;	 
  end	 

//----------------------------------------------------------------
////////// ROM读字地址产生模块
//----------------------------------------------------------------

parameter state_read_text_a = 0;
parameter state_read_font_a = 2;
parameter state_write_font_a = 4;
parameter state_read_text_b = 8;
parameter state_read_font_b = 10;
parameter state_write_font_b = 12;
parameter state_read_text_end = 15;

reg[10:0] text_rom_addr;
reg[10:0] font_rom_addr;
reg[7:0] font_reg_a;
reg[7:0] font_reg_b;
reg use_font_a;

reg[3:0] read_rom_state;
reg [2:0] font_scan;

wire text_rom_read;
assign text_rom_read = (x_cnt >= Hde_start-4 && x_cnt < Hde_end-4 && vsync_de) ? 1'b1 : 1'b0;

// state machine to read char or font from rom
always @(posedge vga_clk)
begin
	if(text_rom_read) begin
		if (read_rom_state == state_read_text_a || read_rom_state == state_read_text_b)
			text_rom_addr <= text_rom_addr;
		else if (read_rom_state == state_read_font_a || read_rom_state == state_read_font_b)
			font_rom_addr <= {1'b1, y_cnt[2:0]};
		else if (read_rom_state == state_write_font_a)
			font_reg_a <= {rom_data};
		else if (read_rom_state == state_write_font_b)
			font_reg_b <= {rom_data};
		
		if (read_rom_state == state_read_text_end)
			read_rom_state <= 0;
		else 
			read_rom_state <= read_rom_state + 1;
	end
end

reg[4:0] font_bit;
always @(posedge vga_clk)
begin
	if (~reset_n) begin
		font_bit <= 7;
		text_rom_addr <= 15;
		use_font_a <= 1'b1;
	end
	else begin
		if (vsync_r == 1'b0) begin
			text_rom_addr <= 15;
			font_bit <= 7;
			use_font_a <= 1'b1;
		end
		if (hsync_de) begin
			if (font_bit == 0) begin
				if (text_rom_addr == 31)
					text_rom_addr <= 15;
				else
					text_rom_addr <= text_rom_addr + 1;
				font_bit <= 7;
				use_font_a <= ~use_font_a;
			end
			else begin
				font_bit <= font_bit - 1;
			end
		end
	end
end 

always @(posedge vga_clk)
   begin
	  if (~reset_n) begin
		  font_scan <= 0;
	  end
	  if(vsync_de && x_cnt == 1) begin
	     if (font_scan == 7)
		     font_scan <= 0;
		  else
           font_scan <= font_scan + 1'b1;
	  end
end

 
//----------------------------------------------------------------
////////// VGA数据输出
//---------------------------------------------------------------- 
wire font_bit_on;
assign font_bit_on = use_font_a ? {font_reg_a[font_bit]} : {font_reg_b[font_bit]};
  
//----------------------------------------------------------------
////////// ROM实例化
//----------------------------------------------------------------	
wire [10:0] rom_addr;
wire [7:0] rom_data;
assign rom_addr =
	((read_rom_state >= state_read_text_a && read_rom_state < state_read_font_a) ||
	 (read_rom_state >= state_read_text_b && read_rom_state < state_read_font_b)) ?
	text_rom_addr : font_rom_addr;

	rom rom_inst (
	  .clock(vga_clk), // input clka
	  .address(rom_addr), // input [10 : 0] addra
	  .q(rom_data) // output [7 : 0] douta
	);
	
	
  assign vga_hs = hsync_r;
  assign vga_vs = vsync_r;  
  assign vga_r = (hsync_de & vsync_de) ? (font_bit_on ? 5'b10011  : 5'b00000)  : 5'b00000;
  assign vga_g = (hsync_de & vsync_de) ? (font_bit_on ? 6'b100111 : 6'b000111) : 6'b000000;
  assign vga_b = (hsync_de & vsync_de) ? (font_bit_on ? 5'b10011  : 5'b01011)  : 5'b00000;
  assign vga_clk = CLK_OUT2;  //VGA时钟频率选择40Mhz
  
  
   pll pll_inst
  (// Clock in ports
   .inclk0(clk),      // IN
   .c0(CLK_OUT1),     // 21.175Mhz for 640x480(60hz)
   .c1(CLK_OUT2),     // 40.0Mhz for 800x600(60hz)
   .c2(CLK_OUT3),     // 65.0Mhz for 1024x768(60hz)
   .c3(CLK_OUT4),     // 108.0Mhz for 1280x1024(60hz)
   .areset(1'b0),               // reset input 
   .locked(LOCKED));        // OUT
// INST_TAG_END ------ End INSTANTIATI 


 
endmodule

