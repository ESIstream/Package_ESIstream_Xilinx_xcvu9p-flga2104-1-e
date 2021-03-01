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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_dual_master_fsm is
  generic(
    FIFO_DATA_WIDTH : integer := 32
    );
  port (
    -- clock and reset
    clk                  : in  std_logic := 'X';
    refclk               : in  std_logic;
    refclk_re            : in  std_logic;
    refclk_fe            : in  std_logic;
    rst                  : in  std_logic := 'X';
    -- spi interface
    spi_ncs2             : out std_logic;
    spi_ncs1             : out std_logic;
    spi_sclk             : out std_logic;
    spi_mosi             : out std_logic;
    spi_miso             : in  std_logic;
    -- spi control
    spi_ss               : in  std_logic;  -- spi slave select spi_ncs1 when '0' else spi_ncs2.
    spi_start            : in  std_logic;  -- active high clk pulse to start sending spi commands.
    spi_busy             : out std_logic;
    -- fifo interface
    fifo_in_rd_en        : out std_logic;
    fifo_in_dout         : in  std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    fifo_in_empty        : in  std_logic;
    fifo_in_almost_empty : in  std_logic;
    fifo_out_wr_en       : out std_logic;
    fifo_out_din         : out std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    fifo_out_full        : in  std_logic
    );
end spi_dual_master_fsm;

