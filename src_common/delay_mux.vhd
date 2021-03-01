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

entity delay_mux is
  generic (    
    LAT_WIDTH : integer := 8);  
  port(
    clk : in  std_logic;
    rst : in  std_logic;
    lat : in  std_logic_vector(LAT_WIDTH-1 downto 0);
    d   : in  std_logic;
    q   : out std_logic);
end delay_mux;

architecture rtl of delay_mux is
  signal sr : std_logic_vector(2**LAT_WIDTH-1 downto 0) := (others => '0');
begin
  delay_p : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sr <= (others => '0');
      else
        sr(0) <= d;
        for index in 1 to 2**LAT_WIDTH-1 loop
          sr(index) <= sr(index-1);
        end loop;
      end if;
    end if;
  end process;

  mux_delay_p : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q <= '0';
      else
        q <= sr(to_integer(unsigned(lat)));
      end if;
    end if;
  end process;
  
end rtl;
