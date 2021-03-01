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
-- 1.1          2020            Teledyne-e2v Tx emulator, add lss output flag (lane synchronization sequence) 
-------------------------------------------------------------------------------
-- Description:
-- This module is designed for hdl testbench only.
-- This module can't be synthesized and implemented on a fpga.  
-------------------------------------------------------------------------------
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module is designed for hdl testbench only.
-- This module can't be synthesized and implemented on a fpga. 
entity tx_emu_esistream_top is
  generic(
    NB_LANES : integer                       := 8;
    COMMA    : std_logic_vector(31 downto 0) := x"00FFFF00"
    );
  port (
    rst         : in  std_logic;
    clk         : in  std_logic;                     -- Lane data rate frequency 6GHz/12GHz/12.8GHz...
    sync_in     : in  std_logic;                     -- Resets LFSR, disparity and starts synchronization
    prbs_en     : in  std_logic;                     -- Enables scrambling processing
    disp_en     : in  std_logic;                     -- Enables disparity processing
    lfsr_init   : in  slv_17_array_n(NB_LANES-1 downto 0) := (others => (others => '1'));
    data_ctrl   : in  std_logic_vector(1 downto 0);  -- tx data control: "00" (all '0'); "01" (postive ramp); "10" (negative ramp); "11" (all '1')
    sso_p       : out std_logic;
    sso_n       : out std_logic;
    tx_clk      : out std_logic;
    tx_ip_ready : out std_logic;
    txp         : out std_logic_vector(NB_LANES-1 downto 0);
    txn         : out std_logic_vector(NB_LANES-1 downto 0);
    lss         : out std_logic                      -- when '1' lane synchronization sequence (FAS + PSS) else normal operation.       
    );
end entity tx_emu_esistream_top;

architecture rtl of tx_emu_esistream_top is
  --
  signal clk_out        : std_logic                                    := '0';
  signal clk_out_tick   : std_logic                                    := '0';
  signal clk_out_cntr   : integer range 0 to SER_WIDTH-1               := 0;
  signal data_out       : std_logic_vector(15 downto 0)                := (others => '0');
  signal data_out_mem   : std_logic_vector(15 downto 0)                := (others => '0');
  signal nrst_data_gen  : std_logic                                    := '1';
  signal tx_rstdone     : std_logic_vector(NB_LANES-1 downto 0)        := (others => '1');
  signal xcvr_pll_lock  : std_logic_vector(NB_LANES-1 downto 0)        := (others => '1');
  signal tx_usrclk      : std_logic                                    := '0';
  signal xcvr_data_tx   : std_logic_vector(SER_WIDTH*NB_LANES-1 downto 0);
  --signal tx_usrrdy      : std_logic_vector(NB_LANES-1 downto 0);
  signal tx_data        : tx_data_array(NB_LANES-1 downto 0);
  signal ip_ready       : std_logic;
  --signal data_out_0     : std_logic_vector(11 downto 0)                := (others => '0');
  --signal data_out_1     : std_logic_vector(11 downto 0)                := (others => '0');
  --signal data_out_2     : std_logic_vector(11 downto 0)                := (others => '0');
  --signal data_out_3     : std_logic_vector(11 downto 0)                := (others => '0');
  type slv_deser_width_array_n is array (natural range <>) of std_logic_vector(SER_WIDTH-1 downto 0);
  signal data_encoded   : slv_deser_width_array_n(NB_LANES-1 downto 0) := (others => (others => '0'));
  signal data_encoded_m : slv_deser_width_array_n(NB_LANES-1 downto 0) := (others => (others => '0'));

