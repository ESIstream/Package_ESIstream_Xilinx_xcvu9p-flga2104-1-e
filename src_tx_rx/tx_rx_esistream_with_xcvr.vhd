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
-- 2.2          2020            Teledyne e2v rx_frame_clk output from rx_xcvr_wrapper IBUSDS_GT ODIV2 - BUFG_GT
-------------------------------------------------------------------------------
-- Description :
-- For each lane, receives and deserializes data using a transceiver IP
-- from the differential serial link output (rx_n / rx_p). 
-- When DESER_WIDTH=32, Decodes 32-bits raw data (2x16-bits ESIstream encoded frame vector) to
-- provide decoded useful data 2x14-bits (data_out signal) and
-- related overhead clock bit and disparity bit (through frame_out)
-- when valid_out is high.
-- When DESER_WIDTH=64, Decodes 64-bits raw data (4x16-bits ESIstream encoded frame vector) to
-- provide decoded useful data 4x14-bits (data_out signal) and
-- related overhead clock bit and disparity bit (through frame_out)
-- when valid_out is high.
-------------------------------------------------------------------------------

library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tx_rx_esistream_with_xcvr is
  generic (
    NB_LANES : natural                       := 4;               -- number of lanes
    COMMA    : std_logic_vector(31 downto 0) := x"00FFFF00"      -- comma for frame alignemnent (0x00FFFF00 or 0xFF0000FF).
    );
  port (
    rst            : in  std_logic;                              -- active high reset
    sysclk         : in  std_logic;                              -- transceiver ip system clock
    refclk_n       : in  std_logic;                              -- transceiver ip reference clock p input 
    refclk_p       : in  std_logic;                              -- transceiver ip reference clock n input
    -- TX port
    txp            : out  std_logic_vector(NB_LANES-1 downto 0);  -- lane serial input p
    txn            : out  std_logic_vector(NB_LANES-1 downto 0);  -- lane Serial input n
    tx_sync_in     : in  std_logic;                              -- active high synchronization pulse input
    tx_prbs_en     : in  std_logic;                              -- active high scrambling processing enable input 
    tx_disp_en     : in  std_logic;                              -- active high disparity processing enable input
    tx_lfsr_init   : in  slv_17_array_n(NB_LANES-1 downto 0);    -- Select LFSR initialization value for each lanes.
    data_in        : in  tx_data_array(NB_LANES-1 downto 0);     -- data input to encode (13 downto 0)
    tx_ip_ready    : out std_logic;                              -- active high ip ready (transceiver pll locked and transceiver reset done)
    tx_frame_clk   : out std_logic;
    -- RX port
    rxp            : in  std_logic_vector(NB_LANES-1 downto 0);  -- lane serial input p
    rxn            : in  std_logic_vector(NB_LANES-1 downto 0);  -- lane Serial input n
    rx_sync_in     : in  std_logic;                              -- active high synchronization pulse input
    rx_prbs_en     : in  std_logic;                              -- active high scrambling enable input 
    rx_lanes_on    : in  std_logic_vector(NB_LANES-1 downto 0);  -- active high lanes enable input vector
    rx_data_en     : in  std_logic;                              -- active high output buffer read data enable input
    clk_acq        : in  std_logic;
    rx_frame_clk   : out std_logic;                              -- receive clock 
    rx_sync_out    : out std_logic;                              -- active high synchronization pulse ouput 
    frame_out      : out rx_frame_array(NB_LANES-1 downto 0);    -- decoded output frame: disparity bit (15) + clk bit (14) + data (13 downto 0) (descrambling and disparity processed)  
    valid_out      : out std_logic_vector(NB_LANES-1 downto 0);  -- active high data valid output
    rx_ip_ready    : out std_logic;                              -- active high ip ready output (transceiver pll locked and transceiver reset done)
    rx_lanes_ready : out std_logic                               -- active high lanes ready output, indicates all lanes are synchronized (alignement and prbs initialization done)
    );
end entity tx_rx_esistream_with_xcvr;

