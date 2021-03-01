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
use ieee.math_real.all;

--library UNISIM;
--use UNISIM.VComponents.all;

-------------------------------------------------------------------------------
--! @description: This module generates a synchronization pulse of width
-- SYNCTRIG_PULSE_WIDTH on synctrig output. Tiggered on send_sync input 
-- rising edge.
-- This module also triggers a counter on send sync input rising edge.
-- This counter offers to utilization mode, normal : 0 and training : 1.
-- - In normal mode the counter stops on end of counter value provided by wr_counter input.
-- - In training mode the counter stops when all lanes output buffer contain at least one valid data (when lanes_ready input is high).
--   Training mode end of counter value can be read on rd_counter ouput.
-------------------------------------------------------------------------------
entity sync_generator is
  generic (
    SYNCTRIG_PULSE_WIDTH   : integer := 4;
    SYNCTRIG_MAX_DELAY     : integer := 10;
    SYNCTRIG_COUNTER_WIDTH : integer := 8
    );
  port (
    clk          : in  std_logic;                                            -- frame clock, must be synchronous with converter master clk/sampling clk.
    rst          : in  std_logic;                                            -- active high asynchronous reset.
    sync_delay   : in  std_logic_vector(integer(floor(log2(real(SYNCTRIG_MAX_DELAY-1)))) downto 0);
    mode         : in  std_logic;                                            -- synchronization counter mode (normal: 0; training :1)
    sync_en      : in  std_logic;
    lanes_ready  : in  std_logic;                                            -- Indicates when all lanes contain at least one valid data. 
    release_data : out std_logic;
    wr_en        : in  std_logic;                                            -- Active high, allows to write a new wr_counter value.
    wr_counter   : in  std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0);  -- To write a new end of counter value, wr_en input must be high to allow write operation.
    rd_counter   : out std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0);  -- To check end of counter value
    counter_busy : out std_logic;                                            -- Active high, indicates counter is busy 
    manual_mode  : in  std_logic;
    send_sync    : in  std_logic;                                            -- from FPGA state machine
    sw_sync      : in  std_logic;                                            -- from user push-button or switch
    synctrig     : out std_logic;                                            -- converter synctrig signal 
    synctrig_re  : out std_logic                                             -- converter synctrig signal rising edge ( one clk period to logic high)
    );
end sync_generator;

architecture rtl of sync_generator is
  --------------------------------------------------------------------------------------------------------------------
  --! signal name description:
  -- _sr = _shift_register
  -- _re = _rising_edge (one clk period pulse generated on the rising edge of the initial signal)
  -- _d  = _delay
  -- _2d = _delay x2
  -- _ba = _bitwise_and
  -- _sw = _slide_window
  -- _m  = memorized
  -- _o  = _output
  -- _i  = _input
  -- _t  = _temporary (fsm signals)
  -- u_  = unsigned vector
  -- s_  = signed vector
  --------------------------------------------------------------------------------------------------------------------
  constant NORMAL         : std_logic                                                                   := '0';
  constant TRAINING       : std_logic                                                                   := '1';
  signal synctrig_o       : std_logic;
  signal wr_counter_m     : std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0)                         := std_logic_vector(to_unsigned(2**SYNCTRIG_COUNTER_WIDTH-1, SYNCTRIG_COUNTER_WIDTH));  -- default value : maximum value
  signal sync_delay_m     : std_logic_vector(integer(floor(log2(real(SYNCTRIG_MAX_DELAY-1)))) downto 0) := (others => '0');
  signal sync_mode_m      : std_logic                                                                   := TRAINING;                                                      --TRAINING;
  --
  constant U_COUNTER_MAX  : unsigned(SYNCTRIG_COUNTER_WIDTH-1 downto 0)                                 := (others => '1');
  signal u_counter        : unsigned(SYNCTRIG_COUNTER_WIDTH-1 downto 0)                                 := U_COUNTER_MAX;
  constant cntr_msb       : integer                                                                     := integer(floor(log2(real(SYNCTRIG_PULSE_WIDTH))))+1;
  signal cntr             : unsigned(cntr_msb downto 0)                                                 := (others => '0');
  --
  signal send_sync_re     : std_logic                                                                   := '0';
  signal wr_en_re         : std_logic                                                                   := '0';
  signal lanes_ready_d    : std_logic                                                                   := '0';
  signal synctrig_re_o    : std_logic                                                                   := '0';
  signal release_data_n_o : std_logic                                                                   := '0';
  signal rd_counter_n_o   : std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0)                         := (others => '0');
  signal release_data_t_o : std_logic                                                                   := '0';
  signal rd_counter_t_o   : std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0)                         := (others => '0');
  signal counter_busy_o   : std_logic                                                                   := '0';
