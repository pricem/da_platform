

module usbp_myhdl_top
(
 // FX2 Interface Signals, for USB 2.0
 input  wire RESET,          ///
 //input  wire CLKOUT,         //  
 //output wire WAKEUP,         ///
 
 input  wire IFCLK,          /// Should be @ 48MHz clock
 input  wire FLAGA,          /// EP2(OUT) Empty
 input  wire FLAGB,          /// EP4(OUT) Empty_n 
 input  wire FLAGC,          /// EP6(IN)  Full
 input  wire FLAGD,          /// EP8(IN)  Full_n
 output wire SLOE,           /// Output Enable, Slave FIFO
 output wire SLRD,           /// Read Signal
 output wire SLWR,           /// Write Signal
 output wire [1:0] FIFOADR,  /// Which of the 4 FIFO currently interfacing with.
 output wire PKTEND,         /// Packet End, Tell FX2 to send data without FIFO Full
 inout  wire [7:0] FD,       /// FIFO Data 
 
 // Misc Dev Board Inputs and Outputs
 output wire [7:0]  LED     /// 8 LEDs
 
);


`ifdef _INCLUDE_SPI_TWI_
 // SPI signals
 output wire [7:0] SS,       /// Slave select lines
 output wire SCK,            /// SPI clock
 output wire MOSI,           /// Master out, slave in
 input  wire MISO,           /// Master in, slave out
 
 inout  SCL,                 /// TWI clock
 inout  SDA,                 /// TWI data
 
 /**
  * Total 33 header pins, dedicate 1 to a clock, 16 for testpoints
  * 16 for interfacing.  
  */
 // Dedicated testpoints and external clock
 output wire HDR_CLK        // IFCLK (48MHz) replicated to the test headers 
 //output wire [15:0] HDR_TP   // 16 signals to header, testpoints for now
`endif   
	
	
   wire [7:0] fdi, fdo;
   wire       rst_sync;
   wire       sys_clk = IFCLK;
   wire       SCL_o, SCL_i, SDA_o, SDA_i;

   /// Create sync reset
   reg [7:0]  rRst;         // Reset Sysnc Pipeline
   reg 	      rff;
   wire       wreset;
   assign  wreset = ~rff | ~RESET;
   assign  rst_sync = rRst[7] | wreset;
   always @(posedge sys_clk or negedge RESET) begin
      if(~RESET) 
        rRst <= 8'hFF;
      else
        rRst <= {rRst[6:0], wreset};
   end

   always @(posedge sys_clk) begin
      rff <= 1'b1;
   end

   
   /// Create DCM for clocks

   
   /// Create tri-states for FX2 USB bus
   assign  fdi = FD;
   assign  FD  = (~SLOE) ? fdo : 8'bz;

	assign  SCL = (~SCL_o) ? 1'b0 : 1'bz;
	assign  SDA = (~SDA_o) ? 1'b0 : 1'bz;
	assign  SCL_i = SCL;
	assign  SDA_i = SDA;
   
   /// MyHDL logic
   usbp_myhdl
     myhdl
       (
        .reset(rst_sync),
	.sys_clk(sys_clk),
	.IFCLK(IFCLK),
	.FLAGA(FLAGA),
	.FLAGB(FLAGB),
	.FLAGC(FLAGC),
	.FLAGD(FLAGD),
	.SLOE(SLOE),
	.SLRD(SLRD),
	.SLWR(SLWR),
	.FIFOADR(FIFOADR),
	.PKTEND(PKTEND),
	.FDI(fdi),
	.FDO(fdo),
	.LEDs(LED),
	.SS(SS),
	.SCK(SCK),
	.MOSI(MOSI),
	.MISO(MISO),
	.SCL_i(SCL_i),
	.SCL_o(SCL_o),
	.SDA_i(SDA_i),
	.SDA_o(SDA_o)
	//.TP_HDR(TP_HDR)
	);
	

   /// Replicate the clock out to the header
   wire    clk   = IFCLK;
   wire    clk_n = ~clk;
   OFDDRCPE 
     DDR_CLK 
       (
        .Q(HDR_CLK),    // Data output (connect directly to top-level port)
        .C0(clk),       // 0 degree clock input
        .C1(clk_n),     // 180 degree clock input
        .CE(1'b1),      // Clock enable input
        .CLR(rst_sync), // Asynchronous reset input
        .D0(1'b1),      // Posedge data input
        .D1(1'b0),      // Negedge data input
        .PRE(1'b0)      // Asynchronous preset input
	);
   
endmodule
