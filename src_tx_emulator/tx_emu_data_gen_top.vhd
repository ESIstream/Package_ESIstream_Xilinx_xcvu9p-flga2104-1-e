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

entity tx_emu_data_gen_top is
  generic(
    NB_LANES : natural
    );
  port (
    nrst    : in  std_logic;
    clk     : in  std_logic;
    -- "00" all 0; "11" all 1; else ramp+
    d_ctrl  : in  std_logic_vector(1 downto 0);
    tx_data : out tx_data_array(NB_LANES-1 downto 0)
    );
end entity tx_emu_data_gen_top;

architecture rtl of tx_emu_data_gen_top is

  signal data_out_0 : std_logic_vector(11 downto 0) := (others => '0');
  signal data_out_1 : std_logic_vector(11 downto 0) := (others => '0');
  signal data_out_2 : std_logic_vector(11 downto 0) := (others => '0');
  signal data_out_3 : std_logic_vector(11 downto 0) := (others => '0');

begin
  --
  tx_emu_data_gen_1 : entity work.tx_emu_data_gen
    port map (
      nrst       => nrst,
      clk        => clk,
      d_ctrl     => d_ctrl,
      data_out_0 => data_out_0,
      data_out_1 => data_out_1,
      data_out_2 => data_out_2,
      data_out_3 => data_out_3);

  gen_data_16b : if SER_WIDTH = 16 generate
  begin
    process(data_out_0)
    begin
      for idx_lane in 0 to NB_LANES-1 loop
        tx_data(idx_lane)(0)(13 downto 12) <= "00";
        tx_data(idx_lane)(0)(11 downto 0)  <= data_out_0;
      end loop;
    end process;
  end generate gen_data_16b;

  gen_data_32b : if SER_WIDTH = 32 generate
  begin
    process(data_out_0, data_out_1)
    begin
      for idx_lane in 0 to NB_LANES-1 loop
        for idx in 0 to SER_WIDTH/16-1 loop
          case (idx mod 2) is
            when 0      =>
              tx_data(idx_lane)(idx)(13 downto 12) <= "00";
              tx_data(idx_lane)(idx)(11 downto 0) <= data_out_0;
            when others =>
              tx_data(idx_lane)(idx)(13 downto 12) <= "00";
              tx_data(idx_lane)(idx)(11 downto 0) <= data_out_1;
          end case;
        end loop;
      end loop;
    end process;
  end generate gen_data_32b;

  gen_data_64b : if SER_WIDTH = 64 generate
  begin
    process(data_out_0, data_out_1, data_out_2, data_out_3)
    begin
      for idx_lane in 0 to NB_LANES-1 loop
        for idx in 0 to SER_WIDTH/16-1 loop
          case idx is
            when 0      =>
              tx_data(idx_lane)(idx)(13 downto 12) <= "00";
              tx_data(idx_lane)(idx)(11 downto 0) <= data_out_0;
            when 1      =>
              tx_data(idx_lane)(idx)(13 downto 12) <= "00";
              tx_data(idx_lane)(idx)(11 downto 0) <= data_out_1;
            when 2      =>
              tx_data(idx_lane)(idx)(13 downto 12) <= "00";
              tx_data(idx_lane)(idx)(11 downto 0) <= data_out_2;
            when others =>
              tx_data(idx_lane)(idx)(13 downto 12) <= "00";
              tx_data(idx_lane)(idx)(11 downto 0) <= data_out_3;
          end case;
        end loop;
      end loop;
    end process;
  end generate gen_data_64b;
--
end architecture rtl;
