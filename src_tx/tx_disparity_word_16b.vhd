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
-- 1.2          2020-11         Teledyne e2v Add Disparity calculation on 4-bit comment
-------------------------------------------------------------------------------
-- Description :
-- Calculates the current word disparity for a 16-bit ESIstream frame.
-------------------------------------------------------------------------------
-- Disparity calculation on 4-bit (ram_dw):
-- 
-- "0000" = -4
-- "0001" = -2 
-- "0010" = -2
-- "0011" = 0
-- "0100" = -2
-- "0101" = 0
-- "0110" = 0
-- "0111" = 2
-- "1000" = -2
-- "1001" = 0
-- "1010" = 
-- "1011" = +2
-- "1100" = 0
-- "1101" = +2
-- "1110" = +2
-- "1111" = +4
-- 
-------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_disparity_word_16b is
  port (
    nrst        : in  std_logic;                      -- active low async reset 
    clk         : in  std_logic;                      -- system clock
    sync        : in  std_logic;                      -- when 1, reset disparity word to 0
    data_in     : in  std_logic_vector(15 downto 0);  -- data to process
    u_data_in_d : out unsigned(15 downto 0);          -- undigned delayed data 
    dw          : out signed(6 downto 0)              -- signed disparity word 
    );
end entity tx_disparity_word_16b;

architecture rtl of tx_disparity_word_16b is

  signal u_data_in : unsigned(15 downto 0) := (others => '0');

  -- disparity word lookup table
  type RAM_BLOCK is array(0 to 15) of signed(dw'length-1 downto 0);
  constant ram_dw : RAM_BLOCK := (to_signed(-4, dw'length),
                                  to_signed(-2, dw'length),
                                  to_signed(-2, dw'length),
                                  to_signed(0, dw'length),
                                  to_signed(-2, dw'length),
                                  to_signed(0, dw'length),
                                  to_signed(0, dw'length),
                                  to_signed(2, dw'length),
                                  to_signed(-2, dw'length),
                                  to_signed(0, dw'length),
                                  to_signed(0, dw'length),
                                  to_signed(2, dw'length),
                                  to_signed(0, dw'length),
                                  to_signed(2, dw'length),
                                  to_signed(2, dw'length),
                                  to_signed(4, dw'length));

begin

  u_data_in <= unsigned(data_in);

  counter_dw : process(clk)
  begin
    if rising_edge(clk) then
      if sync = '1' then
        dw <= to_signed(0, dw'length);
      else
        dw <= ram_dw(to_integer(u_data_in(15 downto 12)))
              + ram_dw(to_integer(u_data_in(11 downto 8)))
              + ram_dw(to_integer(u_data_in(7 downto 4)))
              + ram_dw(to_integer(u_data_in(3 downto 0)));
      end if;
    end if;
  end process;

  process(clk, nrst)
  begin
    if nrst = '0' then
      u_data_in_d <= x"5555";
    elsif rising_edge(clk) then
      if sync = '1' then
        u_data_in_d <= x"5555";
      else
        u_data_in_d <= u_data_in;
      end if;
    end if;
  end process;

end architecture rtl;
