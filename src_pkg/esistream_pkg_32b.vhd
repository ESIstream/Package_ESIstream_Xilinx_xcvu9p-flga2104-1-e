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
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package esistream_pkg is
  constant DESER_WIDTH          : natural range 32 to 64 := 32; -- 32 = ESIstream 32b / 64 = ESIstream 64b 
  constant SER_WIDTH            : natural range 32 to 64 := 32; -- 32 = ESIstream 32b / 64 = ESIstream 64b 
  type slv_01_array_n is array (natural range <>) of std_logic_vector(01-1 downto 0);
  type slv_02_array_n is array (natural range <>) of std_logic_vector(02-1 downto 0);
  type slv_03_array_n is array (natural range <>) of std_logic_vector(03-1 downto 0);
  type slv_04_array_n is array (natural range <>) of std_logic_vector(04-1 downto 0);
  type slv_08_array_n is array (natural range <>) of std_logic_vector(08-1 downto 0);
  type slv_12_array_n is array (natural range <>) of std_logic_vector(12-1 downto 0);
  type slv_14_array_n is array (natural range <>) of std_logic_vector(14-1 downto 0);
  type slv_16_array_n is array (natural range <>) of std_logic_vector(16-1 downto 0);
  type slv_17_array_n is array (natural range <>) of std_logic_vector(17-1 downto 0);
  type slv_32_array_n is array (natural range <>) of std_logic_vector(32-1 downto 0);
  type uns_12_array_n is array (natural range <>) of unsigned        (12-1 downto 0);
  type uns_16_array_n is array (natural range <>) of unsigned        (16-1 downto 0);
  type sig_16_array_n is array (natural range <>) of signed          (16-1 downto 0);
  type sig_07_array_n is array (natural range <>) of signed          (07-1 downto 0);

  --
  type data_array     is array (natural range <>) of slv_14_array_n(1 downto 0);
  type frame_array    is array (natural range <>) of slv_16_array_n(1 downto 0);
  type rx_data_array  is array (natural range <>) of slv_14_array_n(DESER_WIDTH/16 - 1 downto 0);
  type rx_frame_array is array (natural range <>) of slv_16_array_n(DESER_WIDTH/16 - 1 downto 0);
  type tx_data_array  is array (natural range <>) of slv_14_array_n(  SER_WIDTH/16 - 1 downto 0);
  function f_lfsr(data_in : std_logic_vector(16 downto 0)                   ) return std_logic_vector;
  function f_lfsr(data_in : std_logic_vector(16 downto 0); n_loop : integer ) return std_logic_vector;
  function or1   (      r : std_logic_vector                                ) return std_logic;
  function and1  (      r : std_logic_vector                                ) return std_logic;
  function nand1 (      r : std_logic_vector                                ) return std_logic;

end package esistream_pkg;

package body esistream_pkg is 
  --============================================================================================================================
  -- The LFSR polynomial used is X17+X3+1. 
  -- The LFSR is based on a Fibonacci architecture working with steps of 14 bits shifts. 
  -- The following equations characterize this LFSR:
  --============================================================================================================================
  function f_lfsr(data_in : std_logic_vector(16 downto 0) ) return std_logic_vector is
        variable v_lfsr : std_logic_vector(16 downto 0);
    begin
              v_lfsr(0)  := data_in(14);
              v_lfsr(1)  := data_in(15);
              v_lfsr(2)  := data_in(16);
              v_lfsr(3)  := data_in(0)  xor  data_in(3);
              v_lfsr(4)  := data_in(1)  xor  data_in(4);
              v_lfsr(5)  := data_in(2)  xor  data_in(5);
              v_lfsr(6)  := data_in(3)  xor  data_in(6);
              v_lfsr(7)  := data_in(4)  xor  data_in(7);
              v_lfsr(8)  := data_in(5)  xor  data_in(8);
              v_lfsr(9)  := data_in(6)  xor  data_in(9);
              v_lfsr(10) := data_in(7)  xor  data_in(10);
              v_lfsr(11) := data_in(8)  xor  data_in(11);
              v_lfsr(12) := data_in(9)  xor  data_in(12);
              v_lfsr(13) := data_in(10) xor  data_in(13);
              v_lfsr(14) := data_in(11) xor  data_in(14);
              v_lfsr(15) := data_in(12) xor  data_in(15);
              v_lfsr(16) := data_in(13) xor  data_in(16);
          return v_lfsr;
    end function f_lfsr;
    
  --============================================================================================================================
  -- The LFSR polynomial used is X17+X3+1. 
  -- The LFSR is based on a Fibonacci architecture working with steps of 14 bits shifts. 
  -- The following equations characterize this LFSR:
  --============================================================================================================================
  function f_lfsr(data_in : std_logic_vector(16 downto 0); n_loop : integer ) return std_logic_vector is
        variable v_lfsr : std_logic_vector(16 downto 0);
    begin
        v_lfsr := data_in;
        for i in 0 to n_loop-1 loop
              v_lfsr := f_lfsr(v_lfsr);
        end loop;
        return v_lfsr;
    end function f_lfsr;
  
  --============================================================================================================================
  -- Unary Reduction Operators
  --============================================================================================================================  
  function or1 (r : std_logic_vector) return std_logic is 
    variable result : std_logic := '0'; 
  begin 
    for i in r'range loop 
        result := result or  r(i); 
    end loop; 
    return     result ;
  end function or1 ;
  
  function and1(r : std_logic_vector) return std_logic is
    variable result : std_logic := '1';
  begin
    for i in r'range loop
        result := result and  r(i); 
    end loop; 
    return result;
  end function and1;

  function nand1(r : std_logic_vector) return std_logic is
    variable result : std_logic := '1';
  begin
    for i in r'range loop
        result := result nand  r(i); 
    end loop; 
    return result;
  end function nand1;

end package body esistream_pkg;
