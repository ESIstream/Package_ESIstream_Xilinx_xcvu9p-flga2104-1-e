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
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library work;
use work.esistream_pkg.all;

entity tx_emu_data_gen is
  generic(
    DATA_WIDTH : natural := 14
    );
  port (
    nrst       : in  std_logic;
    clk        : in  std_logic;
    d_ctrl     : in  std_logic_vector(1 downto 0);                      -- Control the data output type ("00" all 0; "11" all 1; else ramp+)
    data_out_0 : out std_logic_vector(11 downto 0) := (others => '0');  -- Output data
    data_out_1 : out std_logic_vector(11 downto 0) := (others => '0');  -- Output data
    data_out_2 : out std_logic_vector(11 downto 0) := (others => '0');  -- Output data
    data_out_3 : out std_logic_vector(11 downto 0) := (others => '0')   -- Output data
    );
end entity tx_emu_data_gen;

architecture rtl of tx_emu_data_gen is

---------- Signals ----------
  signal data_0 : std_logic_vector(11 downto 0) := (others => '0');
  signal data_1 : std_logic_vector(11 downto 0) := (others => '0');
  signal data_2 : std_logic_vector(11 downto 0) := (others => '0');
  signal data_3 : std_logic_vector(11 downto 0) := (others => '0');

begin

  gen_data_64 : if SER_WIDTH = 64 generate
    process(clk, nrst)
    begin
      if nrst = '0' then
        data_0 <= (others => '0');
        data_1 <= (others => '0');
        data_2 <= (others => '0');
        data_3 <= (others => '0');
      elsif rising_edge(clk) then
        if d_ctrl = "00" then
          data_0 <= (others => '0');
          data_1 <= (others => '0');
          data_2 <= (others => '0');
          data_3 <= (others => '0');
        elsif d_ctrl = "11" then
          data_0 <= (others => '1');
          data_1 <= (others => '1');
          data_2 <= (others => '1');
          data_3 <= (others => '1');
        else
          data_0 <= data_0 + 8;
          data_1 <= data_0 + 9;
          data_2 <= data_0 + 10;
          data_3 <= data_0 + 11;
        end if;
      end if;
    end process;
    data_out_0(11 downto 0) <= data_0;
    data_out_1(11 downto 0) <= data_1;
    data_out_2(11 downto 0) <= data_2;
    data_out_3(11 downto 0) <= data_3;
  end generate gen_data_64;

  gen_data_32_32 : if SER_WIDTH = 32 and DESER_WIDTH = 32 generate
    process(clk, nrst)
    begin
      if nrst = '0' then
        data_0 <= (others => '0');
        data_1 <= (others => '0');
      elsif rising_edge(clk) then
        if d_ctrl = "00" then
          data_0 <= (others => '0');
          data_1 <= (others => '0');
        elsif d_ctrl = "11" then
          data_0 <= (others => '1');
          data_1 <= (others => '1');
        else
          data_0 <= data_0 + 4;
          data_1 <= data_0 + 5;
        end if;
      end if;
    end process;
    data_out_0(11 downto 0) <= data_0;
    data_out_1(11 downto 0) <= data_1;
  end generate gen_data_32_32;
  
  gen_data_32_16 : if SER_WIDTH = 32 and DESER_WIDTH = 16 generate
    process(clk, nrst)
    begin
      if nrst = '0' then
        data_0 <= (others => '0');
        data_1 <= (others => '0');
      elsif rising_edge(clk) then
        if d_ctrl = "00" then
          data_0 <= (others => '0');
          data_1 <= (others => '0');
        elsif d_ctrl = "11" then
          data_0 <= (others => '1');
          data_1 <= (others => '1');
        else
          data_0 <= data_0 + 4;
          data_1 <= data_0 + 6;
        end if;
      end if;
    end process;
    data_out_0(11 downto 0) <= data_0;
    data_out_1(11 downto 0) <= data_1;
  end generate gen_data_32_16;
  
  gen_data_16 : if SER_WIDTH = 16 generate
    process(clk, nrst)
    begin
      if nrst = '0' then
        data_0 <= (others => '0');
      elsif rising_edge(clk) then
        if d_ctrl = "00" then
          data_0 <= (others => '0');
        elsif d_ctrl = "11" then
          data_0 <= (others => '1');
        else
          data_0 <= data_0 + 2;
        end if;
      end if;
    end process;
    data_out_0(11 downto 0) <= data_0;
  end generate gen_data_16;
  
end architecture rtl;
