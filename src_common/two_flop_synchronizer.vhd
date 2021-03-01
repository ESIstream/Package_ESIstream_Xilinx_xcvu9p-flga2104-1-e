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

entity two_flop_synchronizer is
  port(
    clk       : in  std_logic;
    reg_async : in  std_logic;
    reg_sync  : out std_logic
    );
end two_flop_synchronizer;

architecture rtl of two_flop_synchronizer is
  --
  signal sig_meta                 : std_logic;
  signal sigb                    : std_logic;
  attribute ASYNC_REG             : string;
  attribute ASYNC_REG of sig_meta : signal is "TRUE";
  attribute ASYNC_REG of sigb     : signal is "TRUE";
  --
begin

  P_2FF : process(clk)
  begin
    if rising_edge(clk) then
      sig_meta <= reg_async;  -- metastable
      sigb     <= sig_meta;   -- stable
    end if;
  end process;
  reg_sync <= sigb;
end rtl;
