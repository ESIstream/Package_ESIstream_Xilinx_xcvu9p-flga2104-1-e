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

-- @brief:
entity tx_emu_clk_pow2_divider is
  generic(
    DIV : integer := 64  -- [64; 32; 16; 8; 4; 2; 1]
    );
  port(
    rst             : in  std_logic;
    clk_in          : in  std_logic;
    clk_out         : out std_logic;
    clk_out_div64_p : out std_logic;
    clk_out_div64_n : out std_logic;
    clk_out_tick    : out std_logic;
    clk_out_cntr    : out integer range 0 to DIV-1
    );
end tx_emu_clk_pow2_divider;

architecture rtl of tx_emu_clk_pow2_divider is
  constant CNTR_WIDTH     : integer                                 := integer(log2(real(DIV)));
  constant CNTR_END_VALUE : unsigned(CNTR_WIDTH-1 downto 0)         := to_unsigned(DIV-2, CNTR_WIDTH);
  signal cntr             : unsigned(CNTR_WIDTH-1 downto 0)         := (others => '0');
  constant CNTR_MAX       : unsigned(CNTR_WIDTH-1 downto 0)         := (others => '1');
  signal slv_cntr         : std_logic_vector(CNTR_WIDTH-1 downto 0) := (others => '0');

begin

  counter_p : process(clk_in)
  begin
    if rising_edge(clk_in) then
      if rst = '1' then
        cntr <= (others => '0');
      else
        cntr <= cntr+1;
      end if;
    end if;
  end process;

  slv_cntr     <= std_logic_vector(cntr);
  clk_out_cntr <= to_integer(cntr);
  clk_out_p : process(clk_in)
  begin
    if rising_edge(clk_in) then
      if rst = '1' then
        clk_out <= '0';
      else
        clk_out <= slv_cntr(CNTR_WIDTH-1);
      end if;
    end if;
  end process;

  clk_out_tick_p : process(clk_in)
  begin
    if rising_edge(clk_in) then
      if rst = '1' then
        clk_out_tick <= '0';
      else
        if cntr = CNTR_END_VALUE then
          clk_out_tick <= '1';
        else
          clk_out_tick <= '0';
        end if;
      end if;
    end if;
  end process;

  gen_clk_out_div32 : if DIV > 63 generate
  begin
    clk_out_div64_p <= slv_cntr(5);
    clk_out_div64_n <= not slv_cntr(5);
  end generate gen_clk_out_div32;

  do_not_gen_clk_out_div32 : if DIV < 64 generate
    constant CNTR_2_WIDTH : integer                                 := (5 - integer(log2(real(DIV))));
    signal cntr_2         : unsigned(CNTR_2_WIDTH downto 0)         := (others => '0');
    signal slv_cntr_2     : std_logic_vector(CNTR_2_WIDTH downto 0) := (others => '0');
  begin
    counter_2_p : process(clk_in)
    begin
      if rising_edge(clk_in) then
        if rst = '1' then
          cntr_2 <= (others => '0');
        else
          if cntr = CNTR_MAX then
            cntr_2 <= cntr_2+1;
          end if;
        end if;
      end if;
    end process;
    slv_cntr_2      <= std_logic_vector(cntr_2);
    clk_out_div64_p <= slv_cntr_2(CNTR_2_WIDTH);
    clk_out_div64_n <= not slv_cntr_2(CNTR_2_WIDTH);
  end generate do_not_gen_clk_out_div32;

end rtl;
