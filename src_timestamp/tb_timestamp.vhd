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

entity tb_timestamp is
end tb_timestamp;

architecture behavioral of tb_timestamp is

  signal clk            : std_logic                      := '0';
  signal rst            : std_logic                      := '0';
  --
  -- 127-bit prbs sequence:
  -- Every 127 frames, it starts again with bit 126.
  constant LFSR_X7X6X0  : std_logic_vector(126 downto 0) := "1000010111110010101110011010001001111000101000011000001000000111111101010100110011101110100101100011011110110101101100100100011";
  constant LFSR_INIT    : std_logic_vector(6 downto 0)   := "1110000";
  signal lfsr_sr        : std_logic_vector(126 downto 0) := (others => '0');
  signal lfsr_t         : std_logic_vector(6 downto 0)   := (others => '0');
  signal timestamp      : std_logic                      := '0';
  signal start_lfsr     : std_logic                      := '0';
  signal lfsr_isrunning : std_logic                      := '0';
  signal lfsr_error     : std_logic                      := '0';
--
begin

  clk <= not clk after 5 ns;  -- 100 MHz

  my_tb : process
  begin
    rst        <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    rst        <= '0';
    wait until rising_edge(clk);
    wait for 100 ns;
    wait until rising_edge(clk);
    start_lfsr <= '1';
    wait until rising_edge(clk);
    start_lfsr <= '0';
    wait for 1000 ns;
    wait;
  end process;

  p_lfsr : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        lfsr_t         <= (others => '0');
        lfsr_isrunning <= '0';
      elsif start_lfsr = '1' then
        lfsr_t         <= LFSR_INIT;
        lfsr_isrunning <= '1';
      else
        lfsr_isrunning <= lfsr_isrunning;
        lfsr_t(0)      <= lfsr_t(6);
        lfsr_t(1)      <= lfsr_t(0);
        lfsr_t(2)      <= lfsr_t(1);
        lfsr_t(3)      <= lfsr_t(2);
        lfsr_t(4)      <= lfsr_t(3);
        lfsr_t(5)      <= lfsr_t(4);
        lfsr_t(6)      <= lfsr_t(5) xor lfsr_t(6);
      end if;
    end if;
  end process;
  timestamp <= lfsr_t(4);

  p_check_lfsr : process(clk)
  begin
    if rising_edge(clk) then
      if lfsr_isrunning = '0' then
        lfsr_sr    <= LFSR_X7X6X0;
        lfsr_error <= '0';
      else
        lfsr_sr(126 downto 1) <= lfsr_sr(125 downto 0);
        lfsr_sr(0) <= lfsr_sr(126);
        if lfsr_sr(126) = timestamp then
          lfsr_error <= '0';
        else
          lfsr_error <= '1';
        end if;
      end if;
    end if;
  end process;

end behavioral;
