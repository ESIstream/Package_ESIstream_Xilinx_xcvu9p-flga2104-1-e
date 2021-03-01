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
-- 1.0          2020            Teledyne e2v Creation
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;
use std.env.all;

entity tb_odelaye3_wrapper is
end tb_odelaye3_wrapper;

architecture behavioral of tb_odelaye3_wrapper is

  constant period      : time                         := 5 ns;
  signal clk           : std_logic                    := '0';
  signal refclk        : std_logic                    := '0';
  signal rst           : std_logic                    := '0';
  signal set_delay     : std_logic;
  signal next_delay    : std_logic_vector(8 downto 0) := (others => '0');
  signal get_delay     : std_logic;
  signal current_delay : std_logic_vector(8 downto 0) := (others => '0');
  signal sync          : std_logic;
  signal sync_odelay   : std_logic;

begin

  refclk <= not refclk after 2.5 ns;  -- 200 MHz
  clk    <= not clk    after 5 ns;    -- 100 MHz

  odelaye3_wrapper_1 : entity work.odelaye3_wrapper
    port map (
      clk         => clk,
      refclk      => refclk,
      rst         => rst,
      set_delay   => set_delay,
      in_delay    => next_delay,
      get_delay   => get_delay,
      out_delay   => current_delay,
      sync        => sync,
      sync_odelay => sync_odelay);

  my_tb : process
  begin
    rst        <= '1';
    set_delay  <= '0';
    next_delay <= std_logic_vector(to_unsigned(0, next_delay'length));
    sync       <= '0';
    get_delay  <= '0';
    wait for period*100;
    wait until rising_edge(clk);

    rst <= '0';

    wait for period*100;
    sync <= '1';
    wait for 22 ns;
    sync <= '0';

    wait for period*100;
    wait until rising_edge(clk);
    next_delay <= std_logic_vector(to_unsigned(1, next_delay'length));
    set_delay  <= '1';
    get_delay  <= '1';
    wait until rising_edge(clk);
    set_delay  <= '0';

    wait for period*100;
    get_delay  <= '0';
    sync <= '1';
    wait for 22 ns;
    sync <= '0';

    wait for period*100;
    wait until rising_edge(clk);
    next_delay <= std_logic_vector(to_unsigned(2, next_delay'length));
    set_delay  <= '1';
    wait until rising_edge(clk);
    set_delay  <= '0';

    wait for period*100;
    sync <= '1';
    wait for 22 ns;
    sync <= '0';


    wait for period*100;
    wait until rising_edge(clk);
    next_delay <= std_logic_vector(to_unsigned(511, next_delay'length));
    set_delay  <= '1';
    wait until rising_edge(clk);
    set_delay  <= '0';

    wait for period*100;
    sync <= '1';
    wait for 22 ns;
    sync <= '0';


    wait;
  end process;
end behavioral;
