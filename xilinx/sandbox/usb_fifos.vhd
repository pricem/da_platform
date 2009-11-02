-- $Id: usb_fifos.vhd,v 1.3 2009/02/20 16:59:57 jrothwei Exp $
-- Joseph Rothweiler, Sensicomm LLC. Started 17Feb2009.
-- http://www.sensicomm.com
--
-- Copyright 2009 Joseph Rothweiler
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
-------------------------------------------------------------------------------
-- Interface to the 4 FIFO's of the Cypress USB chip.
-- The configuration as set by the associated USB firmware is:
-- FIFO flags are set to Active-High, and indicate the state
-- of the fifo selected by the faddr lines:
-- A : Programmable level (not used here).
-- B : Full.
-- C : Empty.
-- Using Default Alternate-1 settings:
-- faddr EP  Host
--   00   2  OUT
--   01   4  OUT
--   10   6   IN
--   11   8   IN
-- EP2 and EP6 are best used for high-capacity transfers.
-- I plan to use 4 and 8 for control signals.
-- EP0 and EP1 are not handled through the FIFO's.
-- Asynchronous mode is being used on the control signals. ifclk_div
-- is derived from the 48MHz USB clock, and is slow enough to be well
-- within the async mode timing requirements. Faster transfers would
-- be possible with synchronous mode or less conservative timing.
--
-- This test version is for demonstration; it only uses EP2 and EP6.
-- Every byte from EP2 is presented on fifo0_outbyte, and a pulse
-- is generated on fifo0_outflag. The total byte count is fifo0_outcount.
-- When fifo2_inflag is high, dummy data is written to fifo2 (EP6). The
-- data is just a continuously incrementing 8-bit value. The total count
-- is in fifo2_incount.
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;      -- Common things.
use IEEE.STD_LOGIC_ARITH.ALL;     -- Makes the "div+1" instruction work.
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity usb_fifos is
  Port (
    CLK_50M  : in  STD_LOGIC; -- Input: 50 MHz clock.
    -- the USB interface. 56-pin package in 8-bit mode.
    fdata_in  : in  STD_LOGIC_VECTOR(7 downto 0); -- USB FIFO data lines.
    fdata_out : out STD_LOGIC_VECTOR(7 downto 0); -- USB FIFO data lines.
    fdata_oe  : out STD_LOGIC;                    -- Enable drivers.
    faddr     : out STD_LOGIC_VECTOR(1 downto 0); -- USB FIFO select lines.
    slrd      : out STD_LOGIC;
    slwr      : out STD_LOGIC;
    sloe      : out STD_LOGIC;
    slcs      : out STD_LOGIC; -- Or FLAGD.
    int0      : out STD_LOGIC;
    pktend    : out STD_LOGIC;
    flaga     : in  STD_LOGIC;
    flagb     : in  STD_LOGIC;
    flagc     : in  STD_LOGIC;
    ifclk     : in  STD_LOGIC;
    fifo0_outbyte  : out STD_LOGIC_VECTOR(7 downto 0);
    fifo0_outcount : out STD_LOGIC_VECTOR(31 downto 0);
    fifo0_outflag  : out STD_LOGIC;
    fifo2_inflag   : in  STD_LOGIC;
    fifo2_incount  : out STD_LOGIC_VECTOR(31 downto 0);
    debugvec       : out STD_LOGIC_VECTOR(7 downto 0)
  );
end usb_fifos;

architecture rtl of usb_fifos is
  -- *_i signals are copies of corresponding Port signals.
  -- out signals are write-only, so I need these copies to remember
  -- what the signal values are.
  signal faddr_i    : STD_LOGIC_VECTOR(1 downto 0);  -- Internal version of faddr.
  signal fdata_oe_i : STD_LOGIC;
  signal slrd_i     : STD_LOGIC;
  signal slwr_i     : STD_LOGIC;
  signal sloe_i     : STD_LOGIC;
  signal fifo0_outcount_i : STD_LOGIC_VECTOR(31 downto 0);
  signal fifo2_incount_i  : STD_LOGIC_VECTOR(31 downto 0);
  signal fifo2_inbyte : STD_LOGIC_VECTOR(7 downto 0);  -- Local for now.
  signal sequencer : STD_LOGIC_VECTOR(5 downto 0);   -- Counter to sequence the fifo signals.
  signal ifclk_div : STD_LOGIC_VECTOR(7 downto 0);   -- To divide down the USB clock.
