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
-- 1.0          2019            teledyne e2v Creation
-- 1.1          2019            teledyne e2v bitslip integer, add bitslip_d to facilitate place&route.
-- 1.2          2021            teledyne e2v DESER_WIDTH 16-bit, 32-bit and 64-bit supported
-- 1.3          2021            teledyne e2v New implementation to align frame that
--                                           reduces the amount of logic ressources used
--                                           and improves resistance timing errors.
-------------------------------------------------------------------------------
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity rx_frame_alignment is
  generic (
    COMMA : std_logic_vector(31 downto 0) := X"00FFFF00"              -- COMMA to look for  
    );
  port (
    clk              : in  std_logic;
    din              : in  std_logic_vector(DESER_WIDTH-1 downto 0);  -- Input misaligned frames 
    sync             : in  std_logic;                                 -- Pulse when start synchronization
    align_busy       : out std_logic;
    aligned_data     : out slv_16_array_n(0 to (DESER_WIDTH/16)-1);   -- Output aligned frames
    aligned_data_rdy : out std_logic                                  -- Indicates that frame alignment is done
    );
end entity rx_frame_alignment;

architecture rtl of rx_frame_alignment is
  -------------------------------------------------------------
  -- functions declaration
  -------------------------------------------------------------
  function f_init_data_but_comma_width return natural is
    variable v_dbc : natural;
  begin
    if DESER_WIDTH = 64 then
      v_dbc := DESER_WIDTH*2-1;
    elsif DESER_WIDTH = 32 then
      v_dbc := DESER_WIDTH*2-1;
    else
      v_dbc := DESER_WIDTH*3-1;
    end if;
    return v_dbc;
  end function f_init_data_but_comma_width;
  --
  function f_comma_shift return natural is
    variable v_cs : natural;
  begin
    if DESER_WIDTH = 64 then
      v_cs := COMMA'length-1;
    elsif DESER_WIDTH = 32 then
      v_cs := COMMA'length-1;
    else
      v_cs := COMMA'length/2-1;
    end if;
    return v_cs;
  end function f_comma_shift;
  -------------------------------------------------------------
  -- signals declaration
  -------------------------------------------------------------
  signal data_buf       : std_logic_vector(DESER_WIDTH*2-1 downto 0)             := (others => '0');  -- buffer used to get aligned data
  signal data_buf_comma : std_logic_vector(f_init_data_but_comma_width downto 0) := (others => '0');  -- buffer used to look for COMMA
  signal bitslip        : integer range 0 to 31                                  := 0;                -- number of bit slip to align frames
  signal bitslip_d      : integer range 0 to 31                                  := 0;                -- number of bit slip to align frames
  signal data_out_t     : std_logic_vector(DESER_WIDTH-1 downto 0)               := (others => '0');
  signal frame_align    : std_logic                                              := '0';              -- If '1' frame alignment done
  signal frame_align_d  : std_logic                                              := '0';              -- If '1' frame alignment done
  signal busy           : std_logic                                              := '0';              -- If '1', frame alignment in progress
  signal bitslip_t      : std_logic_vector(DESER_WIDTH-1 downto 0)               := (others => '0');  -- Temp bitslip
  signal comp_in_comma  : slv_32_array_n(f_comma_shift downto 0)                 := (others => (others => '0'));
  signal comp_out_comma : slv_16_array_n(f_comma_shift downto 0)                 := (others => (others => '0'));
