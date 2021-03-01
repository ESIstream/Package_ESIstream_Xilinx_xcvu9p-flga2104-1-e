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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity risingedge is
  port (
    rst : in  std_logic;  --! active high synchronous reset.
    clk : in  std_logic;  --!
    d   : in  std_logic;
    re  : out std_logic
    );
end risingedge;

architecture rtl of risingedge is

  signal shift_register : std_logic_vector(2 downto 0) := (others => '0');
begin

  p_sr : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        shift_register <= (others => '0');
      else
        shift_register(0)          <= d;
        shift_register(2 downto 1) <= shift_register(1 downto 0);
      end if;
    end if;
  end process;

  p_re : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        re <= '0';
      else
        if shift_register(2 downto 1) = "01" then
          re <= '1';
        else
          re <= '0';
        end if;
      end if;
    end if;
  end process;

end rtl;
