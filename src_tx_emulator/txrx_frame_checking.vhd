-------------------------------------------------------------------------------
-- This-------------------------------------------------------------------------------
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
-- 1.0          2021-01         Teledyne e2v Creation
------------------------------------------------------------------------------- 
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity txrx_frame_checking is
  generic(
    NB_LANES : natural
    );
  port (
    rst          : in  std_logic;                     -- Active high reset. 
    clk          : in  std_logic;                     -- 
    d_ctrl       : in  std_logic_vector(1 downto 0);  -- 
    lanes_on     : in  std_logic_vector(NB_LANES-1 downto 0);
    frame_out    : in  rx_frame_array(NB_LANES-1 downto 0);
    valid_out    : in  std_logic_vector(NB_LANES-1 downto 0);
    be_status    : out std_logic;                     -- Active high, bit error detected.
    cb_status    : out std_logic;                     -- Active high, clock bit error detected.
    valid_status : out std_logic
    );
end entity txrx_frame_checking;

architecture rtl of txrx_frame_checking is
  --
  function f_cb_check_value return std_logic is
    variable v_cb_cv : std_logic;
  begin
    if DESER_WIDTH = 64 then
      v_cb_cv := '0';
    elsif DESER_WIDTH = 32 then
      v_cb_cv := '0';
    else
      v_cb_cv := '1';
    end if;
    return v_cb_cv;
  end function f_cb_check_value;
  --
  --constant BER_NO_ERROR    : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  --constant CB_NO_ERROR     : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  constant RAMP_DATA_WIDTH   : natural                                      := 12;
  constant ADD_U12_LATENCY   : natural := 3;
  ----
  type ramp_array is array (natural range <>) of slv_12_array_n(DESER_WIDTH/16-1 downto 0);
  type ramp_uarray is array (natural range <>) of uns_12_array_n(DESER_WIDTH/16-1 downto 0);
  type cb_array is array (natural range <>) of slv_01_array_n(DESER_WIDTH/16-1 downto 0);
  --
  signal sum                 : ramp_array(NB_lANES-1 downto 0)              := (others => (others => (others => '0')));
  signal u_sum               : ramp_uarray(NB_LANES-1 downto 0)             := (others => (others => (others => '0')));
  signal step                : std_logic_vector(RAMP_DATA_WIDTH-1 downto 0) := (others => '0');
--
  signal data_check_per_lane : slv_04_array_n(NB_LANES-1 downto 0)          := (others => (others => '0'));
  signal data_check_all_lane : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal cb_check_per_lane   : slv_04_array_n(NB_LANES-1 downto 0)          := (others => (others => '0'));
  signal cb_check_all_lane   : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  --
  signal cb_out_d            : cb_array(NB_LANES-1 downto 0)                := (others => (others => (others => '0')));
  --
  signal data_out_12b        : ramp_array(NB_LANES-1 downto 0);
  signal data_out_12b_d      : ramp_array(NB_LANES-1 downto 0);
  signal valid_out_d1        : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal valid_out_d2        : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal valid_out_d3        : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal valid_out_d4        : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal valid_out_d5        : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal valid_out_d6        : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
--
begin
  -- 
  process(clk)
  begin
    if rising_edge(clk) then
      if (d_ctrl(0) xor d_ctrl(1)) = '0' then
        step <= (others => '0');  -- just check data don't change, either all at x"000" or all at x"FFF". 
      else
        step <= std_logic_vector(to_unsigned(DESER_WIDTH*ADD_U12_LATENCY/8, RAMP_DATA_WIDTH));
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      valid_out_d1 <= valid_out and lanes_on;
      valid_out_d2 <= valid_out_d1;
      valid_out_d3 <= valid_out_d2;
      valid_out_d4 <= valid_out_d3;
      valid_out_d5 <= valid_out_d4;
      valid_out_d6 <= valid_out_d5;
    end if;
  end process;

  lanes_assign : for i in 0 to NB_LANES-1 generate
    channel_assign : for j in 0 to DESER_WIDTH/16-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          data_out_12b(i)(j)   <= frame_out(i)(j)(12-1 downto 0);
          data_out_12b_d(i)(j) <= data_out_12b(i)(j);
        end if;
      end process;
    end generate channel_assign;
  end generate lanes_assign;

  lanes_check_1 : for i in 0 to NB_LANES-1 generate
    channel_check_1 : for j in 0 to DESER_WIDTH/16-1 generate

      adder_1 : entity work.add_u12
        port map(
          A   => data_out_12b_d(i)(j)(RAMP_DATA_WIDTH-1 downto 0),
          B   => step,
          CLK => clk,
          S   => sum(i)(j));

      u_sum(i)(j) <= unsigned(sum(i)(j));

      p_check_data_0 : process(clk)
      begin
        if rising_edge(clk) then
          if valid_out_d6(i) = '0' then
            data_check_per_lane(i)(j) <= '0';
          elsif unsigned(data_out_12b_d(i)(j)) = u_sum(i)(j) then
            data_check_per_lane(i)(j) <= '0';
          else
            data_check_per_lane(i)(j) <= '1';
          end if;
        end if;
      end process;
      --
      process(clk)
      begin
        if rising_edge(clk) then
          if valid_out_d6(i) = '0' then
            data_check_all_lane(i) <= '0';
          elsif unsigned(data_check_per_lane(i)) = 0 then
            data_check_all_lane(i) <= '0';
          else
            data_check_all_lane(i) <= '1';
          end if;
        end if;
      end process;

      p_check_clock_bit : process(clk)
      begin
        if rising_edge(clk) then
          cb_out_d(i)(j)(0) <= frame_out(i)(j)(14);
          --
          if valid_out_d6(i) = '0' then
            cb_check_per_lane(i)(j) <= '0';
          elsif (frame_out(i)(j)(14) xor cb_out_d(i)(j)(0)) = f_cb_check_value then
            cb_check_per_lane(i)(j) <= '0';
          else
            cb_check_per_lane(i)(j) <= '1';
          end if;
        end if;
      end process;
      --
      process(clk)
      begin
        if rising_edge(clk) then
          if valid_out_d6(i) = '0' then
            cb_check_all_lane(i) <= '0';
          elsif unsigned(cb_check_per_lane(i)) = 0 then
            cb_check_all_lane(i) <= '0';
          else
            cb_check_all_lane(i) <= '1';
          end if;
        end if;
      end process;

    end generate channel_check_1;
  end generate lanes_check_1;

  p_bit_error_status : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or and1(valid_out_d1) = '0' then
        be_status <= '0';
      elsif unsigned(data_check_all_lane) /= 0 then
        be_status <= '1';
      --else
      --  be_status <= be_status;
      end if;
    end if;
  end process;

  p_clock_bit_status : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or and1(valid_out_d1) = '0' then
        cb_status <= '0';
      elsif unsigned(cb_check_all_lane) /= 0 then
        cb_status <= '1';
      --else
      --  cb_status <= cb_status;
      end if;
    end if;
  end process;

  valid_status <= and1(valid_out_d6);

end architecture rtl;
