-- $Id: x03_usb_top.vhd,v 1.3 2009/02/20 15:57:21 jrothwei Exp $
-- Joseph Rothweiler, Sensicomm LLC. Started 16Feb2009.
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
-- Testing communications with the Cypress USB.
-- Developing it for the Nexys 2 board from Digilent: http://www.digilentinc.com
-- Chip is XC3S500E FGG320 package, Speed Grade 5C/4I.
-- This test program just displays incoming data (from EP2) on the LED's, and
-- Sends dummy data to EP6 when BTN0 is pushed.
-- The Slide switches select what is displayed on the row of LED's. Set
-- only SW(2) high to display the EP2 output byte.
--
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;      -- Common things.
use IEEE.STD_LOGIC_ARITH.ALL;     -- Makes the "div+1" instruction work.
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity usb_top is
  Port (
    CLK_50M  : in  STD_LOGIC; -- Input: 50 MHz clock.
    SW       : in  STD_LOGIC_VECTOR(7 downto 0) ; -- Input control switch.
    BTN      : in  STD_LOGIC_VECTOR(3 downto 0) ; -- Input control pushbuttons.
    -- the USB interface. 56-pin package in 8-bit mode.
    U_FDATA  : inout STD_LOGIC_VECTOR(7 downto 0); -- USB FIFO data lines.
    U_FADDR  : out STD_LOGIC_VECTOR(1 downto 0); -- USB FIFO select lines.
    U_SLRD   : out STD_LOGIC;
    U_SLWR   : out STD_LOGIC;
    U_SLOE   : out STD_LOGIC;
    U_SLCS   : out STD_LOGIC; -- Or FLAGD.
    U_INT0   : out STD_LOGIC;
    U_PKTEND : out STD_LOGIC;
    U_FLAGA  : in  STD_LOGIC;
    U_FLAGB  : in  STD_LOGIC;
    U_FLAGC  : in  STD_LOGIC;
    U_IFCLK  : in  STD_LOGIC;
    --
    LED       : out STD_LOGIC_VECTOR(7 downto 0)
  );
end usb_top;