begin
  -- These are unused for now.
  int0   <= '0';
  slcs   <= '0';
  pktend <= '0';
  -- Connect internal to external.
  slrd           <= slrd_i;
  slwr           <= slwr_i;
  sloe           <= sloe_i;
  faddr          <= faddr_i;
  fifo0_outcount <= fifo0_outcount_i;
  fifo2_incount  <= fifo2_incount_i;
  fdata_oe       <= fdata_oe_i;
  ------------------------------------------
  -- Divide down the ifclk, as a quick fix.
  process(ifclk) begin
    if(rising_edge(ifclk)) then
      ifclk_div <= ifclk_div + 1;
    end if;
  end process;
  ------------------------------------------
  -- Cycle through the fifo's.
  process(ifclk_div) begin
    if(rising_edge(ifclk_div(2))) then
      sequencer <= sequencer + 1;
      ---------------------------------------------------------
      -- Generate the control lines.
      case sequencer(4 downto 0) is
      ----------------------------------
      -- Cases for OUT fifo 0 reads.
      ----------------------------------
      when "00000" =>    -- Select FIFO 0, Get ready for a cycle.
        faddr_i <= "00";
        sloe_i  <= '1';
        slrd_i  <= '0';
        slwr_i  <= '0';
      when "00001" =>    -- Start the FIFO 0 read cycle.
        faddr_i <= "00";
        sloe_i  <= '1';
	if(flagc = '0') then
          slrd_i  <= '1';
	else
          slrd_i  <= '0';
	end if;
        slwr_i  <= '0';
      when "00010" =>    -- Complete the FIFO 0 read cycle.
        if(slrd_i = '1') then -- Reading.
	  fifo0_outbyte <= fdata_in;             -- Capture the data.
	  fifo0_outcount_i <= fifo0_outcount_i + 1; -- Increment the byte count.
	  fifo0_outflag <= '1';
	end if;
        faddr_i <= "00";
        sloe_i  <= '0';
        slrd_i  <= '0'; -- Read cycle done.
        slwr_i  <= '0';
      ----------------------------------
      -- Cases for IN fifo 2 writes.
      -- Skipping a few numbers for now.
      ----------------------------------
      when "01000" =>    -- Set to write to fifo 2.
        -- Set up for a write if there is data to send and fifo is not full.
        if( (fifo2_inflag='1') AND (flagb='0') ) then
	  fdata_out <= fifo2_inbyte; -- Put the data on the bus,
	  fifo2_inbyte <= fifo2_inbyte + 1; -- Dummy data for now.
	  fifo2_incount_i <= fifo2_incount_i + 1; -- For debugging.
	  fdata_oe_i <= '1';
	else
	  fdata_oe_i <= '0';
	end if;
        faddr_i <= "10";
        sloe_i  <= '0';
        slrd_i  <= '0';
        slwr_i  <= '0';   -- Write cycle starts on the next clock.
      when "01001" =>    -- Do the write.
        debugvec <= faddr_i & slrd_i & slwr_i     & fifo2_inflag & sloe_i & flagb & flagc;
        faddr_i <= "10";
        sloe_i  <= '0';
        slrd_i  <= '0';
	if (fdata_oe_i = '1') then
          slwr_i  <= '1';  
	else
          slwr_i  <= '0';  
	end if;
      when "01010" =>    -- Write finished.
	fifo0_outflag <= '0';
        faddr_i <= "10";
        sloe_i  <= '0';
        slrd_i  <= '0';
        slwr_i  <= '0';
	fdata_oe_i <= '0';
      when others =>
	fifo0_outflag <= '0';
        faddr_i <= "00";
        sloe_i  <= '0';
        slrd_i  <= '0';
        slwr_i  <= '0';
      end case;
    end if;
  end process;
end rtl;
