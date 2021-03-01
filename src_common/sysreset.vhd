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
 
entity sysreset is
  generic(
    RST_CNTR_INIT : std_logic_vector(11 downto 0) := x"FFF"
    );
  port(
    syslock : in  std_logic;
    sysclk  : in  std_logic;
    reset   : out std_logic;
    resetn  : out std_logic);
end sysreset;

architecture rtl of sysreset is
  signal s_rst_cntr : std_logic_vector(11 downto 0) := RST_CNTR_INIT;
  signal s_reset_i  : std_logic                     := '0';
  signal s_resetn_i : std_logic                     := '0';
begin

  p_reset : process(syslock, sysclk)
  begin
    if syslock = '0' then
      s_rst_cntr <= RST_CNTR_INIT;
      s_reset_i  <= '1';
      s_resetn_i <= '0';

    elsif rising_edge(sysclk) then
      if s_rst_cntr /= x"000" then
        s_rst_cntr <= std_logic_vector(unsigned(s_rst_cntr) - 1);
      end if;
      -- Global POR reset.
      if s_rst_cntr /= x"000" then
        s_reset_i  <= '1';
        s_resetn_i <= '0';
      else
        s_reset_i  <= '0';
        s_resetn_i <= '1';
      end if;
    end if;
  end process;
  reset  <= s_reset_i;
  resetn <= s_resetn_i;

end rtl;
