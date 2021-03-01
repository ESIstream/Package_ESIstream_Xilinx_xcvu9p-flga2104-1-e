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
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity spi_refclk is
  generic(
    CLK_MHz     : real := 100.0;
    SPI_CLK_MHz : real := 10.0
    );
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    refclk    : out std_logic;
    refclk_re : out std_logic;
    refclk_fe : out std_logic
    );
end spi_refclk;

architecture rtl of spi_refclk is
  
  constant cntr_msb                       : integer                      := integer(log2(real(CLK_MHz/SPI_CLK_MHz/2.0)));
  signal cntr                             : unsigned(cntr_msb downto 0)  := (others => '0');
  constant cntr_init                      : unsigned(cntr_msb downto 0)  := to_unsigned(integer(real(CLK_MHz/SPI_CLK_MHz/2.0-1.0)), cntr'length);
  signal refclk_i                         : std_logic                    := '0';
  signal refclk_sr                        : std_logic_vector(2 downto 0) := (others => '0');

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cntr     <= cntr_init;
        refclk_i <= '0';
      else
        if cntr = 0 then
          cntr     <= cntr_init;
          refclk_i <= not refclk_i;
        else
          cntr     <= cntr-1;
          refclk_i <= refclk_i;
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        refclk_sr <= (others => '0');
      else
        refclk_sr(0) <= refclk_i;
        refclk_sr(2 downto 1) <= refclk_sr(1 downto 0);
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        refclk_fe <= '0';
        refclk_re <= '0';
      else
        -- rising edge
        if refclk_sr(1 downto 0) = "01" then
          refclk_re <= '1';
        else
          refclk_re <= '0';
        end if;
        -- falling edge
        if refclk_sr(1 downto 0) = "10" then
          refclk_fe <= '1';
        else
          refclk_fe <= '0';
        end if;
      end if;
    end if;
  end process;

  refclk <= refclk_sr(2);
  
end rtl;
