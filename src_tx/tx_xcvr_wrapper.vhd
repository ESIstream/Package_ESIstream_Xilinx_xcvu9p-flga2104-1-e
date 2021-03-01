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

library work;
use work.esistream_pkg.all;

library unisim;
use unisim.vcomponents.all;


entity tx_xcvr_wrapper is
  generic (
    NB_LANES : natural := 4                                                      -- number of lanes
    );
  port (
    rst           : in  std_logic;                                               -- Active high (A)synchronous reset
    rst_xcvr      : in  std_logic_vector(NB_LANES-1 downto 0);                   -- Active high (A)synchronous reset
    tx_rstdone    : out std_logic_vector(NB_LANES-1 downto 0)           := (others => '0');
    tx_usrclk     : out std_logic                                       := '0';  -- user clock
    sysclk        : in  std_logic;                                               -- transceiver ip system clock
    refclk_n      : in  std_logic;                                               -- transceiver ip reference clock
    refclk_p      : in  std_logic;                                               -- transceiver ip reference clock
    txp           : out std_logic_vector(NB_LANES-1 downto 0);                   -- lane serial input p
    txn           : out std_logic_vector(NB_LANES-1 downto 0);                   -- lane Serial input n
    xcvr_pll_lock : out std_logic_vector(NB_LANES-1 downto 0)           := (others => '0');
    tx_usrrdy     : in  std_logic_vector(NB_LANES-1 downto 0)           := (others => '0');
    data_in       : in  std_logic_vector(SER_WIDTH*NB_LANES-1 downto 0) := (others => '0')
    );
end entity tx_xcvr_wrapper;

architecture rtl of tx_xcvr_wrapper is
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
  signal refclk            : std_logic := '0';
  signal tx_rstdone_single : std_logic := '0';
  signal qpll_lock         : std_logic := '0';


begin
  --============================================================================================================================
  -- Assignments
  --============================================================================================================================
  tx_rstdone    <= (others => tx_rstdone_single);
  xcvr_pll_lock <= (others => qpll_lock);


  --============================================================================================================================
  -- Clock buffer for REFCLK
  --============================================================================================================================
  IBUFDS_GTE3_MGTREFCLK0_INST : IBUFDS_GTE3
    generic map(
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",
      REFCLK_ICNTL_RX    => "00"
      )
    port map(
      I     => refclk_p,
      IB    => refclk_n,
      CEB   => '0',
      O     => refclk,
      ODIV2 => open
      );


  --============================================================================================================================
  -- XCVR instance
  --============================================================================================================================
  -- GTH Transceivers
  gth_tx_sfp_1 : entity work.gth_rx_tx_sfp
    port map(
      gtwiz_userclk_tx_reset_in(0)       => rst_xcvr,
      gtwiz_userclk_tx_srcclk_out        => open,
      gtwiz_userclk_tx_usrclk_out        => open,
      gtwiz_userclk_tx_usrclk2_out(0)    => tx_usrclk,
      gtwiz_userclk_tx_active_out        => open,
      gtwiz_userclk_rx_reset_in          => (others => '1'),
      gtwiz_userclk_rx_srcclk_out        => open,
      gtwiz_userclk_rx_usrclk_out        => open,
      gtwiz_userclk_rx_usrclk2_out       => open,
      gtwiz_userclk_rx_active_out        => open,
      gtwiz_reset_clk_freerun_in(0)      => sysclk,
      gtwiz_reset_all_in(0)              => rst,
      gtwiz_reset_tx_pll_and_datapath_in => (others => '0'),
      gtwiz_reset_tx_datapath_in         => (others => '0'),
      gtwiz_reset_rx_pll_and_datapath_in => (others => '1'),
      gtwiz_reset_rx_datapath_in         => (others => '1'),
      gtwiz_reset_rx_cdr_stable_out      => open,
      gtwiz_reset_tx_done_out(0)         => tx_rstdone_single,
      gtwiz_reset_rx_done_out            => open,
      gtwiz_userdata_tx_in               => data_in,
      gtwiz_userdata_rx_out              => open,
      gtrefclk00_in(0)                   => refclk,
      qpll0lock_out(0)                   => qpll_lock,
      qpll0outclk_out                    => open,
      qpll0outrefclk_out                 => open,
      gthrxn_in                          => (others => '0'),
      gthrxp_in                          => (others => '0'),
      rxpd_in                            => (others => '1'),  -- RX part power-down
      txpd_in                            => (others => '0'),
      gthtxn_out                         => txn,
      gthtxp_out                         => txp,
      gtpowergood_out                    => open,
      rxpmaresetdone_out                 => open,
      txpmaresetdone_out                 => open
      );


end architecture rtl;