architecture rtl of spi_dual_master_fsm is
  --
  constant SLAVE_AQ600            : std_logic                               := '0';
  constant SLAVE_LMX2592          : std_logic                               := '1';
  constant DATA_AQ600_WIDTH       : integer                                 := 16;
  constant DATA_LMX2592_WIDTH     : integer                                 := 24;
  constant DATA_WIDTH             : integer                                 := 24;  -- max(16 for aq600, 24 for LMX2592)
  signal data_load                : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  --
  type state_type is (st_idle, st_spi_ncs_low, st_spi_ncs_high, st_spi_wr, st_spi_pause);
  signal state, next_state        : state_type;
  --
  signal spi_busy_a, spi_busy_s   : std_logic                               := '0';
  signal spi_wr_a, spi_wr_s       : std_logic                               := '0';
  signal spi_pause_a, spi_pause_s : std_logic                               := '0';
  signal spi_ncs_a, spi_ncs_s     : std_logic                               := '0';
  signal spi_mosi_a, spi_mosi_s   : std_logic                               := '0';
  --
  signal spi_busy_d               : std_logic                               := '0';
  constant dcntr_width            : integer                                 := 8;
  signal dcntr                    : unsigned(dcntr_width-1 downto 0)        := (others => '0');
  constant dcntr_init1            : unsigned(dcntr_width-1 downto 0)        := to_unsigned(DATA_AQ600_WIDTH-1, dcntr'length);
  constant dcntr_init2            : unsigned(dcntr_width-1 downto 0)        := to_unsigned(DATA_LMX2592_WIDTH-1, dcntr'length);
  constant pcntr_width            : integer                                 := 4;
  signal dcntr_done               : std_logic                               := '0';
  signal pcntr                    : unsigned(pcntr_width-1 downto 0)        := to_unsigned(2**pcntr_width-1, pcntr_width);
  constant pcntr_init             : unsigned(pcntr_width-1 downto 0)        := to_unsigned(2**pcntr_width-1, pcntr'length);
  signal pcntr_done               : std_logic                               := '0';
  --signal spi_last_wr              : std_logic                               := '0';
  signal spi_start_m              : std_logic                               := '0';
  signal spi_ss_d                 : std_logic                               := '0';
  signal spi_sclk_o               : std_logic                               := '0';
  -- read processes:
  signal spi_rd_cmd               : std_logic                               := '0';
  signal spi_rd_data              : std_logic                               := '0';
  signal refclk_re_d1             : std_logic                               := '0';
  signal refclk_re_d2             : std_logic                               := '0';
  signal rd_data                  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  signal rd_data_done             : std_logic                               := '0';
begin

  p_start_memo : process (clk)
  begin
    if rising_edge(clk) then
      if spi_start_m = '1' and refclk_fe = '1' then
        spi_start_m <= '0';
      elsif spi_start = '1' and spi_busy_s = '0' then
        spi_start_m <= '1';
      else
        spi_start_m <= spi_start_m;
      end if;
    end if;
  end process;

  SYNC_PROC : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state       <= st_idle;
        spi_busy_s  <= '0';
        spi_ncs_s   <= '1';
        spi_wr_s    <= '0';
        spi_pause_s <= '1';
        spi_mosi_s  <= '0';
      else
        state       <= next_state;
        spi_busy_s  <= spi_busy_a;
        spi_ncs_s   <= spi_ncs_a;
        spi_wr_s    <= spi_wr_a;
        spi_pause_s <= spi_pause_a;
        spi_mosi_s  <= spi_mosi_a;
      end if;
    end if;
  end process;

  --MOORE State-Machine - Outputs based on state only
  OUTPUT_DECODE : process (state, data_load, dcntr, spi_ss)
  begin
    if state = st_idle then
      spi_busy_a  <= '0';
      spi_ncs_a   <= '1';
      spi_wr_a    <= '0';
      spi_pause_a <= '0';
      spi_mosi_a  <= '0';
    elsif state = st_spi_ncs_low then
      spi_busy_a  <= '1';
      spi_ncs_a   <= '0';
      spi_wr_a    <= '0';
      spi_pause_a <= '0';
      spi_mosi_a  <= data_load(to_integer(dcntr));
    elsif state = st_spi_wr then
      spi_busy_a  <= '1';
      spi_ncs_a   <= '0';
      spi_wr_a    <= '1';
      spi_pause_a <= '0';
      spi_mosi_a  <= data_load(to_integer(dcntr));
    elsif state = st_spi_ncs_high then
      spi_busy_a  <= '1';
      spi_ncs_a   <= '0';
      spi_wr_a    <= '0';
      spi_pause_a <= '0';
      spi_mosi_a  <= data_load(to_integer(dcntr));
    elsif state = st_spi_pause then
      spi_busy_a  <= '1';
      spi_ncs_a   <= spi_ss;
      spi_wr_a    <= '0';
      spi_pause_a <= '1';
      spi_mosi_a  <= data_load(to_integer(dcntr));
    else
      spi_busy_a  <= '1';
      spi_ncs_a   <= '1';
      spi_wr_a    <= '0';
      spi_pause_a <= '0';
      spi_mosi_a  <= '0';
    end if;
  end process;

  NEXT_STATE_DECODE : process (state, refclk_re, refclk_fe, spi_start_m, dcntr_done, pcntr_done, fifo_in_almost_empty)
  begin
    next_state <= state;

    case state is
      when st_idle =>
        if (refclk_fe = '1') and (spi_start_m = '1') then
          next_state <= st_spi_ncs_low;
        else
          next_state <= st_idle;
        end if;

      when st_spi_ncs_low =>
        next_state <= st_spi_wr;

      when st_spi_wr =>
        if (refclk_fe = '1') and (dcntr_done = '1') then
          next_state <= st_spi_ncs_high;
        else
          next_state <= st_spi_wr;
        end if;

      when st_spi_ncs_high =>
        if refclk_re = '1' and fifo_in_almost_empty = '1' then
          next_state <= st_idle;
        elsif refclk_re = '1' then
          next_state <= st_spi_pause;
        end if;

      when st_spi_pause =>
        if refclk_fe = '1' and pcntr_done = '1' then
          next_state <= st_spi_ncs_low;
        else
          next_state <= st_spi_pause;
        end if;

      when others =>
        next_state <= st_idle;

    end case;
  end process;

  --! spi port outputs
  p_spi_sclk : process (clk)
  begin
    if rising_edge(clk) then
      if spi_wr_s = '1' then
        spi_sclk_o <= refclk;
      else
        spi_sclk_o <= '0';
      end if;
    end if;
  end process;
  spi_sclk <= spi_sclk_o;
  spi_mosi <= spi_mosi_s;
  spi_ncs1 <= spi_ncs_s when spi_ss = SLAVE_AQ600   else '1';
  spi_ncs2 <= spi_ncs_s when spi_ss = SLAVE_LMX2592 else '1';
  spi_busy <= spi_busy_s;
  p_pcntr : process (clk)
  begin
    if rising_edge(clk) then
      if refclk_fe = '1' then
        if spi_pause_s = '1' then
          if pcntr = 0 then
            pcntr <= to_unsigned(0, pcntr'length);
          else
            pcntr <= pcntr - 1;
          end if;
        else
          pcntr <= pcntr_init;
        end if;
      else
        pcntr <= pcntr;
      end if;
    end if;
  end process;

  p_pcntr_done : process (clk)
  begin
    if rising_edge(clk) then
      if pcntr = 0 then
        pcntr_done <= '1';
      else
        pcntr_done <= '0';
      end if;
    end if;
  end process;

  p_dcntr : process (clk)
  begin
    if rising_edge(clk) then
      if refclk_fe = '1' then
        if spi_wr_s = '1' then
          if dcntr = 0 then
            dcntr <= to_unsigned(0, dcntr'length);
          else
            dcntr <= dcntr - 1;
          end if;
        elsif spi_ss = SLAVE_AQ600 then
          dcntr <= dcntr_init1;
        else
          dcntr <= dcntr_init2;
        end if;
      else
        dcntr <= dcntr;
      end if;
    end if;
  end process;

  p_dcntr_done : process (clk)
  begin
    if rising_edge(clk) then
      if dcntr = 0 then
        if refclk_re = '1' then
          dcntr_done <= '1';
        end if;
      else
        dcntr_done <= '0';
      end if;
    end if;
  end process;

  p_data_id : process (clk)
  begin
    if rising_edge(clk) then
      spi_busy_d <= spi_busy_s;
      if spi_busy_s = '1' and refclk_re = '1' then
        if pcntr = 7 then
          if fifo_in_almost_empty = '1' then
            fifo_in_rd_en <= '0';
          else
            fifo_in_rd_en <= '1';
          end if;
        else
          fifo_in_rd_en <= '0';
        end if;
      elsif spi_busy_s = '0' and spi_busy_d = '1' then
        fifo_in_rd_en <= '1';  -- unstack last word.
      else
        fifo_in_rd_en <= '0';
      end if;
    end if;
  end process;

  p_cmd_multiplexer : process (clk)
  begin
    if rising_edge(clk) then
      spi_ss_d <= spi_ss;
      if spi_ss_d = SLAVE_AQ600 then
        data_load(DATA_AQ600_WIDTH-1 downto 0) <= fifo_in_dout(DATA_AQ600_WIDTH-1 downto 0);
      else
        data_load(DATA_LMX2592_WIDTH-1 downto 0) <= fifo_in_dout(DATA_LMX2592_WIDTH-1 downto 0);
      end if;
    end if;
  end process;

  -- read processes:
  p_spi_ss_0 : process(clk)
  begin
    if rising_edge(clk) then
      if spi_ncs_s = '1' or spi_ss = '1' then
        spi_rd_cmd  <= '0';
        spi_rd_data <= '0';
      elsif spi_wr_s = '1' and dcntr = x"0F" and refclk_re = '1' then
        if spi_rd_cmd = '0' then
          if spi_mosi_s = '0' then -- read operation when 0 else write operation
            spi_rd_cmd  <= '1';
            spi_rd_data <= '0';
          else
            spi_rd_cmd  <= '0';
            spi_rd_data <= '0';
          end if;
        else
          spi_rd_cmd  <= '0';
          spi_rd_data <= '1';
        end if;
      end if;
    else
      spi_rd_cmd  <= spi_rd_cmd;
      spi_rd_data <= spi_rd_data;
    end if;
  end process;

  p_refclk_d : process(clk)
  begin
    if rising_edge(clk) then
      refclk_re_d1 <= refclk_re;
      refclk_re_d2 <= refclk_re_d1;
    end if;
  end process;

  p_rd_data : process(clk)
  begin
    if rising_edge(clk) then
      if spi_rd_data = '1' then
        if refclk_re_d2 = '1' and spi_sclk_o = '1' then
          rd_data(0)                     <= spi_miso;
          rd_data(DATA_WIDTH-1 downto 1) <= rd_data(DATA_WIDTH-2 downto 0);
          if dcntr = 0 then
            rd_data_done <= '1';
          else
            rd_data_done <= '0';
          end if;
        else
          rd_data_done <= '0';
        end if;
      else
        rd_data      <= (others => '0');
        rd_data_done <= '0';
      end if;
    end if;
  end process;

  fifo_out_din   <= rd_data;
  fifo_out_wr_en <= rd_data_done;
end rtl;
