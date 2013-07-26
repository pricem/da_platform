module
	top_level(
		// FX2 interface -----------------------------------------------------------------------------
		input  wire      fx2Clk_in,     // 48MHz clock from FX2
		output wire[1:0] fx2Addr_out,   // select FIFO: "10" for EP6OUT, "11" for EP8IN
		inout  wire[7:0] fx2Data_io,    // 8-bit data to/from FX2

		// When EP6OUT selected:
		output wire      fx2Read_out,   // asserted (active-low) when reading from FX2
		output wire      fx2OE_out,     // asserted (active-low) to tell FX2 to drive bus
		input  wire      fx2GotData_in, // asserted (active-high) when FX2 has data for us

		// When EP8IN selected:
		output wire      fx2Write_out,  // asserted (active-low) when writing to FX2
		input  wire      fx2GotRoom_in, // asserted (active-high) when FX2 has room for more data from us
		output wire      fx2PktEnd_out, // asserted (active-low) when a host read needs to be committed early

        input wire gclk0,   //  Nexys2 50 MHz clock
        input wire reset,   //  User button 0
		
        inout wire [7:0]  pmod1, 
		inout wire [7:0]  pmod2, 
		inout wire [7:0]  pmod3, 
		inout wire [7:0]  pmod4
	);

	// Channel read/write interface -----------------------------------------------------------------
	wire[6:0]  chanAddr;  // the selected channel (0-127)

	// Host >> FPGA pipe:
	wire[7:0]  h2fData;   // data lines used when the host writes to a channel
	wire       h2fValid;  // '1' means "on the next clock rising edge, please accept the data on h2fData_out"
	wire       h2fReady;  // channel logic can drive this low to say "I'm not ready for more data yet"

	// Host << FPGA pipe:
	wire[7:0]  f2hData;   // data lines used when the host reads from a channel
	wire       f2hValid;  // channel logic can drive this low to say "I don't have data ready for you"
	wire       f2hReady;  // '1' means "on the next clock rising edge, put your next byte of data on f2hData_in"
	// ----------------------------------------------------------------------------------------------
	
	// Needed so that the comm_fpga_fx2 module can drive both fx2Read_out and fx2OE_out
	wire       fx2Read;

	// Flags for display on the 7-seg decimal points
	wire[3:0]  flags;

	// FIFOs
	wire[15:0] fifoCount;        // MSB=writeFifo, LSB=readFifo

	// Write FIFO:
	wire[7:0]  writeFifoInputData;    // producer: data
	wire       writeFifoInputValid;   //           valid flag
	wire       writeFifoInputReady;   //           ready flag
	wire[7:0]  writeFifoOutputData;   // consumer: data
	wire       writeFifoOutputValid;  //           valid flag
	wire       writeFifoOutputReady;  //           ready flag

	// Read FIFO:
	wire[7:0]  readFifoInputData;     // producer: data
	wire       readFifoInputValid;    //           valid flag
	wire       readFifoInputReady;    //           ready flag
	wire[7:0]  readFifoOutputData;    // consumer: data
	wire       readFifoOutputValid;   //           valid flag
	wire       readFifoOutputReady;   //           ready flag

	// CommFPGA module
	assign fx2Read_out = fx2Read;
	assign fx2OE_out = fx2Read;
	assign fx2Addr_out[1] = 1'b1;  // Use EP6OUT/EP8IN, not EP2OUT/EP4IN.
	comm_fpga_fx2 comm_fpga_fx2(
		// FX2 interface
		.fx2Clk_in(fx2Clk_in),
		.fx2FifoSel_out(fx2Addr_out[0]),
		.fx2Data_io(fx2Data_io),
		.fx2Read_out(fx2Read),
		.fx2GotData_in(fx2GotData_in),
		.fx2Write_out(fx2Write_out),
		.fx2GotRoom_in(fx2GotRoom_in),
		.fx2PktEnd_out(fx2PktEnd_out),

		// Channel read/write interface
		.chanAddr_out(chanAddr),
		.h2fData_out(h2fData),
		.h2fValid_out(h2fValid),
		.h2fReady_in(h2fReady),
		.f2hData_in(f2hData),
		.f2hValid_in(f2hValid),
		.f2hReady_out(f2hReady)
	);

	wire [5:0] slotdata3;
	wire [5:0] slotdata2;

    //  DAC driving module
    da_platform main(
	    .clk_nexys(gclk0), 
		.clk_fx2(fx2Clk_in), 
		.reset(reset),

		.chanAddr(chanAddr), 
		.h2fData(h2fData), 
		.h2fValid(h2fValid), 
		.h2fReady(h2fReady), 
		.f2hData(f2hData), 
		.f2hValid(f2hValid), 
		.f2hReady(f2hReady),

		.slotdata({
			slotdata3, 
			slotdata2, 
			pmod2[0], pmod2[1], pmod1[2], pmod1[3], pmod1[0], pmod1[1],	//	Slot 1
			pmod2[5], pmod2[4], pmod1[7], pmod1[6], pmod1[5], pmod1[4] 	//	Slot 0
		}),
		.mclk(pmod3[1]), 
		.amcs(pmod3[0]), 
		.amdi(pmod3[2]), 
		.amdo(pmod3[3]), 
		.dmcs(pmod4[0]), 
		.dmdi(pmod4[1]), 
		.dmdo(pmod4[2]), 
		.dirchan(pmod4[3]), 
		.acon({pmod3[6], pmod3[7]}), 
		.aovf(pmod3[5]), 
		.clk0(pmod3[4]), 
		.reset_out(pmod4[7]), 
		.srclk(pmod4[6]), 
		.clksel(pmod4[5]), 
		.clk1(pmod4[4])
	);
	
	
	
endmodule
