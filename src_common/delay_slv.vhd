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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity delay_slv is
  generic (
    DATA_WIDTH : integer := 32;
    LATENCY    : integer := 1);
  port(
    clk : in  std_logic := 'X';
    d   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    q   : out std_logic_vector(DATA_WIDTH-1 downto 0));
end delay_slv;

architecture rtl of delay_slv is
  type sr_array is array (1 to LATENCY) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal sr : sr_array := (others => (others => '0'));
begin
  delay_slv_x_p : process(clk)
  begin
    if rising_edge(clk) then
      sr(1) <= d;
      for index in 2 to LATENCY loop
        sr(index) <= sr(index-1);
      end loop;
    end if;
  end process;
  q <= sr(LATENCY);
end rtl;