begin

  process(clk)
  begin
    if rising_edge(clk) then
      frame_align_d                                <= frame_align;
      bitslip_d                                    <= bitslip;
      data_out_t                                   <= data_buf(bitslip_d+DESER_WIDTH downto bitslip_d+1);
      --
      data_buf(2*DESER_WIDTH-1 downto DESER_WIDTH) <= din;
      data_buf(DESER_WIDTH-1 downto 0)             <= data_buf(2*DESER_WIDTH-1 downto DESER_WIDTH);
    end if;
  end process;

  gen_data_buf_comma_16b : if DESER_WIDTH = 16 generate
    process(clk)
    begin
      if rising_edge(clk) then
        data_buf_comma(3*DESER_WIDTH-1 downto 2*DESER_WIDTH) <= din;
        data_buf_comma(2*DESER_WIDTH-1 downto DESER_WIDTH)   <= data_buf_comma(3*DESER_WIDTH-1 downto 2*DESER_WIDTH);
        data_buf_comma(DESER_WIDTH-1 downto 0)               <= data_buf_comma(2*DESER_WIDTH-1 downto DESER_WIDTH);
      end if;
    end process;
  end generate gen_data_buf_comma_16b;

  gen_data_buf_comma_32b_or_64b : if DESER_WIDTH = 32 or DESER_WIDTH = 64 generate
    process(clk)
    begin
      if rising_edge(clk) then
        data_buf_comma(2*DESER_WIDTH-1 downto DESER_WIDTH) <= din;
        data_buf_comma(DESER_WIDTH-1 downto 0)             <= data_buf_comma(2*DESER_WIDTH-1 downto DESER_WIDTH);
      end if;
    end process;
  end generate gen_data_buf_comma_32b_or_64b;

  gen_bitslip : for i in f_comma_shift downto 0 generate
    gen_comma_1 : if COMMA = x"FF0000FF" generate
      comp_in_comma(i)      <= data_buf_comma(i+COMMA'length downto i+1);
      --
      comp_out_comma(i)(0)  <= comp_in_comma(i)(0) and comp_in_comma(i)(1);
      comp_out_comma(i)(1)  <= comp_in_comma(i)(2) and comp_in_comma(i)(3);
      comp_out_comma(i)(2)  <= comp_in_comma(i)(4) and comp_in_comma(i)(5);
      comp_out_comma(i)(3)  <= comp_in_comma(i)(6) and comp_in_comma(i)(7);
      comp_out_comma(i)(4)  <= comp_in_comma(i)(8) nor comp_in_comma(i)(9);
      comp_out_comma(i)(5)  <= comp_in_comma(i)(10) nor comp_in_comma(i)(11);
      comp_out_comma(i)(6)  <= comp_in_comma(i)(12) nor comp_in_comma(i)(13);
      comp_out_comma(i)(7)  <= comp_in_comma(i)(14) nor comp_in_comma(i)(15);
      comp_out_comma(i)(8)  <= comp_in_comma(i)(16) nor comp_in_comma(i)(17);
      comp_out_comma(i)(9)  <= comp_in_comma(i)(18) nor comp_in_comma(i)(19);
      comp_out_comma(i)(10) <= comp_in_comma(i)(20) nor comp_in_comma(i)(21);
      comp_out_comma(i)(11) <= comp_in_comma(i)(22) nor comp_in_comma(i)(23);
      comp_out_comma(i)(12) <= comp_in_comma(i)(24) and comp_in_comma(i)(25);
      comp_out_comma(i)(13) <= comp_in_comma(i)(26) and comp_in_comma(i)(27);
      comp_out_comma(i)(14) <= comp_in_comma(i)(28) and comp_in_comma(i)(29);
      comp_out_comma(i)(15) <= comp_in_comma(i)(30) and comp_in_comma(i)(31);
    end generate gen_comma_1;

    gen_comma_2 : if COMMA = x"00FFFF00" generate
      comp_in_comma(i)      <= data_buf_comma(i+COMMA'length downto i+1);
      --
      comp_out_comma(i)(0)  <= comp_in_comma(i)(0) nor comp_in_comma(i)(1);
      comp_out_comma(i)(1)  <= comp_in_comma(i)(2) nor comp_in_comma(i)(3);
      comp_out_comma(i)(2)  <= comp_in_comma(i)(4) nor comp_in_comma(i)(5);
      comp_out_comma(i)(3)  <= comp_in_comma(i)(6) nor comp_in_comma(i)(7);
      comp_out_comma(i)(4)  <= comp_in_comma(i)(8) and comp_in_comma(i)(9);
      comp_out_comma(i)(5)  <= comp_in_comma(i)(10) and comp_in_comma(i)(11);
      comp_out_comma(i)(6)  <= comp_in_comma(i)(12) and comp_in_comma(i)(13);
      comp_out_comma(i)(7)  <= comp_in_comma(i)(14) and comp_in_comma(i)(15);
      comp_out_comma(i)(8)  <= comp_in_comma(i)(16) and comp_in_comma(i)(17);
      comp_out_comma(i)(9)  <= comp_in_comma(i)(18) and comp_in_comma(i)(19);
      comp_out_comma(i)(10) <= comp_in_comma(i)(20) and comp_in_comma(i)(21);
      comp_out_comma(i)(11) <= comp_in_comma(i)(22) and comp_in_comma(i)(23);
      comp_out_comma(i)(12) <= comp_in_comma(i)(24) nor comp_in_comma(i)(25);
      comp_out_comma(i)(13) <= comp_in_comma(i)(26) nor comp_in_comma(i)(27);
      comp_out_comma(i)(14) <= comp_in_comma(i)(28) nor comp_in_comma(i)(29);
      comp_out_comma(i)(15) <= comp_in_comma(i)(30) nor comp_in_comma(i)(31);
    end generate gen_comma_2;
    
    process(clk)
    begin
      if rising_edge(clk) then
          bitslip_t(i) <= and1(comp_out_comma(i));
      end if;
    end process;
  end generate gen_bitslip;

  process(clk)
  begin
    if rising_edge(clk) then
      -- Start frame alignment sequence:
      if sync = '1' then
        busy        <= '1';
        frame_align <= '0';
        bitslip     <= 0;
      -- Look for COMMA: 
      elsif busy = '1' then
        for i in f_comma_shift downto 0 loop
          if bitslip_t(i) = '1' then
            bitslip     <= i;
            frame_align <= '1';
            busy        <= '0';
          end if;
        end loop;
      end if;
    end if;
  end process;

  gen_aligned_data : for index in 0 to (DESER_WIDTH/16)-1 generate
    aligned_data(index) <= data_out_t((15 + 16*index) downto (0+16*index));
  end generate gen_aligned_data;

  process(clk)
  begin
    if rising_edge(clk) then
      -- realign aligned_data_rdy with aligned_data.
      aligned_data_rdy <= frame_align_d;
    end if;
  end process;
  align_busy <= busy;

end architecture rtl;
