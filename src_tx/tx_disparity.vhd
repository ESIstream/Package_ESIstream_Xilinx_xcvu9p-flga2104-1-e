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
----------------------------------------------------------------------------------------------------
-- Description :
-- When SER_WIDTH = 32b : Calculates and process disparity (bit-to-bit NOT) for 2x16-bit ESIstream
--                        frames concatenate the overhead disparity bit.
-- When SER_WIDTH = 64b : Calculates and process disparity (bit-to-bit NOT) for 4x16-bit ESIstream
--                        frames concatenate the overhead disparity bit.
----------------------------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.esistream_pkg.all;

entity tx_disparity is
  port (
    nrst        : in  std_logic;
    clk         : in  std_logic;
    sync        : in  std_logic;  -- reset disparity counter
    disp_en     : in  std_logic;  -- enable disparity processing
    data_in     : in  slv_16_array_n((SER_WIDTH/16)-1 downto 0);
    data_in_vld : in  std_logic;
    data_out    : out slv_16_array_n((SER_WIDTH/16)-1 downto 0)
    );
end entity tx_disparity;

architecture rtl of tx_disparity is
  --============================================================================================================================
  -- Function and Procedure declarations
  --============================================================================================================================
  function f_disp_process_data (rd : signed(6 downto 0); dw : sig_07_array_n((SER_WIDTH/16)-1 downto 0); data_in : uns_16_array_n((SER_WIDTH/16)-1 downto 0)) return uns_16_array_n is
    variable v_rd  : sig_07_array_n((SER_WIDTH/16)-1 downto 0);
    variable v_rtn : uns_16_array_n((SER_WIDTH/16)-1 downto 0);
  begin
    v_rd(0) := rd + dw(0);
    for idx in 0 to (SER_WIDTH/16)-1 loop
      if idx /= 0 then v_rd(idx) := v_rd(idx-1) + dw(idx); end if;
      if v_rd(idx) < - 16 or v_rd(idx) > 16 then
        v_rtn(idx) := not data_in(idx);
        v_rd (idx) := v_rd (idx)- dw(idx) - dw(idx);
      else
        v_rtn(idx) := data_in(idx);
      end if;

    end loop;
    return v_rtn;
  end function f_disp_process_data;

  function f_disp_process_rd (rd : signed(6 downto 0); dw : sig_07_array_n((SER_WIDTH/16)-1 downto 0)) return signed is
    variable v_rd : sig_07_array_n((SER_WIDTH/16)-1 downto 0);
  begin
    v_rd(0) := rd + dw(0);
    for idx in 0 to (SER_WIDTH/16)-1 loop
      if idx /= 0 then v_rd(idx) := v_rd(idx-1) + dw(idx); end if;
      if v_rd(idx) < - 16 or v_rd(idx) > 16 then
        v_rd (idx) := v_rd (idx)- dw(idx) - dw(idx);
      end if;
    end loop;
    return v_rd((SER_WIDTH/16)-1)(6 downto 0);
  end function f_disp_process_rd;

  --============================================================================================================================
  -- Constant and Type declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Component declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Signal declarations
  --============================================================================================================================
  signal sync_buf      : std_logic_vector(2 downto 0)              := (others => '0');
  signal u_data_in_d   : uns_16_array_n((SER_WIDTH/16)-1 downto 0) := (others => (others => '0'));  -- undigned delayed data
  signal data_out_t    : uns_16_array_n((SER_WIDTH/16)-1 downto 0) := (others => (others => '0'));  -- undigned delayed data
  signal disp_en_buf   : std_logic                                 := '0';
  signal data_in_vld_d : std_logic                                 := '0';
  signal rd            : signed(6 downto 0)                        := (others => '0');
  signal dw            : sig_07_array_n((SER_WIDTH/16)-1 downto 0) := (others => (others => '0'));  -- signed disparity word 

begin

  --============================================================================================================================
  -- Syncronizer sync
  --============================================================================================================================
  disparity_sync : process(clk, nrst)
  begin
    if nrst = '0' then
      sync_buf <= (others => '0');
    elsif rising_edge(clk) then
      sync_buf(0)          <= sync;
      sync_buf(2 downto 1) <= sync_buf(1 downto 0);
    end if;
  end process;

  --============================================================================================================================
  -- Calculates the current word disparity for a 16-bit ESIstream frame. 
  --============================================================================================================================
  gen_tx_disparity_word_16b : for index in 0 to (SER_WIDTH/16)-1 generate
    i_tx_disparity_word_16b : entity work.tx_disparity_word_16b
      port map (
        nrst        => nrst,
        clk         => clk,
        sync        => sync_buf(2),
        data_in     => data_in(index),
        u_data_in_d => u_data_in_d(index),
        dw          => dw(index)
        );
  end generate gen_tx_disparity_word_16b;

  --============================================================================================================================
  -- Disparity enable process
  --============================================================================================================================
  disparity_enable : process(clk, nrst)
  begin
    if nrst = '0' then
      disp_en_buf <= '0';
    elsif rising_edge(clk) then
      if sync_buf(2) = '1' then
        disp_en_buf <= '0';
      else
        disp_en_buf <= disp_en;
      end if;
    end if;
  end process;

  --============================================================================================================================
  -- Running disparity process
  --============================================================================================================================
  running_disparity : process(clk)
    variable v_rd : signed(6 downto 0);
  begin
    if rising_edge(clk) then
      if sync_buf(2) = '1' then
        data_in_vld_d <= '0';
        for idx in 0 to SER_WIDTH/16-1 loop
          data_out_t (idx) <= x"5555";
        end loop;
        rd <= to_signed(0, rd'length);
      else
        data_in_vld_d <= data_in_vld;
        if disp_en_buf = '0' or data_in_vld_d = '0' then
          -- disparity processing disabled
          data_out_t <= u_data_in_d;
        else
          -- Instead of checking out of range [-16:16] which requires large combinational path (for addition, comparators...).
          -- Perform simple processing by just checking signs of rd and dw.
          -- Note:
          --      - dw is in range [-16:16] because it is computed from 16 bits.
          --      - rd is in range [-16:16] because it is the requirement.
          -- The process:
          --      - If rd and dw have the same sign (both negative or both positive), sum rd and -dw. Resulting rd will be in range [-16:16]
          --              rd e [-16:-1] and dw e [-16:-1] => [-15:15]
          --          or  rd e [  0:16] and dw e [  0:16] => [-16:16]
          --      - If rd and dw have different signs (one negative and other positive), sum rd and dw. Resulting rd will be in range [-16:15]
          --              rd e [-16:-1] and dw e [  0:16] => [-16:15]
          --          or  rd e [  0:16] and dw e [-16:-1] => [-16:15]
          v_rd := rd;
          for idx in 0 to (SER_WIDTH/16)-1 loop
            if v_rd(v_rd'high) = dw(idx)(dw(idx)'high) then v_rd := v_rd - dw(idx); data_out_t(idx) <= not(u_data_in_d(idx));
            else v_rd                                            := v_rd + dw(idx); data_out_t(idx) <= u_data_in_d(idx);
            end if;
          end loop;
          rd <= v_rd;
        end if;
      end if;
    end if;
  end process;

  --============================================================================================================================
  -- Data out generation according to SER_WIDTH
  --============================================================================================================================
  gen_data_out : for idx in 0 to (SER_WIDTH/16)-1 generate
  begin
    data_out(idx) <= std_logic_vector(data_out_t(idx));
  end generate gen_data_out;

end architecture rtl;