--
begin

  nrst_data_gen <= not (rst or sync_in);
  tx_clk        <= tx_usrclk;
  tx_ip_ready   <= '1';
  tx_emu_clk_pow2_divider_1 : entity work.tx_emu_clk_pow2_divider
    generic map(
      DIV => SER_WIDTH)
    port map (
      rst             => rst,
      clk_in          => clk,
      clk_out         => tx_usrclk,
      clk_out_div64_p => sso_p,
      clk_out_div64_n => sso_n,
      clk_out_tick    => clk_out_tick,
      clk_out_cntr    => clk_out_cntr);

  tx_emu_data_gen_top_1 : entity work.tx_emu_data_gen_top
    generic map (
      NB_LANES => NB_LANES)
    port map (
      nrst    => nrst_data_gen,
      clk     => tx_usrclk,
      d_ctrl  => data_ctrl,
      tx_data => tx_data);

  --tx_emu_data_gen_1 : entity work.tx_emu_data_gen
  --  port map (
  --    nrst       => nrst_data_gen,
  --    clk        => tx_usrclk,
  --    d_ctrl     => data_ctrl,
  --    data_out_0 => data_out_0,
  --    data_out_1 => data_out_1,
  --    data_out_2 => data_out_2,
  --    data_out_3 => data_out_3);
  -- 
  --gen_data_16b : if SER_WIDTH = 16 generate
  --begin
  --  process(data_out_0)
  --  begin
  --    for idx_lane in 0 to NB_LANES-1 loop
  --      tx_data(idx_lane)(0)(13 downto 12) <= "00";
  --      tx_data(idx_lane)(0)(11 downto 0)  <= data_out_0;
  --    end loop;
  --  end process;
  --end generate gen_data_16b;
  -- 
  --gen_data_32b : if SER_WIDTH = 32 generate
  --begin
  --  process(data_out_0, data_out_1)
  --  begin
  --    for idx_lane in 0 to NB_LANES-1 loop
  --      for idx in 0 to SER_WIDTH/16-1 loop
  --        case (idx mod 2) is
  --          when 0 =>
  --            tx_data(idx_lane)(idx)(13 downto 12) <= "00";
  --            tx_data(idx_lane)(idx)(11 downto 0)  <= data_out_0;
  --          when others =>
  --            tx_data(idx_lane)(idx)(13 downto 12) <= "00";
  --            tx_data(idx_lane)(idx)(11 downto 0)  <= data_out_1;
  --        end case;
  --      end loop;
  --    end loop;
  --  end process;
  --end generate gen_data_32b;
  -- 
  --gen_data_64b : if SER_WIDTH = 64 generate
  --begin
  --  process(data_out_0, data_out_1, data_out_2, data_out_3)
  --  begin
  --    for idx_lane in 0 to NB_LANES-1 loop
  --      for idx in 0 to SER_WIDTH/16-1 loop
  --        case idx is
  --          when 0 =>
  --            tx_data(idx_lane)(idx)(13 downto 12) <= "00";
  --            tx_data(idx_lane)(idx)(11 downto 0)  <= data_out_0;
  --          when 1 =>
  --            tx_data(idx_lane)(idx)(13 downto 12) <= "00";
  --            tx_data(idx_lane)(idx)(11 downto 0)  <= data_out_1;
  --          when 2 =>
  --            tx_data(idx_lane)(idx)(13 downto 12) <= "00";
  --            tx_data(idx_lane)(idx)(11 downto 0)  <= data_out_2;
  --          when others =>
  --            tx_data(idx_lane)(idx)(13 downto 12) <= "00";
  --            tx_data(idx_lane)(idx)(11 downto 0)  <= data_out_3;
  --        end case;
  --      end loop;
  --    end loop;
  --  end process;
  --end generate gen_data_64b;

  tx_emu_esistream_1 : entity work.tx_emu_esistream
    generic map (
      NB_LANES => NB_LANES,
      COMMA    => COMMA)
    port map (
      rst           => rst,
      rst_xcvr      => open,  -- rst_xcvr,
      tx_rstdone    => tx_rstdone,
      xcvr_pll_lock => xcvr_pll_lock,
      tx_usrclk     => tx_usrclk,
      xcvr_data_tx  => xcvr_data_tx,
      tx_usrrdy     => open,  -- tx_usrrdy,
      sync_in       => sync_in,
      prbs_en       => prbs_en,
      disp_en       => disp_en,
      lfsr_init     => lfsr_init,
      data_in       => tx_data,
      ip_ready      => ip_ready,
      lss           => lss);

  gen_sub_encoding : for idx_lane in NB_LANES-1 downto 0 generate
  begin

    data_encoded(idx_lane) <= xcvr_data_tx(SER_WIDTH*idx_lane + (SER_WIDTH-1) downto SER_WIDTH*idx_lane + 0);

    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          data_encoded_m(idx_lane) <= (others => '0');
        else
          if clk_out_tick = '1' then
            data_encoded_m(idx_lane) <= data_encoded(idx_lane);
          else
            data_encoded_m(idx_lane) <= data_encoded_m(idx_lane);
          end if;
        end if;
      end if;
      txp(idx_lane) <= data_encoded_m(idx_lane)(clk_out_cntr);
      txn(idx_lane) <= not data_encoded_m(idx_lane)(clk_out_cntr);
    end process;
  end generate gen_sub_encoding;

  tx_clk <= tx_usrclk;

end architecture rtl;