architecture rtl of usb_top is
  component usb_fifos is Port (
    CLK_50M  : in  STD_LOGIC; -- Input: 50 MHz clock.
    -- the USB interface. 56-pin package in 8-bit mode.
    fdata_in  : in  STD_LOGIC_VECTOR(7 downto 0); -- USB FIFO data lines.
    fdata_out : out STD_LOGIC_VECTOR(7 downto 0); -- USB FIFO data lines.
    fdata_oe  : out STD_LOGIC;                    -- Enable drivers.
    faddr     : out STD_LOGIC_VECTOR(1 downto 0); -- USB FIFO select lines.
    slrd      : out STD_LOGIC;
    slwr      : out STD_LOGIC;
    sloe      : out STD_LOGIC;
    slcs      : inout STD_LOGIC; -- Or FLAGD.
    int0      : out STD_LOGIC;
    pktend    : out STD_LOGIC;
    flaga     : in  STD_LOGIC;
    flagb     : in  STD_LOGIC;
    flagc     : in  STD_LOGIC;
    ifclk     : in  STD_LOGIC;
    fifo0_outbyte  : out STD_LOGIC_VECTOR(7 downto 0);
    fifo0_outcount : out STD_LOGIC_VECTOR(31 downto 0);
    fifo0_outflag  : out STD_LOGIC;
    fifo2_inflag   :  in STD_LOGIC;
    fifo2_incount  : out STD_LOGIC_VECTOR(31 downto 0);
    debugvec       : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  signal U_FADDR_i   : STD_LOGIC_VECTOR(1 downto 0);
  signal U_SLRD_i    : STD_LOGIC;
  signal U_SLWR_i    : STD_LOGIC;
  signal U_SLOE_i    : STD_LOGIC;
  signal U_SLCS_i    : STD_LOGIC;
  signal U_INT0_i    : STD_LOGIC;
  signal U_PKTEND_i  : STD_LOGIC;
  signal ifcounter   : STD_LOGIC_VECTOR(27 downto 0);
  signal data_enable : STD_LOGIC;  -- U_FDATA tristate line.
  signal slcs_enable : STD_LOGIC := '1';  -- U_SLCS tristate line. Set for now.
  --
  signal fifo0_outbyte  : STD_LOGIC_VECTOR(7 downto 0);
  signal fifo0_outcount : STD_LOGIC_VECTOR(31 downto 0);
  signal fifo2_incount  : STD_LOGIC_VECTOR(31 downto 0);
  signal fifo0_outflag  : STD_LOGIC;
  signal fdata_in  : STD_LOGIC_VECTOR(7 downto 0);
  signal fdata_out : STD_LOGIC_VECTOR(7 downto 0);
  signal fdata_oe  : STD_LOGIC;
  signal debugvec  : STD_LOGIC_VECTOR(7 downto 0);
begin
  usb_fifos0 : usb_fifos port map (
    CLK_50M   => CLK_50M,
    fdata_in  => fdata_in,
    fdata_out => fdata_out,
    faddr     => U_FADDR_i,
    slrd      => U_SLRD_i,
    slwr      => U_SLWR_i,
    sloe      => U_SLOE_i,
    slcs      => U_SLCS_i,
    int0      => U_INT0_i,
    pktend    => U_PKTEND_i,
    flaga     => U_FLAGA,
    flagb     => U_FLAGB,
    flagc     => U_FLAGC,
    ifclk     => U_IFCLK,
    fifo0_outbyte  => fifo0_outbyte,
    fifo0_outcount => fifo0_outcount,
    fifo0_outflag  => fifo0_outflag,
    fifo2_inflag   => BTN(0),
    fifo2_incount  => fifo2_incount,
    debugvec       => debugvec
    );
  process(CLK_50M) begin
    -- Tristate control for the data lines.
    if(fdata_oe='1') then
      U_FDATA <= fdata_out;
    else
      U_FDATA <= (others=>'Z');  -- Tristated.
    end if;
    fdata_in <= U_FDATA;
    ---------------------------------------------------------------
    if (rising_edge(CLK_50M)) then
      if(SW="00000000") then               -- x00: Just io signal.
        LED <= "0101" & BTN;
      elsif(SW="00000001") then            -- x01: IFCLK counter.
        LED <= ifcounter(27 downto 20);
      elsif(SW="00000010") then            -- X02: in status lines.
        LED <= "00000" & U_FLAGC & U_FLAGB & U_FLAGA;
      elsif(SW="00000011") then            -- X03: out status lines.
        LED <= 
            U_PKTEND_i
          & U_INT0_i
          & U_SLCS_i
          & U_SLOE_i
          & U_SLWR_i
          & U_SLRD_i
          & U_FADDR_i ;
      elsif(SW="00000100") then            -- X04: FIFO 0 outword.
        LED <= fifo0_outbyte;
      elsif(SW="00000101") then            -- X05: FIFO 0 outcount
        LED <= fifo0_outcount(7 downto 0);
      elsif(SW="00000110") then            -- X06: FIFO 0 outcount
        LED <= fifo0_outcount(15 downto 8);
      elsif(SW="00000111") then            -- X07: FIFO 0 outcount
        LED <= fifo0_outcount(23 downto 16);
      --
      elsif(SW="00001000") then            -- X08: debugvec
        LED <= debugvec;
      elsif(SW="00001001") then            -- X09: FIFO 2 incount
        LED <= fifo0_outcount(7 downto 0);
      elsif(SW="00001010") then            -- X0a: FIFO 2 incount
        LED <= fifo0_outcount(15 downto 8);
      elsif(SW="00001011") then            -- X0b: FIFO 2 incount
        LED <= fifo0_outcount(23 downto 16);
      else
        LED <= "10101010";
      end if;

      ---------------------------------------------------------------
    end if;
  end process;
  ----------------------------------------------------------------
  -- Counter on the usb fifo clock.
  process(U_IFCLK) begin
    if (rising_edge(U_IFCLK)) then
      ifcounter <= ifcounter+1;
    end if;
  end process;
  ----------------------------------------------------------------
  -- Output pins.
  U_FADDR  <= U_FADDR_i;
  U_SLRD   <= U_SLRD_i;
  U_SLWR   <= U_SLWR_i;
  U_SLOE   <= U_SLOE_i;
  U_PKTEND <= U_PKTEND_i;
  U_INT0   <= U_INT0_i;
  process(slcs_enable) begin
    if (slcs_enable='1') then
      U_SLCS   <= U_SLCS_i;
    else
      U_SLCS   <= 'Z';
    end if;
  end process;
end rtl;
