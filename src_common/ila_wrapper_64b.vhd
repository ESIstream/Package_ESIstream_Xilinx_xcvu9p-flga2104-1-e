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

library work;
use work.esistream_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ila_wrapper is
  generic (
    ---DESER_WIDTH : natural := 64;
    NB_LANES    : natural := 8);
  port (
    clk            : in std_logic;
    rx_sync        : in std_logic;
    data_out_12b_0 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_1 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_2 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_3 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_4 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_5 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_6 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0);
    data_out_12b_7 : in slv_12_array_n(DESER_WIDTH/16-1 downto 0));
end entity ila_wrapper;

architecture rtl of ila_wrapper is

begin
  ila_64b_0 : entity work.ila_64b
    port map (
      clk        => clk,
      probe0     => data_out_12b_0(0),
      probe1     => data_out_12b_0(1),
      probe2     => data_out_12b_0(2),
      probe3     => data_out_12b_0(3),
      probe4     => data_out_12b_1(0),
      probe5     => data_out_12b_1(1),
      probe6     => data_out_12b_1(2),
      probe7     => data_out_12b_1(3),
      probe8     => data_out_12b_2(0),
      probe9     => data_out_12b_2(1),
      probe10    => data_out_12b_2(2),
      probe11    => data_out_12b_2(3),
      probe12    => data_out_12b_3(0),
      probe13    => data_out_12b_3(1),
      probe14    => data_out_12b_3(2),
      probe15    => data_out_12b_3(3),
      probe16    => data_out_12b_4(0),
      probe17    => data_out_12b_4(1),
      probe18    => data_out_12b_4(2),
      probe19    => data_out_12b_4(3),
      probe20    => data_out_12b_5(0),
      probe21    => data_out_12b_5(1),
      probe22    => data_out_12b_5(2),
      probe23    => data_out_12b_5(3),
      probe24    => data_out_12b_6(0),
      probe25    => data_out_12b_6(1),
      probe26    => data_out_12b_6(2),
      probe27    => data_out_12b_6(3),
      probe28    => data_out_12b_7(0),
      probe29    => data_out_12b_7(1),
      probe30    => data_out_12b_7(2),
      probe31    => data_out_12b_7(3),
      probe32(0) => rx_sync);
end rtl;
