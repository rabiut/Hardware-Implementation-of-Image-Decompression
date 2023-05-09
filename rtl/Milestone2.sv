	// Milestone 2

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif
`include "define_state.h"
module Milestone2 (
		input logic Clock,
		input logic resetn,
		input logic start,
		input logic [15:0]SRAM_read_data,
		output logic  [15:0] SRAM_write_data,
		output logic SRAM_we_n,
		output logic done,//changed all M2_done to done
		output logic [17:0] SRAM_address			
);

M2_state_type M2_state;

logic [6:0] read_address_0a, write_address_0b, read_address_1a, write_address_1b;
logic [31:0] write_data_b [1:0];
logic write_enable_b [1:0];
logic [31:0] read_data_a [1:0];
logic [31:0] read_data_b [1:0];

//RAM0 holds S' (Addresses 0 to 31) & S = T*Ctranspose (Addresses 32 to 64)
dual_port_RAM0 dual_port_RAM0_unit (
	.address_a ( read_address_0a ),
	.address_b ( write_address_0b ),// write_data!!!
	.clock ( Clock ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[0] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);
	
//RAM1 holds T = S'*C (Addresses 0 to 31) 
dual_port_RAM1 dual_port_RAM1_unit (
	.address_a ( read_address_1a ),
	.address_b ( write_address_1b ),// write_data!!!
	.clock ( Clock ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[1] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);


parameter 
// our
		Y_address = 18'd0,
		U_address = 18'd38400,
		V_address = 18'd57600;


//our registers
logic [17:0] y_fetch_col_counter;
logic [17:0] y_fetch_row_counter;
logic signed [31:0] s_prime_1;
logic signed [31:0] s_prime_0;  
logic signed [31:0] C0,C1;
logic [15:0] c0, c1;
logic signed [31:0] MULTICS0,MULTICS1;
logic signed[31:0] T, S;
logic signed[31:0] S_CT;
logic [17:0] i, j;
logic [17:0] Y_write_col_counter;
logic [17:0] Y_write_row_counter;
logic [15:0] Y_FETCH_buffer;
logic [31:0] T_STORE_buffer;
logic [31:0] S_STORE_buffer;
logic [17:0] YUV_block_col_counter;
logic [17:0] YUV_block_row_counter;
logic [17:0] YUV_START_ADDRESS;
logic [17:0] counter;


assign S = (S_CT[31]) ? 8'd0 : (|S_CT[30:24]) ? 8'd255 : S_CT[23:16];


always_ff @ (posedge Clock or negedge resetn) begin
	if (resetn == 1'b0) begin	
		YUV_START_ADDRESS <= 18'd76800;
		write_enable_b[0] <= 1'b0;
		write_enable_b[1] <= 1'b0; 
		write_data_b[0] <= 32'd0;
		write_data_b[1] <= 32'd0;
		M2_state <= M2_IDLE;
		SRAM_address <= 18'd0;
		read_address_0a <= 7'd0;
		write_address_0b <= 7'd0;
		read_address_1a <= 7'd0;
		write_address_1b <= 7'd0;
		SRAM_we_n <= 1'b1;//read
		done <= 1'b0;
		c0 <= 16'd0;
		c1 <= 16'd0;
		T <= 32'd0;
		y_fetch_col_counter <= 18'd0;
		y_fetch_row_counter <= 18'd0;
		Y_write_col_counter <= 18'd0;
		Y_write_row_counter <= 18'd0;
		Y_FETCH_buffer <= 16'd0;
		T_STORE_buffer <= 32'd0;
		S_STORE_buffer <= 32'd0;
		YUV_block_col_counter <= 18'd0;
		counter <= 1'd0;
		
	end else begin
		case (M2_state)
		M2_IDLE: begin
				done <= 1'b0;
				if (start) begin
				SRAM_we_n <= 1'b1;
				SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76800 (Y0)
				y_fetch_col_counter <= y_fetch_col_counter + 18'd1;//go to next column
				write_enable_b[0] <= 1'b0; // read
				
				M2_state <= LI_FS_0;
			end
		end
		/****** BEGIN FETCH S' ******/
		LI_FS_0: begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76801 (Y1)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			write_address_0b <= 18'd0;// set address location 0 
			
			M2_state <= LI_FS_1;
		end
		
		LI_FS_1:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76802 (Y2)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			M2_state <= CC_FS_2;
		end
		
		//COMMON CASE FETCH S'
		CC_FS_2:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76803 (Y3)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y0 to store later
			
			if (write_address_0b == 18'd0) begin
				write_address_0b <= 18'd0;// set address location 0 
			end else begin
				write_address_0b <= write_address_0b + 18'd1;// set address location 1
			end
			
			M2_state <= CC_FS_3;
		end
		
		CC_FS_3:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76804 (Y4)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
						
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y0Y1 at address 0
			write_enable_b[0] <= 1'b1; // write
			
			M2_state <= CC_FS_4;
		end
		
		CC_FS_4:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76805 (Y5)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y2 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 1
			
			M2_state <= CC_FS_5;
		end
		
		CC_FS_5:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76806 (Y6)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y2Y3 at address 1***first line done***
			write_enable_b[0] <= 1'b1; // write
			
			M2_state <= CC_FS_6;
		end
		
		CC_FS_6:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76807 (Y7)
			y_fetch_col_counter <= 18'd0;//reset column counter
			y_fetch_row_counter <= y_fetch_row_counter + 18'd320;//move to next row 
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y4 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 2
			
			M2_state <= CC_FS_7;
		end
		
		CC_FS_7:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 77120 (Y320)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y4Y5 at address 2
			write_enable_b[0] <= 1'b1; // write
			
			M2_state <= CC_FS_8;
		end
		
		CC_FS_8:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 77121 (Y321)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y6 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 3
			
			M2_state <= CC_FS_9;
		end
		
		CC_FS_9:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 77122 (Y322)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;

			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y6Y7 at address 3
			write_enable_b[0] <= 1'b1; // write
			
			if (y_fetch_row_counter == 18'd2240) begin 
				M2_state <= LO_FS_10;
			end else begin
				M2_state <= CC_FS_2;
			end
			
		end
		
		// LEAD OUT FETCH S'
		
		LO_FS_10:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 79043 (Y2243)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y2240 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 28
			
			M2_state <= LO_FS_11;
		end
		
		LO_FS_11:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 79044 (Y2244)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y2240Y2241 at address 28
			write_enable_b[0] <= 1'b1; // write
			
			M2_state <= LO_FS_12;
		end
		
		LO_FS_12:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 79045 (Y2245)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y2242 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 29
			
			M2_state <= LO_FS_13;
		end
		
		LO_FS_13:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 79046 (Y2246)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y2242Y2243 at address 29
			write_enable_b[0] <= 1'b1; // write
			
			M2_state <= LO_FS_14;
		end
		
		LO_FS_14:begin
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 79047 (Y2247)
			y_fetch_col_counter <= 18'd0; // reset for Y8 (next block)
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y2244 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 30
			
			M2_state <= LO_FS_15;
		end
		
		LO_FS_15:begin
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y2244Y2245 at address 30
			write_enable_b[0] <= 1'b1; // write
			
			M2_state <= LO_FS_16;
		end
		
		LO_FS_16:begin
			
			Y_FETCH_buffer <= SRAM_read_data; // hold Y2246 to store later
			write_enable_b[0] <= 1'b0; // read
			
			write_address_0b <= write_address_0b + 18'd1;// set address location 31	
			
			M2_state <= LO_FS_17;
		end
		
		LO_FS_17:begin
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y2246Y2247 at address 31
			write_enable_b[0] <= 1'b1; // write
			
			read_address_0a <= 18'd0; // read address to get Y0Y1
			
			YUV_block_col_counter <= YUV_block_col_counter + 18'd1; // go to next block
			
			M2_state <= LO_FS_17_5;
		end
		
		LO_FS_17_5:begin
		
			write_enable_b[0] <= 1'b0; // read
		
			write_address_0b <= 18'd0;// reset back to zero for next 8x8 block fetch
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2Y3
			counter <= counter + 18'd1;
			 
			i <= 18'd0;
			j <= 18'd0;
		
			M2_state <= LI_CT_18;
		end
		
		/****** END FETCH S'  *****/
		
		/****** BEGIN CALCULATE T *******/
		
		LI_CT_18:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y4Y5
			
			c0 <= 16'd0;
			c1 <= 16'd8;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y0
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y1
			
			counter <= counter + 18'd1;
			
			M2_state <= LI_CT_19;
		
		end
		
		LI_CT_19:begin
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y6Y7
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y2
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y3
			
			T <= MULTICS0 + MULTICS1; // c0*Y0 + c1*Y1 
			
			write_address_1b <= 18'd0;
			counter <= counter + 18'd1;
			
			M2_state <= CC_CT_20;
		
		end
		
		// COMMON CASE CALCULATE T
		
		CC_CT_20:begin
		
	
			read_address_0a <= read_address_0a - 18'd3; // read address to get Y0Y1
			counter <= 18'd0;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y4
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y5
			
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2 + c1*Y3
			
			if (write_address_1b == 18'd0) begin
				write_address_1b <= 18'd0;// set address location 1
			end else begin
				write_address_1b <= write_address_1b + 18'd1;// set address location 1
			end
			
			M2_state <= CC_CT_21;
		
		end
		
		CC_CT_21:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2Y3
			counter <= counter + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y6
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y7
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y4 + c1*Y5
			
			j <= j + 18'd1; // increment col C
			
			
			M2_state <= CC_CT_22;
		
		end
		
		CC_CT_22:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y4Y5
			counter <= counter + 18'd1;
			
			c0 <= c0 - 16'd47;
			c1 <= c1 - 16'd47;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y6 + c1*Y7
			
			M2_state <= CC_CT_23;
		
		end
		CC_CT_23:begin

			read_address_0a <= read_address_0a + 18'd1; // read address to get Y6Y7
			counter <= counter + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			write_enable_b[1] <= 1'b1;//write 
			write_data_b[1] <= T;
			
			T <= MULTICS0 + MULTICS1; // c0*Y0 + c1*Y1
			
			M2_state <= CC_CT_24;
		
		end
		CC_CT_24:begin
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2 + c1*Y3
			
			if (counter == 18'd3 && j == 18'd7) begin
			   read_address_0a <= read_address_0a + 18'd1;
				counter <=18'd0;
			end else begin
			   read_address_0a <= read_address_0a - 18'd3;
				counter <= 18'd0;
			end
			
			write_address_1b <= write_address_1b + 18'd1;// set address location 1
			
			M2_state <= CC_CT_25;
		
		end
		CC_CT_25:begin
			
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2Y3	
			counter <= counter + 18'd1;
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;	
			
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y4 + c1*Y5
			
						
			M2_state <= CC_CT_26;
		
		end
		CC_CT_26:begin
			
			read_address_0a <= read_address_0a + 18'd1;
			counter <= counter + 18'd1;
			
			if (j == 7) begin
				read_address_0a <= read_address_0a + 18'd1; // read address to get Y320Y321
				i <= i + 18'd1; //
				c0 <= 16'd0;
				c1 <= 16'd8;
				j <= 0; // reset j 
			end else begin
				j <= j + 18'd1;
				c0 <= c0 - 16'd47;
				c1 <= c1 - 16'd47;
			end
			
			
			
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y6 + c1*Y7

			M2_state <= CC_CT_27;
			
		end
		
		CC_CT_27:begin
			
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2246Y2247
			counter <= counter + 18'd1;
		
			write_enable_b[1] <= 1'b1;//write 
			write_data_b[1] <= T;
			
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			
			
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= MULTICS0 + MULTICS1; // c0*Y0 + c1*Y1
			

			if (i == 18'd7 && j == 18'd6) begin
				M2_state <= LO_CT_28;
			end else begin
				M2_state <= CC_CT_20;
			end
			
		end
		
		// LEAD OUT CALCULATE T
		
		
		LO_CT_28:begin
		
			read_address_0a <= read_address_0a - 18'd3; // read address to get Y2240Y2241
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y2244
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y2245
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2242 + c1*Y2243
			
			write_address_1b <= write_address_1b + 18'd1;// set address location 1
			
			
			M2_state <= LO_CT_29;
		
		end
		
		LO_CT_29:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2242Y2243
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y2246
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y2247
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2244 + c1*Y2245
			
			j <= j + 18'd1; // increment col C
			
			M2_state <= LO_CT_30;
		
		end
		
		LO_CT_30:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2244Y2245
			
			c0 <= c0 - 16'd47;
			c1 <= c1 - 16'd47;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
		
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y2246 + c1*Y2247
			
			M2_state <= LO_CT_31;
		
		end
		LO_CT_31:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2246Y2247
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			write_enable_b[1] <= 1'b1;//write 
			write_data_b[1] <= T;
			
			T <= MULTICS0 + MULTICS1; // c0*Y2240 + c1*Y2241
			
			M2_state <= LO_CT_32;
		
		end
		LO_CT_32:begin
		
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2242 + c1*Y2243
			
			write_address_1b <= write_address_1b + 18'd1;// set address location 1
			
			M2_state <= LO_CT_33;
		
		end
		LO_CT_33:begin
			 
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2244 + c1*Y2245

						
			M2_state <= LO_CT_34;
		
		end
		LO_CT_34:begin
						
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y2246 + c1*Y2247
			
			j <= 18'd0; // reset j 
			i <= 18'd0; // reset i 
			
			counter <= 18'd0;
			M2_state <= LI_CS_FS_35;
		
		end
		
		/****  END CALCULATE T *******/
		
		/****  BEGIN CALCULATE S & FETCH S' *******/
		
		
		LI_CS_FS_35:begin
			y_fetch_row_counter <= 18'd0; // reset for next block
			y_fetch_col_counter <= 18'd0; // reset for next block
			YUV_START_ADDRESS <= YUV_START_ADDRESS + 18'd8;
			
			read_address_1a <= 18'd0; // read address to get T0
			write_address_1b <= 18'd8; // read address to get T320
			
			write_enable_b[1] <= 1'b1; //write
			write_data_b[1] <= T; // store T2246T2247 at address 31
		
			
			M2_state <= LI_CS_FS_35_5;
		end
		
		LI_CS_FS_35_5: begin
			write_enable_b[1] <= 1'b0; //read
			
			read_address_1a <= read_address_1a + 18'd16; // read address to get T640
			write_address_1b <= write_address_1b + 18'd16; // read address to get T960
			counter <= counter + 18'd1;
			
			M2_state <= LI_CS_FS_36;
		end
		
		
		LI_CS_FS_36:begin
		
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76808 (Y8)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			
			read_address_1a <= read_address_1a + 18'd16; // read address to get T640
			write_address_1b <= write_address_1b + 18'd16; // read address to get T960
			counter <= counter + 18'd1;
			
			c0 <= 16'd0;
			c1 <= 16'd8;
			s_prime_0 <= $signed(read_data_a[1]); // T0
			s_prime_1 <= $signed(read_data_b[1]); // T1
			
			M2_state <= LI_CS_FS_37;
		
		end
		
		
		LI_CS_FS_37:begin
		
		
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76809 (Y9)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			read_address_1a <= read_address_1a + 18'd16; // read address to get T640
			write_address_1b <= write_address_1b + 18'd16; // read address to get T960
			counter <= counter + 18'd1;
			
			write_address_0b <= 18'd0;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]); // T2
			s_prime_1 <= $signed(read_data_b[1]); // T3
			
			S_CT <= MULTICS0 + MULTICS1; // c0*T0 + c1*T1 
			
			M2_state <= CC_CS_FS_38;
		
		end
		
		// COMMON CASE CALCULATE S
		CC_CS_FS_38:begin
			
			write_enable_b[0] <= 1'b0; //read
		
			read_address_1a <= read_address_1a - 18'd47;
			write_address_1b <= write_address_1b - 18'd47;
			counter <= 18'd0;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]); // T4
			s_prime_1 <= $signed(read_data_b[1]); // T5
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T2 + c1*T3
			
			M2_state <= CC_CS_FS_39;
		
		end
		
		CC_CS_FS_39:begin
		
			Y_FETCH_buffer <= SRAM_read_data; // hold Y8 to store later
	
			read_address_1a <= read_address_1a + 18'd16; 
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]); // T6
			s_prime_1 <= $signed(read_data_b[1]); // T7
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T4 + c1*T5
			
			j <= j + 18'd1; // increment col C
			
			M2_state <= CC_CS_FS_40;
		
		end
		
		CC_CS_FS_40:begin
		
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y8Y9 at address 0
			write_enable_b[0] <= 1'b1; // write
			
			read_address_1a <= read_address_1a + 18'd16; 
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
			
			c0 <= 16'd0;
			c1 <= 16'd8;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T6 + c1*T7
			
			M2_state <= CC_CS_FS_41;
		
		end
		CC_CS_FS_41:begin

			
			write_address_0b <= write_address_0b + 18'd32;
			
			read_address_1a <= read_address_1a + 18'd16; 
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
			write_enable_b[0] <= 1'b0; // read
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_STORE_buffer <= S; // S0
			
			S_CT <= MULTICS0 + MULTICS1; // c0*T0 + c1*T1
			
			M2_state <= CC_CS_FS_42;
		
		end
		CC_CS_FS_42:begin
		
			//read_address_1a <= read_address_1a - 18'd3; // read address to get T6T7
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			read_address_1a <= read_address_1a - 18'd47;
			write_address_1b <= write_address_1b - 18'd47;
			
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T2 + c1*T3
			
			M2_state <= CC_CS_FS_43;
		
		end
		CC_CS_FS_43:begin
			
			read_address_1a <= read_address_1a + 18'd16; 
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
		  
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T4 + c1*T5
			
						
			M2_state <= CC_CS_FS_44;
		
		end
		CC_CS_FS_44:begin
		
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76810 (Y10)
			y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			
			//c0 <= c0 + 16'd16;
			//c1 <= c1 + 16'd16;
			counter <= counter + 18'd1;
			
			if (j == 7) begin
				i <= i + 18'd1; //
				j <= 0; // reset j 
				c0 <= c0 - 16'd47;
				c1 <= c1 - 16'd47;
				read_address_1a <= 18'd0; 
				write_address_1b <= 18'd8;
			end else begin
				j <= j + 18'd1;
				c0 <= 18'd0;
				c1 <= 18'd8;
				read_address_1a <= read_address_1a - 18'd47; 
				write_address_1b <= write_address_1b - 18'd47;
			end
			
			if (counter == 18'd3 && j == 18'd7) begin
			   c0 <= c0 + 16'd16;
				c1 <= c1 + 16'd16;
				counter <=18'd0;
			end else begin
				c0 <= 18'd0;
				c1 <= 18'd8;
				counter <= 18'd0;
			end
			
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T6 + c1*T7

			M2_state <= CC_CS_FS_45;
		
		end
		
		CC_CS_FS_45:begin
			
			SRAM_address <= y_fetch_col_counter + y_fetch_row_counter + YUV_START_ADDRESS; // fetch S': address 76809 (Y9)
				
			if (y_fetch_col_counter == 18'd7) begin
				y_fetch_row_counter <= y_fetch_row_counter + 18'd320;
				y_fetch_col_counter <= 18'd0;
			end else begin
				y_fetch_col_counter <= y_fetch_col_counter + 18'd1;
			end
			
			write_enable_b[0] <= 1'b1; // write
		
			read_address_1a <= read_address_1a + 18'd16; 
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
			
			write_data_b[0] <= {S_STORE_buffer[15:0],S[15:0]};
			write_address_0b <= write_address_0b - 18'd31;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T0 + c1*T1
			
			if (i == 18'd7 && j == 18'd6) begin
				M2_state <= LO_CS_FS_46;
			end else begin
				M2_state <= CC_CS_FS_38;
			end
			
		end
		
		
		// LEAD OUT CALCULATE S & FETCH S'
		
		LO_CS_FS_46:begin
		
			read_address_1a <= read_address_1a - 18'd47;
				write_address_1b <= write_address_1b - 18'd47;
			counter <= 18'd0;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]); // T4
			s_prime_1 <= $signed(read_data_b[1]); // T5
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T2 + c1*T3
			
			M2_state <= LO_CS_FS_47;
		
		end
		
		LO_CS_FS_47:begin
		
			Y_FETCH_buffer <= SRAM_read_data; // hold Y2254 to store later
		
			read_address_1a <= read_address_1a + 18'd16;
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter  + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]); // T6
			s_prime_1 <= $signed(read_data_b[1]); // T7
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T4 + c1*T5
			
			j <= j + 18'd1; // increment col C
			
			M2_state <= LO_CS_FS_48;
		
		end
		
		LO_CS_FS_48:begin
		
			y_fetch_col_counter <= 18'd0;
			y_fetch_row_counter <= 18'd0;
			
			write_enable_b[0] <= 1'b1; // write
			
			write_data_b[0] <= {Y_FETCH_buffer,SRAM_read_data}; // store Y8Y9 at address 0
			write_address_0b <= write_address_0b + 18'd32;
			
			read_address_1a <= read_address_1a + 18'd16;
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
			
			c0 <= 16'd0;
			c1 <= 16'd8;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T6 + c1*T7
			
			M2_state <= LO_CS_FS_49;
		
		end
		LO_CS_FS_49:begin
		
			read_address_1a <= read_address_1a + 18'd16;
			write_address_1b <= write_address_1b + 18'd16;
			counter <= counter + 18'd1;
			
			write_enable_b[0] <= 1'b0; // read
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_STORE_buffer <= S; // S0
			
			S_CT <= MULTICS0 + MULTICS1; // c0*T0 + c1*T1
			
			M2_state <= LO_CS_FS_50;
		
		end
		LO_CS_FS_50:begin
		
			//read_address_1a <= read_address_1a + 18'd1; // read address to get T6T7
			//counter <= counter + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T2 + c1*T3
			
			M2_state <= LO_CS_FS_51;
		
		end
		LO_CS_FS_51:begin
			 
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[1]);
			s_prime_1 <= $signed(read_data_b[1]);
			
			S_CT <= S_CT + MULTICS0 + MULTICS1; // c0*T4 + c1*T5
						
			M2_state <= LO_CS_FS_52;
		
		end
		LO_CS_FS_52:begin
		
			
			YUV_block_col_counter <= YUV_block_col_counter + 18'd1; // go to next block
			
			read_address_0a <= 18'd0;
			
			i <= 18'd0;//reset i and j counter to 0
			j <= 18'd0;
			M2_state <= LI_WS_CT_53;
		
		end
		
		/***** END CALCULATE S & FETCH S' *********/
		
		/****** BEGIN WRITE S & CALCULATE T *******/
		
		LI_WS_CT_53:begin
			
			write_enable_b[0] <= 1'b1; // write
			
			read_address_0a <= read_address_0a + 18'd1;
			
			write_data_b[0] <= {S_STORE_buffer[15:0],S[15:0]};
			
			M2_state <= LI_WS_CT_54;
			
		end
		
		LI_WS_CT_54:begin
		
			write_enable_b[0] <= 1'b0; // read
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2Y3
			
			c0 <= 16'd0;
			c1 <= 16'd8;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y0
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y1
			
			M2_state <= LI_WS_CT_55;
		
		end
		
		LI_WS_CT_55:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y4Y5
			Y_write_row_counter <= 18'd0;
			Y_write_col_counter <= 18'd0;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y2
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y3
			
			T <= MULTICS0 + MULTICS1; // c0*Y0 + c1*Y1 
			
			write_address_1b <= 18'd0; // writing T
			write_address_0b <= 18'd32;  // writing S to SRAM ???
			
			M2_state <= CC_WS_CT_56;
		
		end
		
		// COMMON CASE WRITE S & CALCULATE T
		
		CC_WS_CT_56:begin
		
			read_address_0a <= read_address_0a - 18'd3; // read address to get Y6Y7
			counter <= 18'd0;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y4
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y5
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2 + c1*Y3
			
			M2_state <= CC_WS_CT_57;
		
		end
		
		CC_WS_CT_57:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y0Y1
			counter <= counter + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y6
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y7
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y4 + c1*Y5
			
			j <= j + 18'd1; // increment col C
			
			M2_state <= CC_WS_CT_58;
		
		end
		
		CC_WS_CT_58:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2Y3
			counter <= counter + 18'd1;
			
			c0 <= c0 - 16'd47;
			c1 <= c1 - 16'd47;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y6 + c1*Y7
			
			M2_state <= CC_WS_CT_59;
		
		end
		CC_WS_CT_59:begin
		
			SRAM_address <= Y_write_col_counter + Y_write_row_counter + Y_address;
			SRAM_we_n <= 1'b0; //write
			
			// write S0S1
			SRAM_write_data <= {read_data_b[0][15:8], read_data_b[0][7:0]}; // S0S1
			
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y4Y5
			counter <= counter + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T_STORE_buffer <= T; // T0
			
			T <= MULTICS0 + MULTICS1; // c0*Y0 + c1*Y1
			
			M2_state <= CC_WS_CT_60;
		
		end
		CC_WS_CT_60:begin
		
			SRAM_we_n <= 1'b1; // read
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2 + c1*Y3
			
			if (counter == 18'd3 && j == 18'd7) begin
			   read_address_0a <= read_address_0a + 18'd1;
				counter <=18'd0;
			end else begin
			   read_address_0a <= read_address_0a - 18'd3;
				counter <= 18'd0;
			end
			
			write_address_0b <= write_address_0b + 18'd1;
			
			M2_state <= CC_WS_CT_61;
		
		end
		CC_WS_CT_61:begin
		
			read_address_0a <= read_address_0a + 18'd1;
			counter <= counter + 18'd1;
		
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y4 + c1*Y5

						
			M2_state <= CC_WS_CT_62;
		
		end
		CC_WS_CT_62:begin
			
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2Y3
			counter <= counter + 18'd1;
			
			if (j == 7) begin
				read_address_0a <= read_address_0a + 18'd1; // read address to get Y320Y321
				i <= i + 18'd1; //
				c0 <= 16'd0;
				c1 <= 16'd8;
				j <= 0; // reset j 
			end else begin
				j <= j + 18'd1;
				c0 <= c0 - 16'd47;
				c1 <= c1 - 16'd47;
			end
			
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y6 + c1*Y7

			M2_state <= CC_WS_CT_63;
		
		end
		
		CC_WS_CT_63:begin
			
			read_address_0a <= read_address_0a + 18'd1;
			counter <= counter + 18'd1;
			
			write_enable_b[1] <= 1'b1;//write
			write_data_b[1] <= {T_STORE_buffer[15:0],T[15:0]};
			write_address_1b <= write_address_1b + 18'd1;
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y0 + c1*Y1
			
			if (i == 18'd7 && j == 18'd6) begin
				M2_state <= LO_WS_CT_64;
			end else begin
				M2_state <= CC_WS_CT_56;
			end
			
			if (Y_write_col_counter == 18'd3) begin
				Y_write_col_counter <= 18'd0;
				Y_write_row_counter <= Y_write_row_counter + 18'd160;
			end else begin
				Y_write_col_counter <= Y_write_col_counter + 18'd1;
			end
			
		end
		
		// LEAD OUT CALCULATE T
		
		LO_WS_CT_64:begin
		
			read_address_0a <= read_address_0a - 18'd3; // read address to get Y2246Y2247
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y2244
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y2245
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2242 + c1*Y2243
			
			M2_state <= LO_WS_CT_65;
		
		end
		
		LO_WS_CT_65:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2240Y2241
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]); // Y2246
			s_prime_1 <= $signed(read_data_a[0][15:0]); // Y2247
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2244 + c1*Y2245
			
			j <= j + 18'd1; // increment col C
			
			M2_state <= LO_WS_CT_66;
		
		end
		
		LO_WS_CT_66:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2242Y2243
			
			c0 <= c0 - 16'd47;
			c1 <= c1 - 16'd47;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
		
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y2246 + c1*Y2247
			
			M2_state <= LO_WS_CT_67;
		
		end
		LO_WS_CT_67:begin
		
			read_address_0a <= read_address_0a + 18'd1; // read address to get Y2244Y2245
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T_STORE_buffer <= T; // T2246
			
			T <= MULTICS0 + MULTICS1; // c0*Y2240 + c1*Y2241
			
			M2_state <= LO_WS_CT_68;
		
		end
		LO_WS_CT_68:begin
			
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2242 + c1*Y2243
			
			M2_state <= LO_WS_CT_69;
		
		end
		LO_WS_CT_69:begin
			 
			c0 <= c0 + 16'd16;
			c1 <= c1 + 16'd16;
			s_prime_0 <= $signed(read_data_a[0][31:16]);
			s_prime_1 <= $signed(read_data_a[0][15:0]);
			
			T <= T + MULTICS0 + MULTICS1; // c0*Y2244 + c1*Y2245

			M2_state <= LO_WS_CT_70;
		
		end
		LO_WS_CT_70:begin
			
			T <= (T + MULTICS0 + MULTICS1) >>> 8; // c0*Y2246 + c1*Y2247
			
			j <= 18'd0; // reset j 
			i <= 18'd0; // reset i 
			

			M2_state <= LO_IF_71;
		
		end
		
		/****** END WRITE S & CALCULATE T *******/
		
		/****** IF STATEMENTS to determine if Y, U or V *******/
		
		LO_IF_71:begin
		
			if (YUV_block_row_counter == 18'd29) begin // if done Y or U
				if (YUV_block_col_counter == 18'd39 && SRAM_address == 18'd153599) begin
					YUV_START_ADDRESS <= 18'd153600; // let's go to U
					YUV_block_col_counter <= 18'd0;
					YUV_block_row_counter <= 18'd0;
				end
				if (YUV_block_col_counter == 18'd39 && SRAM_address == 18'd191999) begin
					YUV_START_ADDRESS <= 18'd192000; // let's go to V
					YUV_block_col_counter <= 18'd0;
					YUV_block_row_counter <= 18'd0;
				end else begin
					YUV_START_ADDRESS <= YUV_START_ADDRESS + 18'd8;
				end
			end else begin // if not done Y, U or V
				if (YUV_block_col_counter == 18'd39) begin
					YUV_START_ADDRESS <= YUV_START_ADDRESS + 18'd2248; // for Y
					YUV_block_col_counter <= 18'd0;
					YUV_block_row_counter <= YUV_block_row_counter + 18'd1;
				end
				if (YUV_block_col_counter == 18'd19) begin
					YUV_START_ADDRESS <= YUV_START_ADDRESS + 18'd1128;  // for U & V
					YUV_block_col_counter <= 18'd0;
					YUV_block_row_counter <= YUV_block_row_counter + 18'd1;
				end else begin
					YUV_START_ADDRESS <= YUV_START_ADDRESS + 18'd8;
				end
			end
			
			if (YUV_START_ADDRESS >= 18'd230399) begin
				M2_state <= L2_finish;
			end else begin // go back to calculate S and fetch S'
				M2_state <= LI_CS_FS_35;
			end
		
		end
		
		L2_finish: begin
			SRAM_we_n <= 1'b1;
			M2_state <= M2_finish;
		end
		
		M2_finish: begin
			done <= 1'b1;
			M2_state <= M2_IDLE;
		end
		default: M2_state <= M2_IDLE;
	endcase
	end
end

assign MULTICS0 = C0 * s_prime_0;
assign MULTICS1 = C1 * s_prime_1;

always_comb begin
	case(c0)
	0:   C0 = 32'sd1448;   //C00
	1:   C0 = 32'sd1448;   //C01
	2:   C0 = 32'sd1448;   //C02
	3:   C0 = 32'sd1448;   //C03
	4:   C0 = 32'sd1448;   //C04
	5:   C0 = 32'sd1448;   //C05
	6:   C0 = 32'sd1448;   //C06
	7:   C0 = 32'sd1448;   //C07
	8:   C0 = 32'sd2008;   //C10
	9:   C0 = 32'sd1702;   //C11
	10:  C0 = 32'sd1137;   //C12
	11:  C0 = 32'sd399;    //C13
	12:  C0 = -32'sd399;   //C14
	13:  C0 = -32'sd1137;  //C15
	14:  C0 = -32'sd1702;  //C16
	15:  C0 = -32'sd2008;  //C17
	16:  C0 = 32'sd1892;   //C20
	17:  C0 = 32'sd783;    //C21
	18:  C0 = -32'sd783;   //C22
	19:  C0 = -32'sd1892;  //C23
	20:  C0 = -32'sd1892;  //C24
	21:  C0 = -32'sd783;   //C25
	22:  C0 = 32'sd783;    //C26
	23:  C0 = 32'sd1892;   //C27
	24:  C0 = 32'sd1702;   //C30
	25:  C0 = -32'sd399;   //C31
	26:  C0 = -32'sd2008;  //C32
	27:  C0 = -32'sd1137;  //C33
	28:  C0 = 32'sd1137;   //C34
	29:  C0 = 32'sd2008;   //C35
	30:  C0 = 32'sd399;    //C36
	31:  C0 = -32'sd1702;  //C37
	32:  C0 = 32'sd1448;   //C40
	33:  C0 = -32'sd1448;  //C41
	34:  C0 = -32'sd1448;  //C42
	35:  C0 = 32'sd1448;   //C43
	36:  C0 = 32'sd1448;   //C44
	37:  C0 = -32'sd1448;  //C45
	38:  C0 = -32'sd1448;  //C46
	39:  C0 = 32'sd1448;   //C47
	40:  C0 = 32'sd1137;   //C50
	41:  C0 = -32'sd2008;  //C51
	42:  C0 = 32'sd399;    //C52
	43:  C0 = 32'sd1702;   //C53
	44:  C0 = -32'sd1702;  //C54
	45:  C0 = -32'sd399;   //C55
	46:  C0 = 32'sd2008;   //C56
	47:  C0 = -32'sd1137;  //C57
	48:  C0 = 32'sd783;    //C60
	49:  C0 = -32'sd1892;  //C61
	50:  C0 = 32'sd1892;   //C62
	51:  C0 = -32'sd783;   //C63
	52:  C0 = -32'sd783;   //C64
	53:  C0 = 32'sd1892;   //C65
	54:  C0 = -32'sd1892;  //C66
	55:  C0 = 32'sd783;    //C67
	56:  C0 = 32'sd399;    //C70
    57:  C0 = -32'sd1137;  //C71
    58:  C0 = 32'sd1702;   //C72
    59:  C0 = -32'sd2008;  //C73
    60:  C0 = 32'sd2008;   //C74
    61:  C0 = -32'sd1702;  //C75
    62:  C0 = 32'sd1137;   //C76
    63:  C0 = -32'sd399;   //C77
	endcase
end

always_comb begin
	case(c1)
	0:   C1 = 32'sd1448;
	1:   C1 = 32'sd1448;
	2:   C1 = 32'sd1448;
	3:   C1 = 32'sd1448;
	4:   C1 = 32'sd1448;
	5:   C1 = 32'sd1448;
	6:   C1 = 32'sd1448;
	7:   C1 = 32'sd1448;
	8:   C1 = 32'sd2008;
	9:   C1 = 32'sd1702;
	10:  C1 = 32'sd1137;
	11:  C1 = 32'sd399;
	12:  C1 = -32'sd399;
	13:  C1 = -32'sd1137;
	14:  C1 = -32'sd1702;
	15:  C1 = -32'sd2008;
	16:  C1 = 32'sd1892;
	17:  C1 = 32'sd783;
	18:  C1 = -32'sd783;
	19:  C1 = -32'sd1892;
	20:  C1 = -32'sd1892;
	21:  C1 = -32'sd783;
	22:  C1 = 32'sd783;
	23:  C1 = 32'sd1892;
	24:  C1 = 32'sd1702;
	25:  C1 = -32'sd399;
	26:  C1 = -32'sd2008;
	27:  C1 = -32'sd1137;
	28:  C1 = 32'sd1137;
	29:  C1 = 32'sd2008;
	30:  C1 = 32'sd399;
	31:  C1 = -32'sd1702;
	32:  C1 = 32'sd1448;
	33:  C1 = -32'sd1448;
	34:  C1 = -32'sd1448;
	35:  C1 = 32'sd1448;
	36:  C1 = 32'sd1448;
	37:  C1 = -32'sd1448;
	38:  C1 = -32'sd1448;
	39:  C1 = 32'sd1448;
	40:  C1 = 32'sd1137;
	41:  C1 = -32'sd2008;
	42:  C1 = 32'sd399;
	43:  C1 = 32'sd1702;
	44:  C1 = -32'sd1702;
	45:  C1 = -32'sd399;
	46:  C1 = 32'sd2008;
	47:  C1 = -32'sd1137;
	48:  C1 = 32'sd783;
	49:  C1 = -32'sd1892;
	50:  C1 = 32'sd1892;
	51:  C1 = -32'sd783;
	52:  C1 = -32'sd783;
	53:  C1 = 32'sd1892;
	54:  C1 = -32'sd1892;
	55:  C1 = 32'sd783;
	56:  C1 = 32'sd399;
    57:  C1 = -32'sd1137;
    58:  C1 = 32'sd1702;
    59:  C1 = -32'sd2008;
    60:  C1 = 32'sd2008;
    61:  C1 = -32'sd1702;
    62:  C1 = 32'sd1137;
    63:  C1 = -32'sd399;
	endcase	
end

endmodule