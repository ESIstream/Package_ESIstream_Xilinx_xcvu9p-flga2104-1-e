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
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Description :
-- Manages and monitors transceiver PLL(s) lock, reset, reset done,
-- user ready and ip ready signals.
-------------------------------------------------------------------------------
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_control is
  generic(
    NB_LANES : natural := 4
    );
  port (
    clk             : in  std_logic;
    pll_lock        : in  std_logic_vector(NB_LANES-1 downto 0);  -- Indicates whether GTH CPLL is locked
    rst_done        : in  std_logic_vector(NB_LANES-1 downto 0);  -- Indicates that GTH is ready
    usrrdy          : out std_logic_vector(NB_LANES-1 downto 0);  -- Indicates that GTH is ready
    rst_transceiver : out std_logic;                              --_vector(NB_LANES-1 downto 0)
    ip_ready        : out std_logic
    );
end entity tx_control;

architecture rtl of tx_control is

  constant SLV_NB_LANES_ALL_ONE : std_logic_vector(NB_LANES-1 downto 0) := (others => '1');
  signal usrrdy_sr              : slv_32_array_n(NB_LANES-1 downto 0)   := (others => (others => '0'));
  signal lock                   : std_logic                             := '0';
begin
  usrrdy_gen : for index in NB_LANES-1 downto 0 generate
    process(clk, pll_lock(index))
    begin
      if pll_lock(index) = '0' then
        usrrdy_sr(index) <= (others => '0');
      elsif rising_edge(clk) then
        usrrdy_sr(index)(0)           <= pll_lock(index);
        usrrdy_sr(index)(31 downto 1) <= usrrdy_sr(index)(30 downto 0);
      end if;
    end process;
    usrrdy(index) <= usrrdy_sr(index)(31);
  end generate;

  lock            <= '1' when pll_lock = SLV_NB_LANES_ALL_ONE                                     else '0';
  rst_transceiver <= not lock;
  ip_ready        <= '1' when pll_lock = SLV_NB_LANES_ALL_ONE and rst_done = SLV_NB_LANES_ALL_ONE else '0';

end architecture rtl;
