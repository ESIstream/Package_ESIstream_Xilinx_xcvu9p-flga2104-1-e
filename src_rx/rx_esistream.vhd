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
-- 1.2          2020            Teledyne e2v Entity description   
-- 1.3          2021            teledyne e2v DESER_WIDTH 16-bit, 32-bit and 64-bit supported
-- 1.4          2021            teledyne e2v remove rx_control global rst
-------------------------------------------------------------------------------
-- Description :
-- rx_esistream manages control signals in rx_control:
-- -    reset of the transceiver (rst_xcvr).
-- -    reset of the lane decoding module (rst_esistream).
-- -    synchronization signal of the lane decoding module (sync_esistream). 
-- rx_esistream instantiates one rx_lane_decoding sub-module for each serial lane:
-- -    When DESER_WIDTH is 32, it decodes 32-bits of raw data (xcvr_data(index)) received from the transceiver at each clock period of the frame clock.
-- -    When DESER_WIDTH is 64, it decodes 64-bits of raw data (xcvr_data(index)) received from the transceiver at each clock period of the frame clock. 
-- -    index is the number of the lane.
-- rx_esistream generates lanes_ready signal using and bitwise operation on lane_ready logic vector. Each bit of the lane_ready vector is addressed by one lane_ready output of each rx_lane_decoding sub-module. When high, the lanes_ready signal indicates that all lanes are synchronized. 
-- 
-- For each lane, the rx_esistream module decodes received raw data from the transceiver IP. 
--      When DESER_WIDTH is 32, raw data contain unaligned 2 x 16-bits ESIstream encoded frame. 
--      When DESER_WIDTH is 64, raw data contain unaligned 4 x 16-bits ESIstream encoded frame. 
-- The rx_esistream modules provides valid decoded data on its outputs frame_out and data_out when valid_out is high.
-------------------------------------------------------------------------------

library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity rx_esistream is
  generic (
    NB_LANES : natural                       := 4;                          -- number of lanes
    COMMA    : std_logic_vector(31 downto 0) := x"00FFFF00"                 -- comma for frame alignemnent (0x00FFFF00 or 0xFF0000FF).
    );
  port (
    -- XCVR IF
    rst_xcvr      : out std_logic;                                          -- Reset of the XCVR
    rx_rstdone    : in  std_logic_vector(NB_LANES-1 downto 0);              -- Reset done of RX XCVR part
    xcvr_pll_lock : in  std_logic_vector(NB_LANES-1 downto 0);              -- PLL locked from XCVR part
    rx_usrclk     : in  std_logic;                                          -- RX User Clock from XCVR
    xcvr_data_rx  : in  std_logic_vector(DESER_WIDTH*NB_LANES-1 downto 0);  -- RX User data from RX XCVR part

    sync_in      : in  std_logic;                              -- active high synchronization pulse input
    prbs_en      : in  std_logic;                              -- active high scrambling enable input 
    lanes_on     : in  std_logic_vector(NB_LANES-1 downto 0);  -- active high lanes enable input vector
    read_data_en : in  std_logic;                              -- active high output buffer read data enable input
    clk_acq      : in  std_logic;                              -- acquisition clock, output buffer read port clock, should be same frequency and no phase drift with receive clock (default: clk_acq should take rx_clk).
    sync_out     : out std_logic := '0';                       -- active high synchronization pulse ouput 
    frame_out    : out rx_frame_array(NB_LANES-1 downto 0);    -- decoded output frame: disparity bit (15) + clk bit (14) + data (13 downto 0) (descrambling and disparity processed)  
    data_out     : out rx_data_array(NB_LANES-1 downto 0);     -- decoded output data: data (13 downto 0)(descrambling and disparity processed) 
    valid_out    : out std_logic_vector(NB_LANES-1 downto 0);  -- active high data valid output
    ip_ready     : out std_logic;                              -- active high ip ready output (transceiver pll locked and transceiver reset done)
    lanes_ready  : out std_logic                               -- active high lanes ready output, indicates all lanes are synchronized (alignement and prbs initialization done)
    );
end entity rx_esistream;

architecture rtl of rx_esistream is
  --============================================================================================================================
  -- Function and Procedure declarations
  --============================================================================================================================ 

  --============================================================================================================================
  -- Constant and Type declarations
  --============================================================================================================================
  constant DATA_LENGTH : integer := 14;
  constant LFSR_LENGTH : integer := 17;
  type slv_deser_width_array_n is array (natural range <>) of std_logic_vector(DESER_WIDTH-1 downto 0);

  --============================================================================================================================
  -- Component declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Signal declarations
  --============================================================================================================================
  signal lane_ready     : std_logic_vector(NB_LANES-1 downto 0)        := (others => '0');
  signal rst_esistream  : std_logic                                    := '0';
  signal sync_esistream : std_logic                                    := '0';
  signal xcvr_data      : slv_deser_width_array_n(NB_LANES-1 downto 0) := (others => (others => '0'));

begin

  --============================================================================================================================
  -- Instantiate RX Control module
  --============================================================================================================================
  i_rx_control : entity work.rx_control
    generic map(
      NB_LANES => NB_LANES
      )
    port map(
      clk_acq         => clk_acq,         -- clk_acq
      rx_usrclk       => rx_usrclk,       -- rx_usrclk
      pll_lock        => xcvr_pll_lock,
      rst_done        => rx_rstdone,
      sync_in         => sync_in,         -- clk_acq domain
      sync_esistream  => sync_esistream,  -- rx_usrclk domain
      rst_esistream   => rst_esistream,   -- rx_usrclk domain
      rst_transceiver => rst_xcvr,        -- rx_usrclk domain
      ip_ready        => ip_ready         -- rx_usrclk domain
      );

  sync_out <= sync_esistream;  -- rx_usrclk clock domain

  --============================================================================================================================
  -- Instantiate rx_lane_decoding
  --============================================================================================================================
  lane_decoding_gen : for index in 0 to (NB_LANES - 1) generate
  begin

    rx_lane_decoding_1 : entity work.rx_lane_decoding
      generic map (
        DATA_LENGTH => DATA_LENGTH,
        COMMA       => COMMA,
        LFSR_LENGTH => LFSR_LENGTH
        )
      port map (
        clk               => rx_usrclk,          -- rx_usrclk
        rst_esistream     => rst_esistream,      -- rx_usrclk domain
        sync_esistream    => sync_esistream,     -- rx_usrclk domain
        prbs_en           => prbs_en,            -- asynchronous domain
        lane_on           => lanes_on(index),    -- asynchronous domain
        clk_acq           => clk_acq,            -- clk_acq
        data_in           => xcvr_data(index),   -- rx_usrclk domain
        read_fifo         => read_data_en,       -- clk_acq domain
        lane_ready        => lane_ready(index),  -- clk_acq domain
        decoded_frame_out => frame_out(index),   -- clk_acq domain
        decoded_data_out  => data_out(index),    -- clk_acq domain
        decoded_valid_out => valid_out(index)    -- clk_acq domain
        );
  end generate;

  --============================================================================================================================
  -- Assignements output 
  --============================================================================================================================
  lanes_ready  <= and1(lane_ready);
  --============================================================================================================================
  -- Transceiver User interface
  --============================================================================================================================
  gen_xcvr_data : for idx in 0 to NB_LANES-1 generate
    xcvr_data(idx) <= xcvr_data_rx(DESER_WIDTH*idx + (DESER_WIDTH-1) downto DESER_WIDTH*idx + 0);  -- rx_usrclk domain
  end generate gen_xcvr_data;

end architecture rtl;