--
begin

  risingedge_1 : entity work.risingedge
    port map (
      rst => rst,
      clk => clk,
      d   => send_sync,
      re  => send_sync_re);

  risingedge_2 : entity work.risingedge
    port map (
      rst => rst,
      clk => clk,
      d   => wr_en,
      re  => wr_en_re);

  p_sync_generator : process (clk)
  begin
    if rising_edge (clk) then
      if rst = '1' then
        cntr          <= (others => '0');
        synctrig_o    <= '0';
        synctrig_re_o <= '0';
      else
        if send_sync_re = '1' or sw_sync = '1' then
          synctrig_re_o <= '1';
          cntr          <= to_unsigned(SYNCTRIG_PULSE_WIDTH, cntr'length);
          synctrig_o    <= '1';
        elsif cntr = 0 then
          synctrig_re_o <= '0';
          synctrig_o    <= '0';
          cntr          <= cntr;
        elsif manual_mode = '1' then
          synctrig_re_o <= '0';
          synctrig_o    <= '1';
          cntr          <= cntr;
        else
          synctrig_re_o <= '0';
          cntr          <= cntr - 1;
          synctrig_o    <= synctrig_o;
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge (clk) then
      synctrig_re   <= synctrig_re_o;  -- also starts sync counter.
      lanes_ready_d <= lanes_ready;
    end if;
  end process;

  delay_prog_1 : entity work.delay_prog
    generic map (
      LATENCY => SYNCTRIG_MAX_DELAY)
    port map (
      clk => clk,
      rst => rst,
      lat => sync_delay_m,
      d   => synctrig_o,
      q   => synctrig);

  p_sync_counter : process(clk)
  begin
    if rising_edge(clk) then
      if synctrig_re_o = '1' then
        u_counter      <= (others => '0');
        counter_busy_o <= '1';
      elsif counter_busy_o = '1' then
        if u_counter = unsigned(wr_counter_m) then  -- default wr_counter_m = U_COUNTER_MAX
          u_counter      <= u_counter;
          counter_busy_o <= '0';
        else
          u_counter      <= u_counter+1;
          counter_busy_o <= '1';
        end if;
      end if;
    end if;
  end process;

  counter_busy <= counter_busy_o;

  -- sync counter default mode is TRAINING.
  rd_counter_normal_p : process(clk)
  begin
    if rising_edge(clk) then
      if synctrig_re_o = '1' then
        release_data_n_o <= '0';
        rd_counter_n_o   <= (others => '0');
      elsif (lanes_ready = '1' and counter_busy_o = '0') then
        release_data_n_o <= '1';
        rd_counter_n_o   <= std_logic_vector(u_counter);
      end if;
    end if;
  end process;

  rd_counter_training_p : process(clk)
  begin
    if rising_edge(clk) then
      if synctrig_re_o = '1' then
        release_data_t_o <= '0';
        rd_counter_t_o   <= (others => '0');
      elsif (lanes_ready_d = '0' and lanes_ready = '1') then
        release_data_t_o <= '1';
        rd_counter_t_o   <= std_logic_vector(u_counter);
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if sync_mode_m = NORMAL then
        release_data <= release_data_n_o;
        rd_counter   <= rd_counter_n_o;
      else
        release_data <= release_data_t_o;
        rd_counter   <= rd_counter_t_o;
      end if;
    end if;
  end process;


  wr_counter_p : process(clk)
  begin
    if rising_edge(clk) then
      if wr_en_re = '1' then
        wr_counter_m <= wr_counter;
      end if;
    end if;
  end process;

  wr_sync_cfg_p : process(clk)
  begin
    if rising_edge(clk) then
      if sync_en = '1' then
        sync_delay_m <= sync_delay;
        sync_mode_m  <= mode;
      end if;
    end if;
  end process;
end architecture rtl;
