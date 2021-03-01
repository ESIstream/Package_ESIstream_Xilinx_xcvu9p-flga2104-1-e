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
-- Description :
-- For each lane : 
-- When SER_WIDTH = 32 : Encodes useful data 2x14-bits (data_in signal) into a
--                       2x16-bits ESIstream frame vector (32-bits, data_encoded signal).
-- When SER_WIDTH = 64 : Encodes useful data 4x14-bits (data_in signal) into a
--                       4x16-bits ESIstream frame vector (64-bits, data_encoded signal). 
-- It serializes and transmits data using a transceiver IP on the
-- differential serial link output (tx_n / tx_p).
----------------------------------------------------------------------------------------------------
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;

entity tx_esistream is
  generic(
    NB_LANES : natural                       := 4;           -- number of lanes
    COMMA    : std_logic_vector(31 downto 0) := x"FF0000FF"  -- comma for frame alignemnent (0x00FFFF00 or 0xFF0000FF).
    );
  port (
    -- XCVR IF
    rst_xcvr      : out std_logic;                                        --_vector(NB_LANES-1 downto 0)                           -- Reset of the XCVR
    tx_rstdone    : in  std_logic_vector(NB_LANES-1 downto 0);            -- Reset done of TX XCVR part
    xcvr_pll_lock : in  std_logic_vector(NB_LANES-1 downto 0);            -- PLL locked from XCVR part
    tx_usrclk     : in  std_logic;                                        -- TX User Clock from XCVR
    xcvr_data_tx  : out std_logic_vector(SER_WIDTH*NB_LANES-1 downto 0);  -- TX User data from RX XCVR part

    tx_usrrdy : out std_logic_vector(NB_LANES-1 downto 0);  -- TX User Ready
    sync_in   : in  std_logic;                              -- active high synchronization pulse input
    prbs_en   : in  std_logic;                              -- active high scrambling processing enable input 
    disp_en   : in  std_logic;                              -- active high disparity processing enable input
    lfsr_init : in  slv_17_array_n(NB_LANES-1 downto 0);    -- Select LFSR initialization value for each lanes.
    data_in   : in  tx_data_array(NB_LANES-1 downto 0);     -- data input to encode (13 downto 0)
    ip_ready  : out std_logic                               -- active high ip ready (transceiver pll locked and transceiver reset done)
    );
end entity tx_esistream;

architecture rtl of tx_esistream is
  --============================================================================================================================
  -- Function and Procedure declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Constant and Type declarations
  --============================================================================================================================
  type slv_deser_width_array_n is array (natural range <>) of std_logic_vector(SER_WIDTH-1 downto 0);
  type taslv_16_array_n is array (natural range <>) of slv_16_array_n ((SER_WIDTH/16)-1 downto 0);

  --============================================================================================================================
  -- Component declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Signal declarations
  --============================================================================================================================   
  signal data_encoded : slv_deser_width_array_n(NB_LANES-1 downto 0) := (others => (others => '0'));

begin

  --============================================================================================================================
  -- TX Control module
  --============================================================================================================================
  i_tx_control : entity work.tx_control
    generic map(
      NB_LANES => NB_LANES
      ) port map (
        clk             => tx_usrclk,
        pll_lock        => xcvr_pll_lock,
        rst_done        => tx_rstdone,
        usrrdy          => tx_usrrdy,
        rst_transceiver => rst_xcvr,
        ip_ready        => ip_ready
        );

  --============================================================================================================================
  -- Encoding sub-module
  --============================================================================================================================
  gen_sub_encoding : for idx_lane in NB_LANES-1 downto 0 generate
    signal data_encoded_t : taslv_16_array_n(NB_LANES-1 downto 0);
  begin
    i_tx_encoding : entity work.tx_encoding
      generic map(
        COMMA => COMMA
        ) port map (
          clk       => tx_usrclk,
          nrst      => xcvr_pll_lock(idx_lane),
          sync      => sync_in,
          prbs_en   => prbs_en,
          disp_en   => disp_en,
          lfsr_init => lfsr_init(idx_lane),
          data_in   => data_in(idx_lane),
          data_out  => data_encoded_t(idx_lane)
          );

    gen_data_encoded : for idx in 0 to (SER_WIDTH/16)-1 generate
      data_encoded(idx_lane)(16*idx + 15 downto 16*idx + 00) <= data_encoded_t(idx_lane)(idx);
    end generate gen_data_encoded;

  end generate gen_sub_encoding;

  --============================================================================================================================
  -- Transceivers IP
  --============================================================================================================================
  gen_data_in : for idx in 0 to NB_LANES-1 generate
    xcvr_data_tx(SER_WIDTH*idx + (SER_WIDTH-1) downto SER_WIDTH*idx + 0) <= data_encoded(idx);
  end generate gen_data_in;


end architecture rtl;
