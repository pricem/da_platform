module
	dac_demo(
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
        output wire [3:0] pmod1a_data
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

    //  DAC driving module
    dac_control dac_ctl(
        .clk_in(gclk0), 
        .reset(reset), 
        .clk_fx2(fx2Clk_in),
        .chanAddr(chanAddr), 
        .h2fData(h2fData), 
        .h2fValid(h2fValid), 
        .h2fReady(h2fReady), 
        .f2hData(f2hData), 
        .f2hValid(f2hValid), 
        .f2hReady(f2hReady),
        .dac_sclk(pmod1a_data[3]), 
        .dac_dina(pmod1a_data[1]), 
        .dac_dinb(pmod1a_data[2]), 
        .dac_sync(pmod1a_data[0])
    );

endmodule
