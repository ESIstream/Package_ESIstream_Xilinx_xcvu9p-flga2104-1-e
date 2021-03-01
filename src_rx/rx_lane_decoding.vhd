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
-- 1.1          2019            REFLEXCES    FPGA target migration, 64-bit data path
-- 1.2          2020            teledyne-e2v Remove process p_wr_fifo and rst_logic_3d signal
--                                           rst_logic_2d depends on lane_on state.
--                                           _esistream added to rst and sync inputs.
-- 1.3          2021            teledyne e2v DESER_WIDTH 16-bit, 32-bit and 64-bit supported
-------------------------------------------------------------------------------
-- Description :
-- When DESER_WIDTH = 32, Decodes useful data 2x14-bits, from a 2x16-bits ESIstream frame
-- vector (32-bits) from transceiver output according to the ESIstream
-- When DESER_WIDTH = 64, Decodes useful data 4x14-bits, from a 4x16-bits ESIstream frame
-- vector (64-bits) from transceiver output according to the ESIstream
-------------------------------------------------------------------------------
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity rx_lane_decoding is
  generic (
    DATA_LENGTH : integer                       := 14;                  -- useful data length in an ESIstream frame (16-bit) 
    COMMA       : std_logic_vector(31 downto 0) := X"00FFFF00";         -- COMMA for frame alignemnent / For ESIstream 32bits 0x00FFFF00 or 0xFF0000FF
    LFSR_LENGTH : integer                       := 17
    );
  port (
    clk               : in  std_logic;                                  -- receive clock (f_linerate/DESER_WIDTH)
    rst_esistream     : in  std_logic;                                  -- active high reset pulse 
    sync_esistream    : in  std_logic;                                  -- active high synchronization pulse, start ESIstream frame alignment and prbs initialization.
    prbs_en           : in  std_logic;                                  -- active high descrambling enable input
    lane_on           : in  std_logic;                                  -- active high lane enable input, when low lane ready output state is always high but no data can be read/write from/to output buffer ( decoded_valid_out state always low )
    clk_acq           : in  std_logic;                                  -- acquisition clock, output buffer read port clock, should be same frequency and no phase drift with receive clock (default: clk_acq should take rx_clk).
    data_in           : in  std_logic_vector(DESER_WIDTH-1 downto 0);   -- transceiver 32-bit raw data 
    read_fifo         : in  std_logic;                                  -- active high output buffer read data enable input
    lane_ready        : out std_logic;                                  -- active high lane ready output, indicates the lane is synchronized (alignement and prbs initialization done)
    decoded_frame_out : out slv_16_array_n(DESER_WIDTH/16-1 downto 0);  -- decoded output frame: disparity bit (15) + clk bit (14) + data (13 downto 0) (descrambling and disparity processed)  
    decoded_data_out  : out slv_14_array_n(DESER_WIDTH/16-1 downto 0);  -- decoded output data: data (13 downto 0)(descrambling and disparity processed)                        
    decoded_valid_out : out std_logic := '0'                            -- active high data valid output                                                        
    );
end entity rx_lane_decoding;

architecture rtl of rx_lane_decoding is
  --============================================================================================================================
  -- Function and Procedure declarations
  --============================================================================================================================
  function f_init_latency_decoding_rdy return natural is
    variable v_rtn : natural;
  begin
    if DESER_WIDTH = 64 then
      v_rtn := 7;
    elsif DESER_WIDTH = 32 then
      v_rtn := 15;
    else
      v_rtn := 31;
    end if;
    return v_rtn;
  end function f_init_latency_decoding_rdy;

  --============================================================================================================================
  -- Constant and Type declarations
  --============================================================================================================================

  --============================================================================================================================
  -- Signal declarations
  --============================================================================================================================
  signal aligned_data_rdy     : std_logic                                     := '0';
  signal align_busy           : std_logic                                     := '0';
  signal aligned_data         : slv_16_array_n(0 to DESER_WIDTH/16-1)         := (others => (others => '0'));
  --
  signal sync_d               : std_logic                                     := '0';
  signal rst_logic_2d         : std_logic                                     := '0';
  --
  signal init_lfsr            : std_logic                                     := '0';
  signal write_fifo           : std_logic                                     := '0';
  --
  signal scrambled_data       : slv_16_array_n(0 to (DESER_WIDTH/16)-1)       := (others => (others => '0'));
  signal scrambled_data_rdy   : std_logic                                     := '0';
  --                                                                          
  signal din_fifo             : slv_16_array_n(0 to (DESER_WIDTH/16)-1)       := (others => (others => '0'));
  signal descrambled_data     : slv_16_array_n(0 to (DESER_WIDTH/16)-1)       := (others => (others => '0'));
  signal descrambled_data_rdy : std_logic                                     := '0';
  signal prbs                 : slv_17_array_n(0 to (DESER_WIDTH/16)-1)       := (others => (others => '0'));
  signal fifo_empty           : std_logic_vector((DESER_WIDTH/16)-1 downto 0) := (others => '1');
  --
