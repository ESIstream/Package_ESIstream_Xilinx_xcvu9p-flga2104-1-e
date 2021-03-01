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
-- 1.2          2020            Teledyne-e2v Asynchronous logic, remove Flip-Flops 
-------------------------------------------------------------------------------
-- Description :
-- Applies descrambling and reverse disparity processing on each frame.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity rx_decoding is
  port (
    clk        : in  std_logic;
    data_in    : in  std_logic_vector(16-1 downto 0);  -- Input aligned frames
    prbs_value : in  std_logic_vector(14-1 downto 0);  -- Input PRBS value to descramble data
    prbs_en    : in  std_logic;                        -- Signal to configure if descrambling is enabled ('1') or not ('0')
    data_out   : out std_logic_vector(16-1 downto 0)   -- Output decoded data
    );
end entity rx_decoding;

architecture behavioral of rx_decoding is

  signal data_mask     : std_logic_vector(16-2 downto 0);
  signal data_out_t    : std_logic_vector(16-1 downto 0);
  signal prbs_value_en : std_logic_vector(16-1 downto 0);
  signal prbs_mask     : std_logic_vector(14-1 downto 0);
  signal data_dbp      : std_logic_vector(16-1 downto 0);

begin

  prbs_mask <= (others => prbs_en);
  data_mask <= (others => data_in(15));

  data_dbp(15)          <= data_in(15);
  data_dbp(14 downto 0) <= (data_in(14 downto 0) xor data_mask);

  -- possibility to remove and operation when prbs always enable.
  prbs_value_en(15 downto 14) <= "00";
  prbs_value_en(13 downto 0)  <= (prbs_mask and prbs_value);
  data_out_t <= data_dbp xor prbs_value_en;
  data_out <= data_out_t;
end architecture behavioral;