architecture rtl of tx_rx_esistream_with_xcvr is
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
  signal rx_usrclk     : std_logic                                         := '0';
  signal tx_usrclk     : std_logic                                         := '0';
  signal rx_rstdone    : std_logic_vector(NB_LANES-1 downto 0)             := (others => '0');
  signal tx_rstdone    : std_logic_vector(NB_LANES-1 downto 0)             := (others => '0');
  signal tx_rst_xcvr   : std_logic                                         := '0';  --_vector(NB_LANES-1 downto 0)             := (others => '0');
  signal rx_rst_xcvr   : std_logic                                         := '0';
  signal xcvr_pll_lock : std_logic_vector(NB_LANES-1 downto 0)             := (others => '0');
  signal xcvr_data_rx  : std_logic_vector(DESER_WIDTH*NB_LANES-1 downto 0) := (others => '0');
  signal xcvr_data_tx  : std_logic_vector(SER_WIDTH*NB_LANES-1 downto 0)   := (others => '0');
  signal tx_usrrdy     : std_logic_vector(NB_LANES-1 downto 0)             := (others => '0');

begin
  --============================================================================================================================
  -- Instantiate TX ESIstream module
  --============================================================================================================================
  tx_esistream_1 : entity work.tx_esistream
    generic map (
      NB_LANES => NB_LANES,
      COMMA    => COMMA)
    port map (
      rst_xcvr      => tx_rst_xcvr,
      tx_rstdone    => tx_rstdone,
      xcvr_pll_lock => xcvr_pll_lock,
      tx_usrclk     => tx_usrclk,
      xcvr_data_tx  => xcvr_data_tx,
      tx_usrrdy     => tx_usrrdy, -- ?
      sync_in       => tx_sync_in,
      prbs_en       => tx_prbs_en,
      disp_en       => tx_disp_en,
      lfsr_init     => tx_lfsr_init,
      data_in       => data_in,
      ip_ready      => tx_ip_ready);

  --============================================================================================================================
  -- Instantiate RX ESIstream module
  --============================================================================================================================
  rx_esistream : entity work.rx_esistream
    generic map(
      NB_LANES => NB_LANES,
      COMMA    => COMMA
      ) port map(
        rst_xcvr      => rx_rst_xcvr,
        rx_rstdone    => rx_rstdone,
        xcvr_pll_lock => xcvr_pll_lock,
        rx_usrclk     => rx_usrclk,
        xcvr_data_rx  => xcvr_data_rx,
        sync_in       => rx_sync_in,
        prbs_en       => rx_prbs_en,
        lanes_on      => rx_lanes_on,
        read_data_en  => rx_data_en,
        clk_acq       => clk_acq,
        sync_out      => rx_sync_out,
        frame_out     => frame_out,
        data_out      => open,
        valid_out     => valid_out,
        ip_ready      => rx_ip_ready,
        lanes_ready   => rx_lanes_ready
        );

  --============================================================================================================================
  -- Instantiate XCVR
  --============================================================================================================================
  tx_rx_xcvr_wrapper_1 : entity work.tx_rx_xcvr_wrapper
    generic map (
      NB_LANES => NB_LANES)
    port map (
      rst           => rst,
      rx_rst_xcvr   => rx_rst_xcvr,
      rx_rstdone    => rx_rstdone,
      rx_frame_clk  => rx_frame_clk,
      rx_usrclk     => rx_usrclk,
      tx_rst_xcvr   => tx_rst_xcvr,
      tx_usrrdy     => tx_usrrdy, 
      tx_rstdone    => tx_rstdone,
      tx_frame_clk  => tx_frame_clk,
      tx_usrclk     => tx_usrclk,
      sysclk        => sysclk,
      refclk_n      => refclk_n,
      refclk_p      => refclk_p,
      rxp           => rxp,
      rxn           => rxn,
      txp           => txp,
      txn           => txn,
      xcvr_pll_lock => xcvr_pll_lock,
      data_in       => xcvr_data_tx,
      data_out      => xcvr_data_rx);

end architecture rtl;
