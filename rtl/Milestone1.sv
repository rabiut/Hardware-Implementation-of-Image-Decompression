//Milestone1

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"
module Milestone1(
	 input logic Clock,
	 input logic resetn,
	 input logic start,
	 input logic  [15:0] SRAM_read_data,
	 output logic [15:0] SRAM_write_data,
	 output logic done,
	 output logic SRAM_we_n,
	 output logic [17:0] SRAM_address 
);

M1_state_type M1_state;


logic [17:0] data_counter; // data counter to keep track of  pixels
logic [17:0] y_counter; // y counter to keep track of y
logic [17:0] y_loop_counter;
logic [17:0] RGB_write_counter;
logic [7:0] Y,U,V; //holds values of YUV' to do color spacing
logic [31:0] Uj,Vj;//hold accumulation of 6 sums(state table)

logic [7:0] u_6; //[j+5]/2
logic [7:0] u_5;
logic [7:0] u_4;
logic [7:0] u_3;
logic [7:0] u_2;
logic [7:0] u_1; //[j+5]/2
logic [7:0] v_6;
logic [7:0] v_5;
logic [7:0] v_4;
logic [7:0] v_3;
logic [7:0] v_2;
logic [7:0] v_1;


parameter 
		U_START_ADDRESS   = 18'd38400, // starting address for U
		V_START_ADDRESS   = 18'd57600, // starting address for V 
		RGB_START_ADDRESS = 18'd146944, // starting address for RGB
		Y_START_ADDRESS = 18'd0; // starting address for Y
		  

logic [17:0] RGB_address;

logic signed[31:0] coeff; //76284,104595,-25624,-53281,132251: sign-extension needed
logic [8:0]  Mult_op_U;  		//operation 1 8-bits U0
logic signed[8:0] Mult_op_C;  //Operation 2 contants (signed or unsigned) 
logic [8:0]  Mult_op_V;  		//operation 1 8-bits V0
logic [31:0] Mult_op_UVY;  	//Operation 3 Holds either U' or V' or Y'

logic [31:0] op_UVY_math;  // check if aoo*Y' (Y' - 16) else do (U' - 128 & V' - 128)
logic [31:0] MULTI_RGB;// result RGB multiplication with coeff to add into RGB_data[n]
logic [15:0] RGB_data[2:0]; // stores RGB data to be written into SRAM R0G0 B0R1 G1B1
logic [15:0] UVY_data[2:0];//stores UVY data to be written into UVY (state table)

logic [31:0] Mult_result_U, Mult_result_V;
logic [63:0] Mult_result_long_U, Mult_result_long_V;
logic [31:0] op_U_extended, op_V_extended, op_C_extended;

logic [31:0] Reven, Geven, Beven, Rodd, Godd, Bodd;
logic [31:0] RE, GE, BE, RO, GO, BO;


