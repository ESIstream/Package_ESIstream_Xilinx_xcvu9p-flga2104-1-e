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
-- Description :
--      Generates pseudo-random binary sequence (PRBS) to scramble
--      data using a linear feedback shift register (LFSR) based on a
--      Fibonacci architecture and using polynomial X17+X3+1.
-- Support only : LFSR 64b / LFSR 32b / LFSR 16b
----------------------------------------------------------------------------------------------------
-- Version      Date            Author      Description
-- 0.1          2019/06/18      REFLEXCES   Creation
-- 1.0          2019/06/18      REFLEXCES   Publication
----------------------------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;

library work;
use work.esistream_pkg.all;

entity tx_lfsr is
  port (
    clk        : in  std_logic;
    init       : in  std_logic;                                         -- Initialize LFSR with init_value
    init_value : in  std_logic_vector(16 downto 0) := (others => '1');  -- Initial value of LFSR
    lfsr_out   : out slv_14_array_n((SER_WIDTH/16)-1 downto 0)
    );
end entity tx_lfsr;

architecture rtl of tx_lfsr is

  --============================================================================================================================
  -- Function and Procedure declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Constant and Type declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Component declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Signal declarations
  --============================================================================================================================
  signal lfsr_out_t : slv_17_array_n((SER_WIDTH/16)-1 downto 0) := (others => (others => '1'));

begin

  gen_lfsr_per_deser : for index in 0 to (SER_WIDTH/16)-1 generate
    lfsr_out(index) <= lfsr_out_t(index)(13 downto 0);
  end generate gen_lfsr_per_deser;
  --============================================================================================================================
  -- LFSR 64b if SER_WIDTH = 64  
  --============================================================================================================================
  gen_lfsr_64b : if SER_WIDTH = 64 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if init = '1' then
          lfsr_out_t <= (others => init_value);
        else
          lfsr_out_t(0) <= f_lfsr(lfsr_out_t(3));
          lfsr_out_t(1) <= f_lfsr(f_lfsr(lfsr_out_t(3)));
          lfsr_out_t(2) <= f_lfsr(f_lfsr(f_lfsr(lfsr_out_t(3))));
          lfsr_out_t(3) <= f_lfsr(f_lfsr(f_lfsr(f_lfsr(lfsr_out_t(3)))));
        end if;
      end if;
    end process;
  end generate gen_lfsr_64b;

  --============================================================================================================================
  -- LFSR 32b if SER_WIDTH = 32  
  --============================================================================================================================
  gen_lfsr_32b : if SER_WIDTH = 32 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if init = '1' then
          lfsr_out_t <= (others => init_value);
        else

          lfsr_out_t(0) <= f_lfsr(lfsr_out_t(1));
          lfsr_out_t(1) <= f_lfsr(f_lfsr(lfsr_out_t(1)));
        end if;
      end if;
    end process;
  end generate gen_lfsr_32b;

  --============================================================================================================================
  -- LFSR 16b if SER_WIDTH = 16  
  --============================================================================================================================
  gen_lfsr_16b : if SER_WIDTH = 16 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if init = '1' then
          lfsr_out_t <= (others => init_value);
        else
          lfsr_out_t(0) <= f_lfsr(lfsr_out_t(0));
        end if;
      end if;
    end process;
  end generate gen_lfsr_16b;

end architecture rtl;
