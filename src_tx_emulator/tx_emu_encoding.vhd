-------------------------------------------------------------------------------
-- This is free and unencumbered software released into the public domain.
--
-- Anyone is free to copy, modify, publish, use, compile, sell, or distribute
-- this software, either in source code form or as a compiled bitstream, for 
-- any purpose, commercial or non-commercial, and by any means.
--
-- In jurisdictions that recognize copyright laws, the author or authors of 
-- this software dedicate any and all copyright interest in the software to 
-- the public domain. We make this dedication for the benefit of the public at
-- large and to the detriment of our heirs and successors. We intend this 
-- dedication to be an overt act of relinquishment in perpetuity of all present
-- and future rights to this software under copyright law.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
-- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- THIS DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
-------------------------------------------------------------------------------
-- Version      Date            Author       Description
-- 1.0          2019            Teledyne e2v Creation
-- 1.1          2019            REFLEXCES    FPGA target migration, 64-bit data path
-- 1.2          2020            Teledyne-e2v Tx emulator, add lss output flag (lane synchronization sequence) 
-------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- Description :
-- When SER_WIDTH = 32 : Encodes useful data 2x14-bits (data_in signal) into a 2x16-bits
-- When SER_WIDTH = 64 : Encodes useful data 4x14-bits (data_in signal) into a 4x16-bits
----------------------------------------------------------------------------------------------------

library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;

entity tx_emu_encoding is
  generic(
    COMMA : std_logic_vector(31 downto 0) := x"FF0000FF"
    );
  port (
    clk       : in  std_logic;
    nrst      : in  std_logic;
    sync      : in  std_logic;                                         -- Resets LFSR, disparity and starts synchronization
    prbs_en   : in  std_logic;                                         -- Enables scrambling processing
    disp_en   : in  std_logic;                                         -- Enables disparity processing
    lfsr_init : in  std_logic_vector(16 downto 0) := (others => '1');  -- Initial value of LFSR
    data_in   : in  slv_14_array_n((SER_WIDTH/16)-1 downto 0);         -- Input data to encode
    data_out  : out slv_16_array_n((SER_WIDTH/16)-1 downto 0);         -- Output endoded data
    lss       : out std_logic                                          -- when '1' lane synchronization sequence (FAS + PSS) else normal operation.       
    );
end entity tx_emu_encoding;

architecture rtl of tx_emu_encoding is
  --============================================================================================================================
  -- Function and Procedure declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Constant and Type declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Component declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Signal declarations
  --============================================================================================================================
  signal data_lfsr          : slv_14_array_n((SER_WIDTH/16)-1 downto 0);
  signal data_scrambled     : slv_16_array_n((SER_WIDTH/16)-1 downto 0);
  signal data_scrambled_vld : std_logic;

begin

  tx_emu_lfsr_1 : entity work.tx_emu_lfsr
    port map(
      clk        => clk,
      init       => sync,
      init_value => lfsr_init,
      lfsr_out   => data_lfsr
      );

  tx_emu_scrambling : entity work.tx_emu_scrambling
    generic map(
      COMMA => COMMA
      )
    port map (
      nrst         => nrst,
      clk          => clk,
      sync         => sync,
      prbs_en      => prbs_en,
      data_in      => data_in,
      data_prbs    => data_lfsr,
      data_out     => data_scrambled,
      data_out_vld => data_scrambled_vld,
      lss          => lss
      );

  tx_emu_disparity : entity work.tx_emu_disparity
    port map (
      nrst        => nrst,
      clk         => clk,
      sync        => sync,
      disp_en     => disp_en,
      data_in     => data_scrambled,
      data_in_vld => data_scrambled_vld,
      data_out    => data_out
      );

end architecture rtl;