always @(posedge Clock or negedge resetn) begin
    if (~resetn)begin
		Mult_op_U <= 9'd0;
		Mult_op_C <= 9'sd0;
		Mult_op_V <= 9'd0;
		Mult_op_UVY <= 32'd0;
		Reven = 32'd0;
		Geven = 32'd0;
		Beven = 32'd0;
		Rodd = 32'd0;
		Godd = 32'd0;
		Bodd = 32'd0;
		UVY_data[0] = 16'd0;
		UVY_data[1] = 16'd0;
		UVY_data[2] = 16'd0;
		coeff <= 32'sd0;
		SRAM_we_n <= 1'b1;	
		done <= 1'b0;		
		u_6 = 8'd0;
		u_5 <= 8'd0;
		u_4 <= 8'd0;
		u_3 <= 8'd0;
		u_2 <= 8'd0;
		u_1 <= 8'd0;
		v_6 <= 8'd0;
		v_5 <= 8'd0;
		v_4 <= 8'd0;
		v_3 <= 8'd0;
		v_1 <= 8'd0;
		v_1 <= 8'd0;
		Uj <= 32'd0;
		Vj <= 32'd0;
		Y <= 8'd0;
		U <= 8'd0;
		V <= 8'd0;
		data_counter <= 18'd0;
		y_counter <= 18'd0;
		y_loop_counter <= 18'd0;
		RGB_write_counter <= 18'd0;
		RGB_address <= RGB_START_ADDRESS;
		M1_state <= M1_IDLE;		
	end else begin
		case (M1_state)
		/****** BEGIN LEAD IN *******/
		M1_IDLE: begin
			done <= 1'b0;
			if (start) begin
				//start or finish one frame
				M1_state <= LI_0;
				SRAM_we_n <= 1'b1; //read
				SRAM_address <= data_counter + U_START_ADDRESS; // read address U0,U1
				Mult_op_U <= 9'd0;
				Mult_op_C <= 9'sd0;
				Mult_op_V <= 9'd0;
				Mult_op_UVY <= 32'd0;
				Reven = 32'd0;
				Geven = 32'd0;
				Beven = 32'd0;
				Rodd = 32'd0;
				Godd = 32'd0;
				Bodd = 32'd0;
				coeff <= 32'sd0;
				done <= 1'b0;		
				u_6 = 8'd0;
				u_5 <= 8'd0;
				u_4 <= 8'd0;
				u_3 <= 8'd0;
				u_2 <= 8'd0;
				u_1 <= 8'd0;
				v_6 <= 8'd0;
				v_5 <= 8'd0;
				v_4 <= 8'd0;
				v_3 <= 8'd0;
				v_2 <= 8'd0;
				v_1 <= 8'd0;
				Uj <= 32'd0;
				Vj <= 32'd0;
				Y <= 8'd0;
				U <= 8'd0;
				V <= 8'd0;
			end
		end 
		
		LI_0: begin
			SRAM_address <= data_counter + V_START_ADDRESS;//read V0V1
            M1_state <= LI_1;			
		end
		LI_1 : begin
			SRAM_address <= y_counter + Y_START_ADDRESS;//Y0Y1
			
			data_counter <= data_counter + 18'd1;
			
			M1_state <= LI_2;
		end
		LI_2 : begin
		
			/**Interpolation**/
			UVY_data[2] <= SRAM_read_data;//store U0U1
			
			u_4 <= SRAM_read_data[7:0];//U1
			u_3 <= SRAM_read_data[15:8];//U0
			u_2 <= SRAM_read_data[15:8];//U0
			u_1 <= SRAM_read_data[15:8];//U0
			
			Uj <= 32'd128;
			Vj <= 32'd128;
			
			y_counter <= y_counter + 18'd1;
			
			M1_state <= LI_3;
		end		
		LI_3 : begin
		   SRAM_address <= data_counter + U_START_ADDRESS;//U2U3
			
			/**Interpolation**/
			UVY_data[1] <= SRAM_read_data;//store V0V1
			
			v_4 <= SRAM_read_data[7:0];//V1
			v_3 <= SRAM_read_data[15:8];//V0
			v_2 <= SRAM_read_data[15:8];//V0
			v_1 <= SRAM_read_data[15:8];//V0
			
			//21*U0 & 21*V0
			Mult_op_U <= u_1; //U0   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= SRAM_read_data[15:8];//V0
			
			M1_state <= LI_4;
		end		
		LI_4 : begin
			SRAM_address <= data_counter + V_START_ADDRESS;//V2V3
			
			/**Interpolation**/
			UVY_data[0] <= SRAM_read_data;//store Y0Y1
			
			//-52*U0 & -52*V0
			Mult_op_U <= u_2;    
			Mult_op_C <= -9'sd52;//52 ***********************************
			Mult_op_V <= v_2;
			
			// add 128 + 21*U0/21*V0
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			
			M1_state <= LI_5;	
		end	
		
		LI_5 : begin
		
			/**Interpolation**/
			//159*U0 159*V0
		   Mult_op_U <= u_3;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_3;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			//set YUV0' 
			Y <= UVY_data[0][15:8];//Y0'
			U <= UVY_data[2][15:8];//U0'
			V <= UVY_data[1][15:8];//V0'
			
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Y0'
			
			data_counter <= data_counter + 18'd1;
			
			M1_state <= LI_6;
		end	
		
		LI_6 : begin
			/**Interpolation**/
		   UVY_data[2] <= SRAM_read_data;//store U2U3
			
			//159*U1 159*V1
		   Mult_op_U <= u_4;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_4;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			u_6 <= SRAM_read_data[7:0];//u3
			u_5 <= SRAM_read_data[15:8];//u2
			
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V; // V0'
			
			Reven <= 32'd0 + MULTI_RGB;// R0 (0 + a00*Y0)
			Geven <= 32'd0 + MULTI_RGB;// G0 (0 + a00*Y0)
			Beven <= 32'd0 + MULTI_RGB;//B0 (0 + a00*Y0)
			
			
			M1_state <= LI_7;
		end
		
		LI_7 : begin
			/**Interpolation**/
		   UVY_data[1] <= SRAM_read_data;//store V2V3
			 
			 //-52*U1, -52*V1
		   Mult_op_U <= u_5; //U2  
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= SRAM_read_data[15:8];//V2
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			v_6 <= SRAM_read_data[7:0];//V3
			v_5 <= SRAM_read_data[15:8];//V2
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Reven <= Reven + MULTI_RGB;// R0 (aoo*Y0' + a02*V0')
			
			 
			M1_state <= LI_8;
		end
		
		LI_8 : begin
			
			/**Interpolation**/
			//21*U1 21*V1
		   Mult_op_U <= u_6;   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_6;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Geven <= Geven + MULTI_RGB;// G0 (a00*Y0' + a11*U0')
			
					
			M1_state <= LI_9;
		end
		
		LI_9 : begin
			SRAM_address <= data_counter + U_START_ADDRESS;//U4U5
			
			/**Interpolation**/
			Uj <= (Uj + Mult_result_U) >>> 8;
			Vj <= (Vj + Mult_result_V) >>> 8;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Geven <= Geven + MULTI_RGB;// G0 (a00*Y0' + a11*U0' + a12V0')
			
			M1_state <= CC_10;
		end
		
		/****** BEGIN COMMON CASE *******/
		CC_10: begin
			SRAM_address <= data_counter + V_START_ADDRESS;//VevenVodd
			
			/**Interpolation**/ 
			Y <= UVY_data[0][7:0];//Yodd'
			U <= Uj[7:0];//Uodd'
			V <= Vj[7:0];//Vodd'
			
			u_1 <= u_2;//U0
			u_2 <= u_3;//U0
			u_3 <= u_4;//U1
			u_4 <= u_5;//U2
			u_5 <= u_6;//U3
			
			v_1 <= v_2;//V0
			v_2 <= v_3;//V0
			v_3 <= v_4;//V1
			v_4 <= v_5;//V2
			v_5 <= v_6;//V3
		
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][7:0]; // Yodd'
		
			Beven <= Beven + MULTI_RGB;// B0 (a00*Y0' + a21*U0')

			M1_state <= CC_11;
			 
		end
		CC_11: begin
			
			SRAM_address <= y_counter + Y_START_ADDRESS;//YevenYodd
			
			/**Interpolation**/
			// reset Uj, Vj to 128
			Uj <= 32'd128;
			Vj <= 32'd128;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Rodd <= 32'd0 + MULTI_RGB;// Rodd (0 + a00*Yodd')
			Godd <= 32'd0 + MULTI_RGB;// Godd (0 + a00*Yodd')
			Bodd <= 32'd0 + MULTI_RGB;//Bodd (0 + a00*Yodd')
			
			data_counter <= data_counter + 18'd1;
			
			M1_state <= CC_12;
			 
		end
		CC_12: begin
		
			/**Interpolation**/
			UVY_data[2] <= SRAM_read_data;//store UevenUodd
			
			//21*U 21*V
			Mult_op_U <= u_1;//V  
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_1;//V
			
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Rodd <= Rodd + MULTI_RGB;// Rodd (aoo*Yodd' + a02*Vodd')
			
			y_counter <= y_counter + 18'd1;
			
			M1_state <= CC_13;
			 
		end	
		CC_13: begin
		
			/**Interpolation**/
			UVY_data[1] <= SRAM_read_data;//store VevenVodd
			
			u_6 <= UVY_data[2][15:8];//Unext_even
			
			//-52*U -52*V
			Mult_op_U <= u_2;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_2;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd' + a11*Uodd')
		
			M1_state <= CC_14;
			
			 
		end
		CC_14: begin
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			SRAM_we_n <= 1'b0; //write
			
			//write Reven,Geven
			SRAM_write_data <= {RE[7:0], GE[7:0]};
			
			/**Interpolation**/
			UVY_data[0] <= SRAM_read_data;//store YevenYodd
			
			v_6 <= UVY_data[1][15:8];//Vnext_even
			
			//159*U 159*V
		   Mult_op_U <= u_3;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_3;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd' + a11*Uodd' + a12Vodd')
						
			M1_state <= CC_15;
			 
		end
		
		CC_15 : begin
			
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			
			//write Beven,Rodd
			SRAM_write_data <= {BE[7:0], RO[7:0]};
			
			/**Interpolation**/
			//set YUVeven'
			Y <= UVY_data[0][15:8];//Yeven'
			U <= u_3;//Ueven'
			V <= v_3;//Veven'
			
			//159*U 159*V
		   Mult_op_U <= u_4;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_4;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Yeven'
			
			Bodd <= Bodd + MULTI_RGB;// Bodd (a00*Yodd' + a21*Uodd')
			
			M1_state <= CC_16;
		end
		
		CC_16 : begin
			
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			 
			//write Godd,Bodd
			SRAM_write_data <= {GO[7:0], BO[7:0]};
			
			/**Interpolation**/
			 //-52*U, -52*V
		   Mult_op_U <= u_5;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_5;//V
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Reven <= 32'd0 + MULTI_RGB;// Reven (0 + a00*Yeven')
			Geven <= 32'd0 + MULTI_RGB;// Geven (0 + a00*Yeven')
			Beven <= 32'd0 + MULTI_RGB;//Beven (0 + a00*Yeven')
			 
			M1_state <= CC_17;
		end
		
		CC_17 : begin
			SRAM_we_n <= 1'b1; //read
			
			/**Interpolation**/
			 //21*U 21*V
		   Mult_op_U <= u_6;   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_6;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Reven <= Reven + MULTI_RGB;// Reven (aoo*Yeven' + a02*Veven')
		
			M1_state <= CC_18;
		end
		
		CC_18: begin
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven)

			M1_state <= CC_19;
			 
		end
		
		CC_19: begin
		
			/**Interpolation**/
			Uj <= (Uj + Mult_result_U) >>> 8;
			Vj <= (Vj + Mult_result_V) >>> 8;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven + a12Veven)

		
			M1_state <= CC_20;
			 
		end
		
		CC_20: begin
			
			/**Interpolation**/
			Y <= UVY_data[0][7:0];//Yodd'
			U <= Uj[7:0];//Uodd'
			V <= Vj[7:0];//Vodd'
			
			u_1 <= u_2;//U0
			u_2 <= u_3;//U0
			u_3 <= u_4;//U1
			u_4 <= u_5;//U2
			u_5 <= u_6;//U3
			
			v_1 <= v_2;//V0
			v_2 <= v_3;//V0
			v_3 <= v_4;//V1
			v_4 <= v_5;//V2
			v_5 <= v_6;//V3

			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][7:0]; // Yodd'

			Beven <= Beven + MULTI_RGB;// Beven (a00*Yeven + a21*Ueven)
			
			M1_state <= CC_21;
			 
		end
		
		CC_21: begin
			
			SRAM_address <= y_counter + Y_START_ADDRESS;//YevenYodd
			
			/**Interpolation**/
			// reset Uj, Vj to 128
			Uj <= 32'd128;
			Vj <= 32'd128;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Rodd <= 32'd0 + MULTI_RGB;// Rodd (0 + a00*Yodd')
			Godd <= 32'd0 + MULTI_RGB;// Godd (0 + a00*Yodd')
			Bodd <= 32'd0 + MULTI_RGB;//Bodd (0 + a00*Yodd')
			
			
			M1_state <= CC_22;
			 
		end
		CC_22: begin
			
			/**Interpolation**/
			//21*U 21*V
			Mult_op_U <= u_1;//V  
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_1;//V
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Rodd <= Rodd + MULTI_RGB;// Rodd (aoo*Yodd + a02*Vodd)
			
			y_counter <= y_counter + 18'd1;
			
			M1_state <= CC_23;
			 
		end	
		CC_23: begin
			
			/**Interpolation**/
			u_6 <= UVY_data[2][7:0];//Unext_odd
			
			//-52*U -52*V
			Mult_op_U <= u_2;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_2;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd + a11*Uodd)
		
			
			M1_state <= CC_24;
			 
		end
		CC_24: begin
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			SRAM_we_n <= 1'b0; //write
			
			//write Reven,Geven
			SRAM_write_data <= {RE[7:0], GE[7:0]};
		
			/**Interpolation**/
			UVY_data[0] <= SRAM_read_data;//store YevenYodd
			
			v_6 <= UVY_data[1][7:0];//Vnext_odd
			
			//159*U 159*V
		   Mult_op_U <= u_3;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_3;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Godd <= Godd + MULTI_RGB;// G0 (a00*Y0 + a11*U0 + a12V0)
			
			M1_state <= CC_25;
			 
		end
		
		CC_25 : begin
		
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
		
			//write Beven,Rodd
			SRAM_write_data <= {BE[7:0], RO[7:0]};
			
			/**Interpolation**/
			//set YUVeven'
			Y <= UVY_data[0][15:8];//Yeven'
			U <= u_3;//Ueven'
			V <= v_3;//Veven'
			
			//159*U 159*V
		   Mult_op_U <= u_4;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_4;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;

			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Yeven'
			
			Bodd <= Bodd + MULTI_RGB;// Bodd (a00*Yodd + a21*Uodd)
			
			M1_state <= CC_26;
		end
		
		CC_26 : begin
		
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			
			//write Godd,Bodd
			SRAM_write_data <= {GO[7:0], BO[7:0]};
			
			/**Interpolation**/
			 //-52*U, -52*V
		   Mult_op_U <= u_5;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_5;//V
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Reven <= 32'd0 + MULTI_RGB;// Reven (0 + a00*Yeven)
			Geven <= 32'd0 + MULTI_RGB;// Geven (0 + a00*Yeven)
			Beven <= 32'd0 + MULTI_RGB;//Beven (0 + a00*Yeven)
			
			M1_state <= CC_27;
		end
		
		CC_27 : begin
			 
			SRAM_we_n <= 1'b1; //read
			
			/**Interpolation**/
			 //21*U1 21*V1
		   Mult_op_U <= u_6;   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_6;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Reven <= Reven + MULTI_RGB;// Reven (aoo*Yeven + a02*Veven)
		
			M1_state <= CC_28;
			
		end
		
		CC_28 : begin
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven)
			
			M1_state <= CC_29;
			
		end
		
		CC_29 : begin
			
			/**Interpolation**/
			Uj <= (Uj + Mult_result_U) >>> 8;
			Vj <= (Vj + Mult_result_V) >>> 8;
				
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven + a12Veven)
			
			if (y_counter - y_loop_counter == 18'd157) begin
				M1_state <= LO_30; // exit common case
			end else begin
				M1_state <= CC_10; // go back to common case
				SRAM_address <= data_counter + U_START_ADDRESS;//UevenUodd
			end
			
		end
		
	/****** END COMMON CASE *******/
	
	/****** BEGIN LEAD OUT *******/
	
		LO_30: begin
			
			/**Interpolation**/ 
			Y <= UVY_data[0][7:0];//Yodd'
			U <= Uj[7:0];//Uodd'
			V <= Vj[7:0];//Vodd'
			
			u_1 <= u_2;//U155
			u_2 <= u_3;//U156
			u_3 <= u_4;//U157
			u_4 <= u_5;//U158
			u_5 <= u_6;//U159
			u_6 <= u_6;//U159
			
			v_1 <= v_2;//V155
			v_2 <= v_3;//V156
			v_3 <= v_4;//V157
			v_4 <= v_5;//V158
			v_5 <= v_6;//V159
			v_6 <= v_6;//V159
		
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][7:0]; // Yodd'
			
			Beven <= Beven + MULTI_RGB;// B0 (a00*Y0 + a21*U0)

			M1_state <= LO_31;
			 
		end
		LO_31: begin
			SRAM_address <= y_counter + Y_START_ADDRESS;//YevenYodd
			
			/**Interpolation**/
			// reset Uj, Vj to 128
			Uj <= 32'd128;
			Vj <= 32'd128;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Rodd <= 32'd0 + MULTI_RGB;// Rodd (0 + a00*Yodd')
			Godd <= 32'd0 + MULTI_RGB;// Godd (0 + a00*Yodd')
			Bodd <= 32'd0 + MULTI_RGB;//Bodd (0 + a00*Yodd')
			
			data_counter <= data_counter + 18'd1;
			
			M1_state <= LO_32;
			 
		end
		LO_32: begin
		
			/**Interpolation**/			
			//21*U 21*V
			Mult_op_U <= u_1;//V  
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_1;//V
			
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Rodd <= Rodd + MULTI_RGB;// Rodd (aoo*Yodd' + a02*Vodd')
			
			y_counter <= y_counter + 18'd1;
			
			M1_state <= LO_33;
			 
		end	
		LO_33: begin
		
			/**Interpolation**/	
			//-52*U -52*V
			Mult_op_U <= u_2;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_2;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd + a11*Uodd)
		
			M1_state <= LO_34;
			
			 
		end
		LO_34: begin
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			SRAM_we_n <= 1'b0; //write
			
			//write Reven,Geven
			SRAM_write_data <= {RE[7:0], GE[7:0]};
			
			/**Interpolation**/
			UVY_data[0] <= SRAM_read_data;//store YevenYodd
			
			//159*U0 159*V0
		   Mult_op_U <= u_3;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_3;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			 
			Godd <= Godd + MULTI_RGB;// G0 (a00*Y0 + a11*U0 + a12V0)
						
			M1_state <= LO_35;
			 
		end
		
		LO_35 : begin
			
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			
			//write Beven,Rodd
			SRAM_write_data <= {BE[7:0], RO[7:0]};
			
			/**Interpolation**/
			//set YUVeven'
			Y <= UVY_data[0][15:8];//Yeven'
			U <= u_3;//Ueven'
			V <= v_3;//Veven'
			
			//159*U 159*V
		   Mult_op_U <= u_4;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_4;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Yeven'
			
			Bodd <= Bodd + MULTI_RGB;// Bodd (a00*Yodd + a21*Uodd)
			
			
			M1_state <= LO_36;
		end
		
		LO_36 : begin
			
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			 
			//write Godd,Bodd
			SRAM_write_data <= {GO[7:0], BO[7:0]};
			
			/**Interpolation**/
			 //-52*U, -52*V
		   Mult_op_U <= u_5;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_5;//V
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Reven <= 32'd0 + MULTI_RGB;// Reven (0 + a00*Yeven)
			Geven <= 32'd0 + MULTI_RGB;// Geven (0 + a00*Yeven)
			Beven <= 32'd0 + MULTI_RGB;//Beven (0 + a00*Yeven)
			 
			M1_state <= LO_37;
		end
		
		LO_37 : begin
			SRAM_we_n <= 1'b1; //read
			
			/**Interpolation**/
			 //21*U 21*V
		   Mult_op_U <= u_6;   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_6;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Reven <= Reven + MULTI_RGB;// Reven (aoo*Yeven' + a02*Veven')
		
			M1_state <= LO_38;
		end
		
		LO_38: begin
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven)

		
			M1_state <= LO_39;
			 
		end
		
		LO_39: begin
		
			/**Interpolation**/
			Uj <= (Uj + Mult_result_U) >>> 8;
			Vj <= (Vj + Mult_result_V) >>> 8;
		
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven + a12Veven)

		
			M1_state <= LO_40;
			 
		end
		
		LO_40: begin
			/**Interpolation**/	
			Y <= UVY_data[0][7:0];//Yodd'
			U <= Uj[7:0];//Uodd'
			V <= Vj[7:0];//Vodd'
			
			u_1 <= u_2;//U156
			u_2 <= u_3;//U157
			u_3 <= u_4;//U158
			u_4 <= u_5;//U159
			u_5 <= u_6;//U159
			u_6 <= u_6;//U159
			
			v_1 <= v_2;//V156
			v_2 <= v_3;//V157
			v_3 <= v_4;//V158
			v_4 <= v_5;//V159
			v_5 <= v_6;//V159
			v_6 <= v_6;//V159

			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][7:0]; // Yodd'
			
			Beven <= Beven + MULTI_RGB;// Beven (a00*Yeven + a21*Ueven)
		
			M1_state <= LO_41;
			 
		end
		
		LO_41: begin
			SRAM_address <= y_counter + Y_START_ADDRESS;//YevenYodd
			
			/**Interpolation**/
			// reset Uj, Vj to 128
			Uj <= 32'd128;
			Vj <= 32'd128;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Rodd <= 32'd0 + MULTI_RGB;// Rodd (0 + a00*Yodd')
			Godd <= 32'd0 + MULTI_RGB;// Godd (0 + a00*Yodd')
			Bodd <= 32'd0 + MULTI_RGB;//Bodd (0 + a00*Yodd')
			
			M1_state <= LO_42;
			 
		end
		LO_42: begin
			
			/**Interpolation**/
			//21*U 21*V
			Mult_op_U <= u_1;//V  
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_1;//V
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Rodd <= Rodd + MULTI_RGB;// Rodd (aoo*Yodd + a02*Vodd)
			
			y_counter <= y_counter + 18'd1;
			
			M1_state <= LO_43;
			 
		end	
		LO_43: begin
			
			/**Interpolation**/
			//-52*U -52*V
			Mult_op_U <= u_2;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_2;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd + a11*Uodd)
		
			
			M1_state <= LO_44;
			 
		end
		LO_44: begin
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			SRAM_we_n <= 1'b0; //write
			
			//write Reven,Geven
			SRAM_write_data <= {RE[7:0], GE[7:0]};
		
			/**Interpolation**/
			UVY_data[0] <= SRAM_read_data;//store YevenYodd
			
			
			//159*U 159*V
		   Mult_op_U <= u_3;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_3;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Godd <= Godd + MULTI_RGB;// G0 (a00*Y0 + a11*U0 + a12V0)
			
			M1_state <= LO_45;
			 
		end
		
		LO_45 : begin
		
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
		
			//write Beven,Rodd
			SRAM_write_data <= {BE[7:0], RO[7:0]};
			
			/**Interpolation**/
			//set YUVeven'
			Y <= UVY_data[0][15:8];//Yeven'
			U <= u_3;//Ueven'
			V <= v_3;//Veven'
			
			//159*U 159*V
		   Mult_op_U <= u_4;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_4;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;

			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Yeven'
			
			Bodd <= Bodd + MULTI_RGB;// Bodd (a00*Yodd + a21*Uodd)
			
			M1_state <= LO_46;
		end
		
		LO_46 : begin
		
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			
			//write Godd,Bodd
			SRAM_write_data <= {GO[7:0], BO[7:0]};
			
			/**Interpolation**/
			 //-52*U, -52*V
		   Mult_op_U <= u_5;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_5;//V
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Reven <= 32'd0 + MULTI_RGB;// Reven (0 + a00*Yeven)
			Geven <= 32'd0 + MULTI_RGB;// Geven (0 + a00*Yeven)
			Beven <= 32'd0 + MULTI_RGB;//Beven (0 + a00*Yeven)
			
			M1_state <= LO_47;
		end
		
		LO_47 : begin
			 
			SRAM_we_n <= 1'b1; //read
			
			/**Interpolation**/
			 //21*U1 21*V1
		   Mult_op_U <= u_6;   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_6;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Reven <= Reven + MULTI_RGB;// Reven (aoo*Yeven + a02*Veven)
		
			M1_state <= LO_48;
			
		end
		
		LO_48 : begin	
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven)

			M1_state <= LO_49;
			
		end
		
		LO_49 : begin
		
			/**Interpolation**/
			Uj <= (Uj + Mult_result_U) >>> 8;
			Vj <= (Vj + Mult_result_V) >>> 8;
				
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven + a12Veven)
			
			M1_state <= LO_50;
			
		end
		
		LO_50: begin
			
			/**Interpolation**/ 
			Y <= UVY_data[0][7:0];//Yodd'
			U <= Uj[7:0];//Uodd'
			V <= Vj[7:0];//Vodd'
			
			u_1 <= u_2;//U157
			u_2 <= u_3;//U158
			u_3 <= u_4;//U159
			u_4 <= u_5;//U159
			u_5 <= u_6;//U159
			u_6 <= u_6;//U159
			
			v_1 <= v_2;//V157
			v_2 <= v_3;//V158
			v_3 <= v_4;//V159
			v_4 <= v_5;//V159
			v_5 <= v_6;//V159
			v_6 <= v_6;//V159
		
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][7:0]; // Yodd'
			
			Beven <= Beven + MULTI_RGB;// B0 (a00*Y0 + a21*U0)


			M1_state <= LO_51;
			 
		end
		
		LO_51: begin
			SRAM_address <= y_counter + Y_START_ADDRESS;//YevenYodd
			
			/**Interpolation**/
			// reset Uj, Vj to 128
			Uj <= 32'd128;
			Vj <= 32'd128;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Rodd <= 32'd0 + MULTI_RGB;// Rodd (0 + a00*Yodd')
			Godd <= 32'd0 + MULTI_RGB;// Godd (0 + a00*Yodd')
			Bodd <= 32'd0 + MULTI_RGB;//Bodd (0 + a00*Yodd')
			
			data_counter <= data_counter + 18'd1;
			
			M1_state <= LO_52;
			 
		end
		LO_52: begin
		
			/**Interpolation**/
			//21*U 21*V
			Mult_op_U <= u_1;//V  
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_1;//V
			
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Rodd <= Rodd + MULTI_RGB;// Rodd (aoo*Yodd + a02*Vodd)
			
			y_counter <= y_counter + 18'd1;
			
			M1_state <= LO_53;
			 
		end	
		LO_53: begin
		
			/**Interpolation**/
			
			//-52*U -52*V
			Mult_op_U <= u_2;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_2;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd + a11*Uodd)
		
			M1_state <= LO_54;
			
			 
		end
		LO_54: begin
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			SRAM_we_n <= 1'b0; //write
			
			//write Reven,Geven
			SRAM_write_data <= {RE[7:0], GE[7:0]};
			
			/**Interpolation**/
			UVY_data[0] <= SRAM_read_data;//store YevenYodd
			
			//159*U0 159*V0
		   Mult_op_U <= u_3;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_3;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Godd <= Godd + MULTI_RGB;// G0 (a00*Y0 + a11*U0 + a12V0)
						
			M1_state <= LO_55;
			 
		end
		
		LO_55 : begin
			
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			
			//write Beven,Rodd
			SRAM_write_data <= {BE[7:0], RO[7:0]};
			
			/**Interpolation**/
			//set YUVeven'
			Y <= UVY_data[0][15:8];//Yeven'
			U <= u_3;//Ueven'
			V <= v_3;//Veven'
			
			//159*U 159*V
		   Mult_op_U <= u_4;   
			Mult_op_C <= 9'sd159;//159
			Mult_op_V <= v_4;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Yeven'
			
			Bodd <= Bodd + MULTI_RGB;// Bodd (a00*Yodd + a21*Uodd)
			
			M1_state <= LO_56;
		end
		
		LO_56 : begin
			
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			 
			//write Godd,Bodd
			SRAM_write_data <= {GO[7:0], BO[7:0]};
			
			/**Interpolation**/
			 //-52*U, -52*V
		   Mult_op_U <= u_5;   
			Mult_op_C <= -9'sd52;//52
			Mult_op_V <= v_5;//V
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Reven <= 32'd0 + MULTI_RGB;// Reven (0 + a00*Yeven)
			Geven <= 32'd0 + MULTI_RGB;// Geven (0 + a00*Yeven)
			Beven <= 32'd0 + MULTI_RGB;//Beven (0 + a00*Yeven)
			 
			M1_state <= LO_57;
		end
		
		LO_57 : begin
			SRAM_we_n <= 1'b1; //read
			
			/**Interpolation**/
			 //21*U 21*V
		   Mult_op_U <= u_6;   
			Mult_op_C <= 9'sd21;//21
			Mult_op_V <= v_6;
			
			Uj <= Uj + Mult_result_U;
			Vj <= Vj + Mult_result_V;
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Reven <= Reven + MULTI_RGB;// Reven (aoo*Yeven + a02*Veven)
		
			M1_state <= LO_58;
		end
		
		LO_58: begin
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven)
		
			M1_state <= LO_59;
			 
		end
		
		LO_59: begin
		
			/**Interpolation**/
			Uj <= (Uj + Mult_result_U) >>> 8;
			Vj <= (Vj + Mult_result_V) >>> 8;
		
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Geven <= Geven + MULTI_RGB;// Geven (a00*Yeven + a11*Ueven + a12Veven)

			M1_state <= LO_60;
			 
		end
		
		LO_60: begin
			/**Interpolation**/
			Y <= UVY_data[0][7:0];//Yodd'
			U <= Uj[7:0];//Uodd'
			V <= Vj[7:0];//Vodd'

			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][7:0]; // Yodd'
			
			Beven <= Beven + MULTI_RGB;// Beven (a00*Yeven + a21*Ueven)
		
			M1_state <= LO_61;
			 
		end
		
		LO_61: begin
			
			/**Color Conversion**/
			coeff <= 32'sd104595; //a02
			Mult_op_UVY <= V;
			
			Rodd <= 32'd0 + MULTI_RGB;// Rodd (0 + a00*Yodd')
			Godd <= 32'd0 + MULTI_RGB;// Godd (0 + a00*Yodd')
			Bodd <= 32'd0 + MULTI_RGB;//Bodd (0 + a00*Yodd')
			
			M1_state <= LO_62;
			 
		end
		LO_62: begin
			
			/**Color Conversion**/
			coeff <= -32'sd25624; //a11
			Mult_op_UVY <= U;
			
			Rodd <= Rodd + MULTI_RGB;// Rodd (aoo*Yodd + a02*Vodd)
			
			M1_state <= LO_63;
			 
		end	
		LO_63: begin
			
			/**Color Conversion**/
			coeff <= -32'sd53281; //a12
			Mult_op_UVY <= V;
			
			Godd <= Godd + MULTI_RGB;// Godd (a00*Yodd + a11*Uodd)
		
			
			M1_state <= LO_64;
			 
		end
		LO_64: begin
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			SRAM_we_n <= 1'b0; //write
			
			//write Reven,Geven
			SRAM_write_data <= {RE[7:0], GE[7:0]};
			
			/**Color Conversion**/
			coeff <= 32'sd132251; //a21
			Mult_op_UVY <= U;
			
			Godd <= Godd + MULTI_RGB;// G0 (a00*Y0 + a11*U0 + a12V0)
			
			M1_state <= LO_65;
			 
		end
		
		LO_65 : begin
		
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
		
			//write Beven,Rodd
			SRAM_write_data <= {BE[7:0], RO[7:0]};

			/**Color Conversion**/
			coeff <= 32'sd76284; //a00
			Mult_op_UVY <= UVY_data[0][15:8];//Yeven'
			
			Bodd <= Bodd + MULTI_RGB;// Bodd (a00*Yodd + a21*Uodd)
			
			M1_state <= LO_66;
		end
		
		LO_66 : begin
		
			// indicate RGB SRAM address
			SRAM_address <= RGB_address + RGB_write_counter;
			RGB_write_counter <= RGB_write_counter + 18'd1;
			
			//write Godd,Bodd
			SRAM_write_data <= {GO[7:0], BO[7:0]};
			
			M1_state <= LO_finish;
		end
		
		/****** END LEAD OUT *******/
		
	   
      LO_finish : begin
			SRAM_we_n <= 1'b1; // read
			
			if (y_counter == 18'd38400) begin //completed all pixels 320*240
				M1_state <= M1_finish;
			end
			else begin // go back to do the next row
				data_counter <= data_counter - 18'd2;
				y_loop_counter <= y_counter;
				M1_state <= M1_IDLE;
			end
		end
		
		M1_finish : begin
			done <= 1'b1;
			M1_state <= M1_IDLE;
		end
		
		default : M1_state <= M1_IDLE;
		endcase
	end //END OF IF RESETN
//END OF FLIP FLOP
end
///////

assign op_U_extended = {23'd0, Mult_op_U}; //extension for OP1 (U)
assign op_C_extended = {{23{Mult_op_C[8]}},Mult_op_C}; //extension for OP2 (coeff)
assign op_V_extended = {23'd0, Mult_op_V}; //extension for OP1 (V)

// multipliers for U
assign Mult_result_long_U = op_U_extended * op_C_extended;
assign Mult_result_U = Mult_result_long_U[31:0];

// multipliers for V
assign Mult_result_long_V = op_V_extended * op_C_extended;
assign Mult_result_V = Mult_result_long_V[31:0];

assign op_UVY_math = (coeff == 32'sd76284) ? Mult_op_UVY - 32'd16 : Mult_op_UVY - 32'd128;//OP UVY subtraction

// get matrix terms of RGB
assign MULTI_RGB = coeff * op_UVY_math; // multiply RGB coeff with U'- 128 or V'- 128 or Y'- 16

assign RE = (Reven[31]) ? 8'd0 : (|Reven[30:24]) ? 8'd255 : Reven[23:16];
assign GE = (Geven[31]) ? 8'd0 : (|Geven[30:24]) ? 8'd255 : Geven[23:16];
assign BE = (Beven[31]) ? 8'd0 : (|Beven[30:24]) ? 8'd255 : Beven[23:16];

assign RO = (Rodd[31]) ? 8'd0 : (|Rodd[30:24]) ? 8'd255 : Rodd[23:16];
assign GO = (Godd[31]) ? 8'd0 : (|Godd[30:24]) ? 8'd255 : Godd[23:16];
assign BO = (Bodd[31]) ? 8'd0 : (|Bodd[30:24]) ? 8'd255 : Bodd[23:16];

endmodule