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
use ieee.math_real.all;

entity timer is
  generic(
    CLK_FREQUENCY_HZ : integer := 100000000;  --! timer system clock frequency [Hz] 
    TIME_US          : integer := 2000      --! time to count [us] 
    );
  port (
    rst         : in  std_logic;             --! active high synchronous reset.
    clk         : in  std_logic;             --! timer system clock... 
    timer_start : in  std_logic;             --! timer start, set high to start and maintain high until timer_done pulse or while timer busy active.
    timer_busy  : out std_logic;             --! active high, when timer counts.
    timer_done  : out std_logic              --! active high pulse, one clock period of clock when end of timer.
    );
end timer;

architecture rtl of timer is

  constant counter_init  : integer                            := integer(CLK_FREQUENCY_HZ/1000000*TIME_US);
  constant counter_width : integer                            := integer(floor(log2(real(counter_init))))+1;
  signal u_counter       : unsigned(counter_width-1 downto 0) := to_unsigned(1, counter_width);
  signal counter_busy    : std_logic                          := '0';
  signal timer_done_sr   : std_logic_vector(2 downto 0)       := (others => '0');

begin

  p_counter : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or timer_start = '0' then
        u_counter    <= to_unsigned(counter_init, counter_width);
        counter_busy <= '0';
      else
        if u_counter <= 1 then
          u_counter    <= u_counter;
          counter_busy <= '0';
        else
          u_counter    <= u_counter-1;
          counter_busy <= '1';
        end if;
      end if;
    end if;
  end process;

  p_done : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        timer_done_sr <= (others => '1');
        timer_done    <= '0';
      else
        timer_done_sr(0)          <= not counter_busy;
        timer_done_sr(2 downto 1) <= timer_done_sr(1 downto 0);

        if timer_done_sr(2) = '0' and  timer_done_sr(1) = '1' then
          timer_done <= '1';
        else
          timer_done <= '0';
        end if;
      end if;
    end if;
  end process;

  timer_busy <= counter_busy;


end rtl;