begin

  p_rst_fifo : process(clk)
  begin
    if rising_edge(clk) then
      sync_d       <= sync_esistream;
      rst_logic_2d <= sync_d or rst_esistream or (not lane_on);
    end if;
  end process;
  --============================================================================================================================
  -- Instantiate rx_frame_alignment module
  --============================================================================================================================
  i_rx_frame_alignment : entity work.rx_frame_alignment
    generic map (
      COMMA => COMMA
      ) port map (
        clk              => clk,
        sync             => sync_d,
        din              => data_in,
        align_busy       => open,
        aligned_data     => aligned_data,
        aligned_data_rdy => aligned_data_rdy
        );
  --============================================================================================================================
  -- Instantiate rx_lfsr_init module
  --============================================================================================================================
  i_rx_lfsr_init : entity work.rx_lfsr_init
    generic map (
      COMMA       => COMMA,
      LFSR_LENGTH => LFSR_LENGTH,
      DATA_LENGTH => DATA_LENGTH
      ) port map (
        clk      => clk,
        rst      => '0',
        din_rdy  => aligned_data_rdy,
        din      => aligned_data,
        dout_rdy => scrambled_data_rdy,
        prbs     => prbs,
        dout     => scrambled_data
        );
  --============================================================================================================================
  -- Instantiate rx_decoding module per DESER_WIDTH/16 - 1
  --============================================================================================================================  
  gen_rx_decoding : for idx in 0 to DESER_WIDTH/16 - 1 generate
    i_rx_decoding : entity work.rx_decoding
      port map(
        clk        => clk,
        data_in    => scrambled_data(idx),
        prbs_value => prbs(idx)(14-1 downto 0),
        prbs_en    => prbs_en,
        data_out   => descrambled_data(idx)
        );
  end generate gen_rx_decoding;

  delay_decoding_rdy : entity work.delay
    generic map (
      LATENCY     => f_init_latency_decoding_rdy
      ) port map (
        clk   => clk,
        rst   => rst_logic_2d,
        d     => scrambled_data_rdy,
        q     => descrambled_data_rdy
        );

  --============================================================================================================================
  -- Drive output buffer
  --============================================================================================================================
  write_fifo <= descrambled_data_rdy;
  din_fifo   <= descrambled_data;

  --============================================================================================================================
  -- Instantiate rx output buffer Wrapper
  --============================================================================================================================
  i_output_buffer : entity work.rx_output_buffer_wrapper
    generic map (DATA_LENGTH => DATA_LENGTH)
    port map(
      rst               => rst_logic_2d,
      wr_clk            => clk,
      rd_clk            => clk_acq,
      din               => din_fifo,
      wr_en             => write_fifo,
      rd_en             => read_fifo,
      empty             => fifo_empty,
      decoded_valid_out => decoded_valid_out,
      decoded_frame_out => decoded_frame_out,
      decoded_data_out  => decoded_data_out
      );
  --! @brief:
  --! fifo not empty indicates synchronized data are available at buffers outputs:
  lane_ready <= (not fifo_empty(fifo_empty'high));
end architecture rtl;
