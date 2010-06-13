    integer a;


    initial begin
        power_up;
        async_write(1, 16'b00000000_0_00_1_0_000 | RCR<<REG_SEL, {DQ_BITS{1'bz}}, 0, 0);
        idle(0);
        nop (max(tVPH, tCPH));
        //                                          98 7654321098 7 65 4 3 210 
        //                                          |    |        |  | | |  |
        //  FIRST   *RCR REG DEF*                   |    |        |  | | |  --------------> PAR 
        //  LOOK                                    |    |        |  | | |                  000 => Full array (default)
        //  HERE                                    |    |        |  | | |                  001 => Bottom 1/2
        //   |                                      |    |        |  | | -> Reserved        010 => Bottom 1/4
        //   |                                      |    |        |  | |                    011 => Bottom 1/8
        //   |        Register Select  <-------------    |        |  | -> Deep Pwr Down     100 => None
        //   |        00=RCR                             |        |  |    0=Deep Pwr Dn.    101 => Top 1/2
        //   -------->10=BCR                             |        |  |    1=Off (default)   110 => Top 1/4
        //            01=DIDR *CR1.5* ONLY               |        |  |                      111 => Top 1/8
        //                                               |        |  -> Reserved           
        //                                               |        |              
        //                                               |        --> Page Mode
        //                                               |            0-Disabled
        //               Reserved set to 0 <--------------            1-Enabled
        //                
                                        
            
        a = (16'b0_0_011_0_0_0_01_00_1_010 & BCR_MASK[15:0]) | (BCR_DEFAULT & ~BCR_MASK[15:0]) | BCR<<REG_SEL;
        async_write(1, a, {DQ_BITS{1'bz}}, 0, 1);  //put in sync mode
        idle(0);
        nop (tCPH);
        //                                          98 76 5 4 321 0 9 8 76 54 3 210 
        //                                          |  |  | |  |  | | |  | |  |  |               
        //  FIRST   *BCR REG DEF*                   |  |  | |  |  | | |  | |  |  --------------->Burst Length:
        //  LOOK                                    |  |  | |  |  | | |  | |  |                  001    =>  4 words 
        //  HERE                                    |  |  | |  |  | | |  | |  |                  010    =>  8 words
        //   |                                      |  |  | |  |  | | |  | |  |                  011    => 16 words
        //   |                                      |  |  | |  |  | | |  | |  -> 0=Burst Wrap    100    => 32 words *CR1.5* ONLY
        //   |        Register Select  <-------------  |  | |  |  | | |  | |     1=No Wrap       111    => continuous (default)
        //   |        00=RCR                           |  | |  |  | | |  | |                     OTHERS => reserved 
        //   -------->10=BCR                           |  | |  |  | | |  | -> *CR1.5* Drv Strngth
        //            01=DIDR *CR1.5* ONLY             |  | |  |  | | |  | |  00 = Full
        //                                             |  | |  |  | | |  | |  01 = 1/2 (default) ---> *CR1.0* Drv Strngth
        //                                             |  | |  |  | | |  | |  10 = 1/4           |    BCR[4]=reserved
        //              Reserved set to 00 <------------  | |  |  | | |  | |  11 = reserved      |    BCR[5]=0=Full
        //                                                | |  |  | | |  | -----------------------    BCR[5]=1=1/4
        //                     Operating Mode      <------- |  |  | | |  ->  Reserved set to 00's
        //                     0=Synchronous burst          |  |  | | |      
        //                     1=Asynchronous (defalut)     |  |  | | ->  Wait  
        //                                                  |  |  | |     0 = Asserted during delay
        //                    Initial Latency      <---------  |  | |     1 = Asserted one data cycle before delay (default)
        //                    0=Variable(Default)              |  | |    
        //                    1=Fixed *CR1.5* ONLY             |  | ->  Reserved set to 0
        //                                                     |  |     
        //                                                     |  ---------------------------->  Wait Polarity
        //                                                     |                                 0=Active LOW
        //                                                     - >  Latency counter              1=Active HIGH (default)
        //                                                          010=Code 2
        //                                                          011=Code 3(default)
        //                                                          100=Code 4
        //                                                          101=Code 5
        //                                                          110=Code 6
        //                                                          else=Reserved 
        //                                                   

        //Access using ZZ# is WRITE only.

        if (GENERATION > CR10) begin
            //ASYNC register read of BCR
            if (&BCR_MASK[17:16]) begin
                async_read(1, BCR<<REG_SEL, a, 0, 1);
                idle(0);
                nop(tHZ);
            end

            //ASYNC read of RCR
            if (&RCR_MASK[17:16]) begin
                async_read(1, RCR<<REG_SEL, 16'b00000000_0_00_1_0_000, 0, 1);
                idle(0);
                nop(tHZ);
            end

            //ASYNC read of DIDR
            if (&DIDR_MASK[17:16]) begin
                async_read(1, DIDR<<REG_SEL, DIDR_DEFAULT, 0, 1);
                idle(0);
                nop(tHZ);
            end
        end

        #200

        // Figures 42 : Asynchronous Write using ADV
        async_write(0, 0, 16'h0000, 0, 1);  // wr_addr, wr_data;
        idle(0);
        nop(tCPH);

        // Figures 31 : Asynchronous Read using ADV
        async_read(0, 0, 16'h0000, 0, 1);
        idle(0);
        nop(tCPH);

        #200

        async_write(0, 16'hF0, 16'h0AF0, 0, 1);  // wr_addr, wr_data;
        idle(0);
        nop(tCPH);
        async_write(0, 16'hF1, 16'h0AF2, 0, 1);  // wr_addr, wr_data;
        idle(0);
        nop(tCPH);
        async_write(0, 16'hF2, 16'h0AF4, 0, 1);  // wr_addr, wr_data;
        idle(0);
        nop(tCPH);
        async_write(0, 16'hF3, 16'h0AF6, 0, 1);  // wr_addr, wr_data;
        idle(0);
        nop(tCPH);

        // Figure 30 : Asynchronous Read
        async_read(0, 16'hF0, 16'h0AF0, 2'b01, 1);
        idle(0);
        nop(tCPH);
        async_read(0, 16'hF1, 16'h0AF2, 0, 1);
        idle(0);
        nop(tCPH);
        async_read(0, 16'hF2, 16'h0AF4, 2'b10, 1);
        idle(0);
        nop(tCPH);
        async_read(0, 16'hF3, 16'h0AF6, 0, 1);
        idle(0);
        nop(tCPH);

        #200
        
        // Set RCR[7]=1 : Page Mode = 1
        async_write(1, 16'b00000000_1_00_1_0_000 | RCR<<REG_SEL, {DQ_BITS{1'bz}}, 0, 0);
        idle(0);
        nop(max(tVPH, tCPH));
        async_read(0, 16'hF0, 16'h0AF0, 0, 0);
        page_read (16'hF1, 16'h0AF2, 0);
        page_read (16'hF2, 16'h0AF4, 0);
        page_read (16'hF3, 16'h0AF6, 0);

        idle(0);
        nop(200);

        // setup 16 addresses 
        for (a=0; a<16; a=a+1) begin
            async_write(0, 16'h0AA0+a, 16'hF000+a, 0, 1);  // wr_addr, wr_data;
            idle(0);
            nop(tCPH);
        end

        idle(0);
        nop(tCPH);

        // read 16 addresses
        async_read(0, 16'h0AA0, 16'hF000, 0, 0);
        for (a=1; a<16; a=a+1)
            page_read(16'h0AA0+a, 16'hF000+a, 0);

        idle(0);
        nop(200);
        
        // read 9 addresses
        async_read(0, 16'h0AA8, 16'hF008, 0, 0);
        for (a=7; a>=0; a=a-1)
            page_read(16'h0AA0+a, 16'hF000+a, 0);

        idle(0);
        nop(200);

        // Figure 12 : Async Config write followed by Array read
        // Set RCR[7]=1 : Page Mode = 0
        async_write(1, 16'b00000000_0_00_1_0_000 | RCR<<REG_SEL, {DQ_BITS{1'bz}}, 0, 1);
        idle(0);
        nop(tCPH);

        async_read(0, 16'hF2, 16'h0AF4, 0, 1);
        idle(0);
        nop(tCPH);

        #200

        // Synchronous mode -- Burst length = 4
        a = (16'b0_1_011_0_0_0_01_00_1_001 & BCR_MASK[15:0]) | (BCR_DEFAULT & ~BCR_MASK[15:0]) | BCR<<REG_SEL;
        async_write(1, a, {DQ_BITS{1'bz}}, 0, 1);
        tclk = tclk_min;
        idle(0);
        nop(tCPH);

        sync_write(0, 0, 16'h3333, 2'b00); // wr_cre, wr_addr, wr_data, wr_byte
        sync_write_burst(16'h2222, 2'b00); // wr_data, wr_byte
        sync_write_burst(16'h1111, 2'b00); // wr_data, wr_byte
        sync_write_burst(16'h0000, 2'b00); // wr_data, wr_byte

        sync_read(0, 0, 16'h3333, 2'b00); // rd_cre, rd_addr, rd_data, rd_byte
        sync_read_burst(16'h2222, 2'b00); // rd_data, rd_byte
        sync_read_burst(16'h1111, 2'b00); // rd_data, rd_byte
        sync_read_burst(16'h0000, 2'b00); // rd_data, rd_byte

        idle(3);
        nop(tOHZ);
        async_write(0, 0, 16'h0000, 0, 1);  // wr_addr, wr_data;
        idle(0);
        nop(tCBPH);

        #200
        
        // Figure 50 : Async Write followed by Burst read   (Mixed Mode)
        async_write(0, 16'h0AA5, 16'h5555, 0, 1);
        idle(0);
        nop(tCBPH);

        sync_read(0, 16'h0AA5, 16'h5555, 2'b00);
        idle(0);
        nop(tCBPH);

        #200

        // setup 16 addresses 
        sync_write(0, 16'h0BF0, 16'hBF00, 0);  // wr_addr, wr_data;
        for (a=1; a<16; a=a+1) begin
            sync_write_burst(16'hBF00+a, 0);  // wr_addr, wr_data;
        end
        idle(0);
        nop(tCBPH);

        // Figure 13 : Config write in synchronous mode followed by a burst read
        // Synchronous mode -- Burst Length = Continuous
        a = (16'b0_0_011_0_0_1_01_10_1_111 & BCR_MASK[15:0]) | (BCR_DEFAULT & ~BCR_MASK[15:0]) | BCR<<REG_SEL;
        sync_write(1, a, {DQ_BITS{1'bz}}, 0); 
        idle(0);
        nop(tCBPH);

        sync_read(0, 16'h0BFF, 16'hBF0F, 2'b00); // rd_cre, rd_addr, rd_data, rd_byte
        idle(0);
        nop(tCBPH);

        sync_write(0, 16'h0BFF, 16'hBF0F, 2'b00); // wr_cre, wr_addr, wr_data, wr_byte
        idle(0);
        nop(tCBPH);

        sync_read(0, 16'h0BFA, 16'hBF0A, 2'b01); // rd_cre, rd_addr, rd_data, rd_byte
        sync_read_burst(16'hBF0B, 2'b00); // rd_data, rd_byte
        sync_read_burst(16'hBF0C, 2'b10); // rd_data, rd_byte
        sync_read_burst(16'hBF0D, 2'b00); // rd_data, rd_byte
        sync_read_burst(16'hBF0E, 2'b00); // rd_data, rd_byte
        sync_read_burst(16'hBF0F, 2'b00); // rd_data, rd_byte
        clk_pulse(3);
        nop(3*tclk);
        idle(0);
        nop(tCBPH);


        // Row Boundary Crossing
        if (GENERATION == CR10) begin
            sync_write(0, 'h7FC, 16'h0004, 2'b00); // wr_cre, wr_addr, wr_data, wr_byte
            sync_write_burst(16'h0005, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0006, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0007, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0008, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0009, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h000A, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h000B, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h000C, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h000D, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h000E, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h000F, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0010, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0011, 2'b00); // wr_data, wr_byte
            sync_write_burst(16'h0012, 2'b00); // wr_data, wr_byte
            idle(0);
            nop(tCBPH);

            sync_read(0, 'h7FC, 16'h0004, 2'b00); // rd_cre, rd_addr, rd_data, rd_byte
            sync_read_burst(16'h0005, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0006, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0007, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0008, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0010, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0011, 2'b00); // rd_data, rd_byte
            sync_read_burst(16'h0012, 2'b00); // rd_data, rd_byte
            idle(0);
            nop(tCBPH);
        end

        #200

        test_done;

    end
