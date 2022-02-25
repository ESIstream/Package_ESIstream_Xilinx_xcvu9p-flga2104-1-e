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
-- 2.0          2021            Teledyne e2v 
-------------------------------------------------------------------------------
library work;
use work.esistream_pkg.all;

library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;

entity rx_esistream_top is
  generic(
    GEN_ESISTREAM          : boolean                       := true;
    GEN_ILA                : boolean                       := true;
    GEN_GPIO               : boolean                       := false;
    NB_LANES               : integer                       := 8;
    RST_CNTR_INIT          : std_logic_vector(11 downto 0) := x"FFF";
    NB_CLK_CYC             : std_logic_vector(31 downto 0) := x"00FFFFFF";
    CLK_MHz                : real                          := 100.0;
    SPI_CLK_MHz            : real                          := 5.0;
    SYNCTRIG_PULSE_WIDTH   : integer                       := 7;
    SYNCTRIG_MAX_DELAY     : integer                       := 16;
    SYNCTRIG_COUNTER_WIDTH : integer                       := 8;
    FIFO_DATA_WIDTH        : integer                       := 24;
    FIFO_DEPTH             : integer                       := 8
    );
  port (
    -- dbg_sim          : in  std_logic;
    sso_n           : in    std_logic;                                                 -- mgtrefclk from transceiver clock input
    sso_p           : in    std_logic;                                                 -- mgtrefclk from transceiver clock input
    sso2_n          : in    std_logic;                                                 -- mgtrefclk from transceiver clock input
    sso2_p          : in    std_logic;                                                 -- mgtrefclk from transceiver clock input
    CLK_125MHZ_P    : in    std_logic;                                                 -- sysclk
    CLK_125MHZ_N    : in    std_logic;                                                 -- sysclk
    rxp             : in    std_logic_vector(NB_LANES-1 downto 0) := (others => '0');  -- lane serial input p
    rxn             : in    std_logic_vector(NB_LANES-1 downto 0) := (others => '0');  -- lane Serial input n
    -- FPGA Carrier board user interface signals
    gpio_dip_sw     : in    std_logic_vector(4 downto 1);
    gpio_led        : out   std_logic_vector(7 downto 0);
    gpio_sw_n       : in    std_logic;
    gpio_sw_w       : in    std_logic;
    gpio_sw_s       : in    std_logic;
    gpio_sw_e       : in    std_logic;
    gpio_sw_c       : in    std_logic;
    -- FMC EV12AQ600 signals
    m2c_cfg         : in    std_logic_vector(4 downto 1);
    c2m_led         : out   std_logic_vector(4 downto 1);
    spare_8_uart_tx : in    std_logic;                                                 -- CP2105 USB to UART output 
    spare_9_uart_rx : out   std_logic;                                                 -- CP2105 USB to UART input
    spare           : inout std_logic_vector(7 downto 1);
    fpga_ref_clk    : out   std_logic;
    ref_sel_ext     : out   std_logic;
    ref_sel         : out   std_logic;
    clk_sel         : out   std_logic;
    synco_sel       : out   std_logic;
    sync_sel        : out   std_logic;
    hmc1031_d1      : out   std_logic;
    hmc1031_d0      : out   std_logic;
    pll_muxout      : in    std_logic;
    clkoutB_p       : in    std_logic;
    clkoutB_n       : in    std_logic;
    rstn            : out   std_logic;
    adc_sclk        : out   std_logic;
    adc_cs_u        : out   std_logic;                                                 -- AD7708 spi_csn, temperature monitoring 
    adc_mosi        : out   std_logic;
    adc_miso        : in    std_logic;
    csn_pll         : out   std_logic;                                                 -- lmx2592   spi_csn
    sclk            : out   std_logic;                                                 -- ev12aq600  
    miso            : in    std_logic;                                                 -- ev12aq600
    mosi            : out   std_logic;
    csn             : out   std_logic;                                                 -- ev12aq600 spi_csn
    synctrig_p      : out   std_logic;
    synctrig_n      : out   std_logic;
    synco_p         : in    std_logic;
    synco_n         : in    std_logic
    );
end entity rx_esistream_top;

architecture rtl of rx_esistream_top is

  --------------------------------------------------------------------------------------------------------------------
  --! signal name description:
  -- _sr = _shift_register
  -- _re = _rising_edge (one clk period pulse generated on the rising edge of the initial signal)
  -- _fe = _falling_edge (one clk period pulse generated on the falling edge of the initial signal)
  -- _d  = _delay
  -- _2d = _delay x2 ( _d2 ) 
  -- _ba = _bitwise_and
  -- _sw = _slide_window
  -- _o  = _output
  -- _i  = _input
  -- _t  = _temporary or _tristate pin (OBUFT)
  -- _a  = _asychronous (fsm output decode signal)
  -- _s  = _synchronous (fsm synchronous output signal)
  -- _rs = _resynchronized (when there is a clock domain crossing)
  --------------------------------------------------------------------------------------------------------------------
  attribute keep                         : string;
  --constant NB_LANES             : natural                               := 8;
  constant ALL_LANES_ON                  : std_logic_vector(NB_LANES-1 downto 0) := (others => '1');
  constant ALL_LANES_OFF                 : std_logic_vector(NB_LANES-1 downto 0) := (others => '0');
  signal sysrst                          : std_logic                             := '0';
  signal sysclk                          : std_logic                             := '0';
  signal sysclk2                         : std_logic                             := '0';
  signal syslock                         : std_logic                             := '0';
  signal rx_clk                          : std_logic                             := '0';
  attribute keep of rx_clk               : signal is "true";
  signal tx_clk                          : std_logic                             := '0';
  attribute keep of tx_clk               : signal is "true";
  signal reg_rst                         : std_logic                             := '0';
  signal reg_rst_check                   : std_logic                             := '0';
  signal sw_rst                          : std_logic                             := '0';
  signal sw_rst_check                    : std_logic                             := '0';
  signal rst                             : std_logic                             := '0';
  signal rst_re                          : std_logic                             := '0';
  signal rst_check                       : std_logic                             := '0';
  signal rst_check_rs                    : std_logic                             := '0';
  signal rst_check_re                    : std_logic                             := '0';
  signal sync_in                         : std_logic                             := '0';
  signal sync_in_rs                      : std_logic                             := '0';
  signal sync_in_re                      : std_logic                             := '0';
  signal synctrig                        : std_logic                             := '0';
  signal synctrig_odelay                 : std_logic                             := '0';
  signal synctrig_re                     : std_logic                             := '0';
  signal rx_sync_in                      : std_logic                             := '0';
  signal rx_ip_ready                     : std_logic                             := '0';
  signal rx_lanes_on                     : std_logic_vector(NB_LANES-1 downto 0) := (others => '1');
  signal rx_lanes_ready                  : std_logic                             := '0';
  signal rx_release_data                 : std_logic                             := '0';
  signal rx_prbs_en                      : std_logic                             := '1';
  signal tx_emu_d_ctrl                   : std_logic_vector(1 downto 0)          := "00";
  signal dsw_tx_emu_d_ctrl               : std_logic_vector(1 downto 0)          := "00";
  signal dsw_prbs_en                     : std_logic                             := '1';
  signal dsw_manual_mode                 : std_logic                             := '0';
--
  signal spare_i                         : std_logic_vector(7 downto 1)          := (others => '0');
  signal spare_o                         : std_logic_vector(7 downto 1)          := (others => '0');
  signal spare_t                         : std_logic_vector(7 downto 1)          := (others => '0');
  --
  signal sync_set_odelay                 : std_logic                             := '0';
  signal sync_odelay_i                   : std_logic_vector(8 downto 0)          := (others => '0');
  signal sync_get_odelay                 : std_logic                             := '0';
  signal sync_odelay_o                   : std_logic_vector(8 downto 0)          := (others => '0');
  --
  signal fifo_dout                       : data_array(NB_LANES-1 downto 0);
  signal fifo_rd_en                      : std_logic_vector(NB_LANES-1 downto 0) := (others => '0');
  signal fifo_empty                      : std_logic_vector(NB_LANES-1 downto 0) := (others => '0');
  --
  signal be_status                       : std_logic                             := '0';
  signal cb_status                       : std_logic                             := '0';
  signal valid_status                    : std_logic                             := '0';
  --
  signal aq600_prbs_en                   : std_logic                             := '1';
  signal clk_acq                         : std_logic                             := '0';
  signal s_reset_i                       : std_logic                             := '0';
  signal s_resetn_i                      : std_logic                             := '0';
  signal s_resetn_re                     : std_logic                             := '0';
  signal rx_rst                          : std_logic                             := '0';
  signal rx_nrst                         : std_logic                             := '1';
  signal rx_sync_rst                     : std_logic                             := '0';
  signal rx_sync_rst_rs                  : std_logic                             := '0';
  signal rx_sync_rst_re                  : std_logic                             := '0';
  signal reg_aq600_rstn                  : std_logic;
  --
  type rx_data_array_12b is array (natural range <>) of slv_12_array_n(DESER_WIDTH/16-1 downto 0);
  signal data_out_12b                    : rx_data_array_12b(NB_LANES-1 downto 0);
  --
  signal frame_out                       : rx_frame_array(NB_LANES-1 downto 0);
  signal frame_out_d                     : rx_frame_array(NB_LANES-1 downto 0);
  signal valid_out                       : std_logic_vector(NB_LANES-1 downto 0) := (others => '0');
  --
  signal m_axi_addr                      : std_logic_vector(3 downto 0)          := (others => '0');
  signal m_axi_strb                      : std_logic_vector(3 downto 0)          := (others => '0');
  signal m_axi_wdata                     : std_logic_vector(31 downto 0)         := (others => '0');
  signal m_axi_rdata                     : std_logic_vector(31 downto 0)         := (others => '0');
  signal m_axi_wen                       : std_logic                             := '0';
  signal m_axi_ren                       : std_logic                             := '0';
  signal m_axi_busy                      : std_logic                             := '0';
  signal s_interrupt                     : std_logic                             := '0';
  --
  signal reg_0                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_1                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_2                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_3                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_4                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_5                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_6                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_7                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_8                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_9                           : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_10                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_11                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_12                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_13                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_14                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_15                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_16                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_17                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_18                          : std_logic_vector(31 downto 0)         := (others => '0');
  signal reg_19                          : std_logic_vector(31 downto 0)         := (others => '0');
  --
  signal spi_ncs1                        : std_logic                             := '1';
  signal spi_ncs2                        : std_logic                             := '1';
  signal spi_sclk                        : std_logic                             := '0';
  signal spi_mosi                        : std_logic                             := '0';
  signal spi_miso                        : std_logic                             := '0';
  signal spi_ss                          : std_logic;
  signal spi_start                       : std_logic;
  signal spi_start_re                    : std_logic;
  signal fifo_in_wr_en                   : std_logic;
  signal fifo_in_din                     : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
  signal fifo_in_full                    : std_logic;
  signal fifo_out_rd_en                  : std_logic;
  signal fifo_out_dout                   : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
  signal fifo_out_empty                  : std_logic;
--
  signal sync_rst                        : std_logic                             := '0';
  signal sync_delay                      : std_logic_vector(integer(floor(log2(real(SYNCTRIG_MAX_DELAY-1)))) downto 0);
  signal sync_mode                       : std_logic;
  signal sync_en                         : std_logic;
  signal sync_wr_en                      : std_logic;
  signal sync_wr_counter                 : std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0);
  signal sync_rd_counter                 : std_logic_vector(SYNCTRIG_COUNTER_WIDTH-1 downto 0);
  signal sync_counter_busy               : std_logic;
  signal sync_counter_busy_rs            : std_logic;
  signal send_sync                       : std_logic;
  signal send_sync_rs                    : std_logic;
  signal sync_wr_en_rs                   : std_logic;
  signal manual_mode                     : std_logic;
  signal manual_mode_rs                  : std_logic;
  --
  signal uart_ready                      : std_logic                             := '0';
  --
  signal reg_4_os                        : std_logic                             := '0';
  signal reg_5_os                        : std_logic                             := '0';
  signal reg_6_os                        : std_logic                             := '0';
  signal reg_7_os                        : std_logic                             := '0';
  signal reg_10_os                       : std_logic                             := '0';
  signal reg_12_os                       : std_logic                             := '0';
--
  attribute MARK_DEBUG                   : string;
  attribute MARK_DEBUG of rx_sync_in     : signal is "true";
  attribute MARK_DEBUG of rx_ip_ready    : signal is "true";
  attribute MARK_DEBUG of rx_lanes_ready : signal is "true";
  attribute MARK_DEBUG of cb_status      : signal is "true";
  attribute MARK_DEBUG of be_status      : signal is "true";
  attribute MARK_DEBUG of valid_status   : signal is "true";
  attribute MARK_DEBUG of data_out_12b   : signal is "true";
  attribute MARK_DEBUG of valid_out      : signal is "true";
--
begin
  --
  gpio_led <= (others => '0');
  --------------------------------------------------------------------------------------------
  -- User interface:
  --------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------
  --  clk_out1 : 100.0MHz (must be consistent with C_SYS_CLK_PERIOD)
  --------------------------------------------------------------------------------------------
  i_pll_sys : entity work.clk_wiz_0
    port map (
      -- Clock out ports  
      clk_out1  => sysclk,
      clk_out2  => sysclk2,
      -- Status and control signals                
      reset     => sysrst,
      locked    => syslock,
      -- Clock in ports
      clk_in1_p => CLK_125MHZ_P,
      clk_in1_n => CLK_125MHZ_N
      );

  sysreset_1 : entity work.sysreset
    generic map (
      RST_CNTR_INIT => RST_CNTR_INIT)
    port map (
      syslock => syslock,
      sysclk  => sysclk,
      reset   => s_reset_i,
      resetn  => s_resetn_i);

  -------------------------
  -------------------------
  gen_spare_iobuf : for idx in 1 to 7 generate
    spare_t <= "1111100";    -- 7: IN, 6:IN, 5:IN, 4: OUT, 3: OUT, 2: OUT, 1: OUT
    IOBUF_adx4_eeprom : IOBUF
      port map (
        O  => spare_o(idx),  -- 1-bit output: Buffer output
        I  => spare_i(idx),  -- 1-bit input: Buffer input
        IO => spare(idx),    -- 1-bit inout: Buffer inout (connect directly to top-level port)
        T  => spare_t(idx)   -- 1-bit input: 3-state enable input '1': IN, '0': OUT
        );
  end generate gen_spare_iobuf;
  -------------------------
  -- reset
  -------------------------
  rstn      <= reg_aq600_rstn;
  rst       <= sw_rst or reg_rst;
  rx_rst    <= rst_re or s_reset_i;
  rx_nrst   <= not rx_rst;
  rst_check <= sw_rst_check or reg_rst_check;

  gen_gpio_false_hdl : if GEN_GPIO = false generate
    -------------------------
    -- spare signals
    -------------------------
    dsw_tx_emu_d_ctrl(1) <= '0';
    dsw_tx_emu_d_ctrl(0) <= '0';
    dsw_prbs_en          <= '1';
    dsw_manual_mode      <= '0';
  end generate gen_gpio_false_hdl;

  gen_gpio_true_hdl : if GEN_GPIO = true generate
    -------------------------
    -- spare signals
    -------------------------
    dsw_tx_emu_d_ctrl(1) <= spare_o(7);        -- gpio_j20_14;  --dipswitch(2)
    dsw_tx_emu_d_ctrl(0) <= spare_o(6);        -- gpio_j20_12;  --dipswitch(3)
    dsw_prbs_en          <= spare_o(5);        -- gpio_j20_2;   --dipswitch(4)
    dsw_manual_mode      <= spare_o(4);
  end generate gen_gpio_true_hdl;
  -------------------------
  -- Switches
  -------------------------
  sw_rst       <= m2c_cfg(1);                  -- gpio_j20_10;  --SW_C 
  sync_in      <= m2c_cfg(2);                  -- gpio_j20_8;   --SW_S 
  sw_rst_check <= m2c_cfg(3);                  -- gpio_j20_6;   --SW_W 
  sysrst       <= m2c_cfg(4);                  -- gpio_j20_4;   --SW_N 
  --
  -- leds
  spare_i(1)   <= uart_ready;
  c2m_led(1)   <= rx_ip_ready;-- and pll_muxout;  --  and tx_ip_ready;
  c2m_led(2)   <= rx_lanes_ready;
  c2m_led(3)   <= cb_status;
  c2m_led(4)   <= be_status;
  spare_i(2)   <= valid_status;
  --------------------------------------------------------------------------------------------
  -- sysclk rising edge:
  --------------------------------------------------------------------------------------------
  risingedge_array_1 : entity work.risingedge_array
    generic map (
      D_WIDTH => 3)
    port map (
      rst   => s_reset_i,
      clk   => sysclk,
      d(0)  => rst,
      d(1)  => s_resetn_i,
      d(2)  => spi_start,
      re(0) => rst_re,
      re(1) => s_resetn_re,
      re(2) => spi_start_re);
  --------------------------------------------------------------------------------------------
  -- rx_clk rising edge from sysclk:
  --------------------------------------------------------------------------------------------

  ff_synchronizer_array_1 : entity work.ff_synchronizer_array
    generic map (
      REG_WIDTH => 6)
    port map (
      clk          => rx_clk,
      reg_async(0) => sync_in,
      reg_async(1) => rst_check,
      reg_async(2) => rx_sync_rst,
      reg_async(3) => send_sync,
      reg_async(4) => sync_wr_en,
      reg_async(5) => manual_mode,
      reg_sync(0)  => sync_in_rs,
      reg_sync(1)  => rst_check_rs,
      reg_sync(2)  => rx_sync_rst_rs,
      reg_sync(3)  => send_sync_rs,
      reg_sync(4)  => sync_wr_en_rs,
      reg_sync(5)  => manual_mode_rs);

  risingedge_array_2 : entity work.risingedge_array
    generic map (
      D_WIDTH => 3)
    port map (
      rst   => '0',
      clk   => rx_clk,
      d(0)  => sync_in_rs,
      d(1)  => rst_check_rs,
      d(2)  => rx_sync_rst_rs,
      re(0) => sync_in_re,
      re(1) => rst_check_re,
      re(2) => rx_sync_rst_re);
  --
  --------------------------------------------------------------------------------------------
  -- ESIstream RX IP
  --------------------------------------------------------------------------------------------
  gen_esistream_hdl : if GEN_ESISTREAM = true generate
    rx_esistream_inst : entity work.rx_esistream_with_xcvr
      generic map(
        NB_LANES => NB_LANES,
        COMMA    => x"FF0000FF"
        )
      port map(
        rst          => rx_rst,
        sysclk       => sysclk,
        refclk_n     => sso_n,
        refclk_p     => sso_p,
        refclk2_n    => sso2_n,
        refclk2_p    => sso2_p,
        rxn          => rxn,
        rxp          => rxp,
        sync_in      => rx_sync_in,
        prbs_en      => rx_prbs_en,
        lanes_on     => rx_lanes_on,
        read_data_en => rx_release_data,
        clk_acq      => rx_clk,
        rx_frame_clk => rx_clk,
        sync_out     => open,
        frame_out    => frame_out,
        valid_out    => valid_out,
        ip_ready     => rx_ip_ready,
        lanes_ready  => rx_lanes_ready
        );
  end generate gen_esistream_hdl;
  --------------------------------------------------------------------------------------------
  -- Received data check 
  --------------------------------------------------------------------------------------------
  -- Used for ILA only to display the ramp waveform using analog view in vivado simulator:
  lanes_assign : for i in 0 to NB_LANES-1 generate
    channel_assign : for j in 0 to DESER_WIDTH/16-1 generate
      process(rx_clk)
      begin
        if rising_edge(rx_clk) then
          -- to Integrated Logic Analyzer (ILA)
          data_out_12b(i)(j) <= frame_out(i)(j)(12-1 downto 0);  -- add pipeline to meet timing constraints
          -- to txrx_frame_checking
          frame_out_d(i)(j)  <= frame_out(i)(j);                 -- add pipeline to meet timing constraints
        end if;
      end process;
    end generate channel_assign;
  end generate lanes_assign;

  txrx_frame_checking_1 : entity work.txrx_frame_checking
    generic map (
      NB_LANES => NB_LANES)
    port map (
      rst          => rst_check_rs,
      clk          => rx_clk,
      d_ctrl       => tx_emu_d_ctrl,
      lanes_on     => rx_lanes_on,
      frame_out    => frame_out_d,
      valid_out    => valid_out,
      be_status    => be_status,
      cb_status    => cb_status,
      valid_status => valid_status);

  ---------------------------------
  -- Integrated Logic Analyzer:
  ---------------------------------
  g_ila : if GEN_ILA = true generate
    ila_wrapper_1 : entity work.ila_wrapper
      generic map (
        NB_LANES => NB_LANES)
      port map (
        clk            => rx_clk,
        rx_sync        => rx_sync_in,
        data_out_12b_0 => data_out_12b(0),
        data_out_12b_1 => data_out_12b(1),
        data_out_12b_2 => data_out_12b(2),
        data_out_12b_3 => data_out_12b(3),
        data_out_12b_4 => data_out_12b(4),
        data_out_12b_5 => data_out_12b(5),
        data_out_12b_6 => data_out_12b(6),
        data_out_12b_7 => data_out_12b(7));
  end generate g_ila;
  --

  --------------------------------------------------------------------------------------------
  -- SYNC generator and SYNC counter
  --------------------------------------------------------------------------------------------
  sync_generator_1 : entity work.sync_generator
    generic map (
      SYNCTRIG_PULSE_WIDTH   => SYNCTRIG_PULSE_WIDTH,
      SYNCTRIG_MAX_DELAY     => SYNCTRIG_MAX_DELAY,
      SYNCTRIG_COUNTER_WIDTH => SYNCTRIG_COUNTER_WIDTH)
    port map (
      clk          => rx_clk,
      rst          => rx_sync_rst_rs,
      sync_delay   => sync_delay,
      mode         => sync_mode,
      sync_en      => sync_en,
      lanes_ready  => rx_lanes_ready,
      release_data => rx_release_data,
      wr_en        => sync_wr_en,
      wr_counter   => sync_wr_counter,
      rd_counter   => sync_rd_counter,
      counter_busy => sync_counter_busy,
      manual_mode  => manual_mode_rs,
      send_sync    => send_sync,
      sw_sync      => sync_in_re,
      synctrig     => synctrig,
      synctrig_re  => synctrig_re);

  rx_sync_in <= synctrig_re;

  odelaye3_wrapper_1 : entity work.odelaye3_wrapper
    port map (
      clk         => sysclk,
      refclk      => sysclk2,
      rst         => s_reset_i,
      set_delay   => sync_set_odelay,  -- One sysclk clock cycle pulse.
      in_delay    => sync_odelay_i,
      get_delay   => sync_get_odelay,
      out_delay   => sync_odelay_o,
      sync        => synctrig,
      sync_odelay => synctrig_odelay);

  obufds_1 : OBUFDS
    port map (
      O  => synctrig_p,
      OB => synctrig_n,
      I  => synctrig_odelay
      );
  --------------------------------------------------------------------------------------------
  -- SPI Master, dual slave: EV12AQ600 & LMX2592
  --------------------------------------------------------------------------------------------
  -- SPI MUX to switch between EV12AQ60x ADC and PLL LMX2592:
  process(spi_ss, spi_sclk, spi_ncs1, spi_ncs2, spi_mosi, miso, adc_miso)
  begin
    if spi_ss = '0' then  -- AQ600
      sclk     <= spi_sclk;
      csn      <= spi_ncs1;
      mosi     <= spi_mosi;
      spi_miso <= miso;
      --
      adc_sclk <= '0';
      csn_pll  <= '1';
      adc_mosi <= '0';
      --spi_miso     <= adc_miso; -- not used
      --
      adc_cs_u <= '1';

    else  -- LMX
      sclk     <= '0';
      csn      <= '1';
      mosi     <= '0';
      -- spi_miso <= miso; -- not used
      --
      adc_sclk <= spi_sclk;
      csn_pll  <= spi_ncs2;
      adc_mosi <= spi_mosi;
      spi_miso <= adc_miso;
      --
      adc_cs_u <= '1';
    end if;
  end process;

  spi_dual_master_1 : entity work.spi_dual_master
    generic map (
      CLK_MHz         => CLK_MHz,
      SPI_CLK_MHz     => SPI_CLK_MHz,
      FIFO_DATA_WIDTH => FIFO_DATA_WIDTH,
      FIFO_DEPTH      => FIFO_DEPTH)
    port map (
      clk            => sysclk,
      rst            => s_reset_i,
      spi_ncs1       => spi_ncs1,         -- EV12AQ600
      spi_ncs2       => spi_ncs2,         -- LMX2592
      spi_sclk       => spi_sclk,
      spi_mosi       => spi_mosi,
      spi_miso       => spi_miso,
      spi_ss         => spi_ss,           -- from register '0': AQ600 ; '1' : LMX2592
      spi_start      => spi_start_re,     -- from register
      spi_busy       => open,
      fifo_in_wr_en  => fifo_in_wr_en,    -- from register
      fifo_in_din    => fifo_in_din,      -- from register
      fifo_in_full   => fifo_in_full,     -- to register
      fifo_out_rd_en => fifo_out_rd_en,   -- from register
      fifo_out_dout  => fifo_out_dout,    -- to register
      fifo_out_empty => fifo_out_empty);  -- from register

  --------------------------------------------------------------------------------------------
  -- UART 8 bit 115200 and Register map
  --------------------------------------------------------------------------------------------
  uart_wrapper_1 : entity work.uart_wrapper
    port map (
      clk         => sysclk,
      rstn        => s_resetn_i,
      m_axi_addr  => m_axi_addr,
      m_axi_strb  => m_axi_strb,
      m_axi_wdata => m_axi_wdata,
      m_axi_rdata => m_axi_rdata,
      m_axi_wen   => m_axi_wen,
      m_axi_ren   => m_axi_ren,
      m_axi_busy  => m_axi_busy,
      interrupt   => s_interrupt,
      tx          => spare_9_uart_rx,
      rx          => spare_8_uart_tx);

  register_map_1 : entity work.register_map
    generic map (
      CLK_FREQUENCY_HZ => 100000000,
      TIME_US          => 1000000)
    port map (
      clk          => sysclk,
      rstn         => s_resetn_i,
      interrupt_en => s_resetn_re,
      m_axi_addr   => m_axi_addr,
      m_axi_strb   => m_axi_strb,
      m_axi_wdata  => m_axi_wdata,
      m_axi_rdata  => m_axi_rdata,
      m_axi_wen    => m_axi_wen,
      m_axi_ren    => m_axi_ren,
      m_axi_busy   => m_axi_busy,
      interrupt    => s_interrupt,
      uart_ready   => uart_ready,
      reg_0        => reg_0,
      reg_1        => reg_1,
      reg_2        => reg_2,
      reg_3        => reg_3,
      reg_4        => reg_4,
      reg_5        => reg_5,
      reg_6        => reg_6,
      reg_7        => reg_7,
      reg_8        => reg_8,
      reg_9        => reg_9,
      reg_10       => reg_10,
      reg_11       => reg_11,
      reg_12       => reg_12,
      reg_13       => reg_13,
      reg_14       => reg_14,
      reg_15       => reg_15,
      reg_16       => reg_16,
      reg_17       => reg_17,
      reg_18       => reg_18,
      reg_19       => reg_19,
      reg_4_os     => reg_4_os,
      reg_5_os     => reg_5_os,
      reg_6_os     => reg_6_os,
      reg_7_os     => reg_7_os,
      reg_10_os    => reg_10_os,
      reg_12_os    => reg_12_os);

  tx_emu_d_ctrl(0)     <= reg_0(0) or dsw_tx_emu_d_ctrl(0);
  tx_emu_d_ctrl(1)     <= reg_0(1) or dsw_tx_emu_d_ctrl(1);
  --
  rx_prbs_en           <= reg_1(0) or dsw_prbs_en;
  --tx_prbs_en       <= reg_1(1) or dsw_prbs_en;
  --tx_disp_en       <= reg_1(2) or dsw_prbs_en;
  --
  reg_rst              <= reg_2(0);
  reg_rst_check        <= reg_2(1);
  reg_aq600_rstn       <= reg_2(2);
  rx_sync_rst          <= reg_2(3);
  --
  spi_ss               <= reg_3(0);
  spi_start            <= reg_3(1);
  --
  fifo_in_din          <= reg_4(23 downto 0);
  --
  sync_mode            <= reg_5(0);
  sync_delay           <= reg_5(7 downto 4);
  sync_en              <= reg_5_os;
  --
  send_sync            <= reg_6(0);
  manual_mode          <= reg_6(1) or dsw_manual_mode;
  --
  sync_wr_counter      <= reg_7(7 downto 0);
  sync_wr_en           <= reg_7(8);
  -- firmware version --
  reg_8                <= x"00000301";
  --
  reg_9(0)             <= fifo_in_full;
  reg_9(1)             <= fifo_out_empty;
  --
  reg_10(23 downto 0)  <= fifo_out_dout;
  --
  reg_11(7 downto 0)   <= sync_rd_counter;
  reg_11(8)            <= sync_counter_busy;
  reg_11(24 downto 16) <= sync_odelay_o;
  --
  sync_get_odelay      <= reg_12(15);
  sync_odelay_i        <= reg_12(8 downto 0);
  --
  fifo_in_wr_en        <= reg_4_os;
  fifo_out_rd_en       <= reg_10_os;
  sync_set_odelay      <= reg_12_os;
  ------------------------------------------------------------------------------------
  -- ref clk source switch:
  ------------------------------------------------------------------------------------
  -- | ref_sel_ext | ref clk source |
  -- | 1           | external       |
  -- | 0           | internal       | DEFAULT
  ref_sel_ext          <= reg_14(6);
  ------------------------------------------------------------------------------------
  -- external ref clk switch:
  ------------------------------------------------------------------------------------
  -- |ref_sel     | ref clk source               |
  -- | 1          | fpga_ref_clk                 |
  -- | 0          | external ref clk SMA EXT REF | DEFAULT
  ref_sel              <= reg_14(5);
  ------------------------------------------------------------------------------------
  -- EV12AQ60x CLK source switch:
  ------------------------------------------------------------------------------------
  -- |clk_sel      | ref clk source   |
  -- | 1           | PLL LMX2592      | 
  -- | 0           | external SMA     | DEFAULT 
  clk_sel              <= reg_14(4);
  ------------------------------------------------------------------------------------
  -- SYNCO multiplexer CBTL01023 SEL-input:
  ------------------------------------------------------------------------------------
  -- |synco_sel | synco fpga source   |
  -- | 1        | SYNCO external SMA  |
  -- | 0        | SYNCO ADC           | DEFAULT
  synco_sel            <= reg_14(3);
  ------------------------------------------------------------------------------------
  -- SYNC multiplexer CBTL01023 SEL-input:
  ------------------------------------------------------------------------------------
  -- |sync_sel    | sync adc source   |
  -- | 1          | SYNC external SMA |
  -- | 0          | SYNC FPGA         | DEFAULT
  sync_sel             <= reg_14(2);
  ------------------------------------------------------------------------------------
  -- Low jitter clock generation with integer N PLL:
  ------------------------------------------------------------------------------------
  -- | D0   | D1  | state  | ref clock frequency | PLL Division ratio |
  -- |  0   |  0  |  OFF   | N.A.                | Power-down         | DEFAULT
  -- |  1   |  0  |  ON    | 100 MHz             | Divide by 1        |
  -- |  0   |  1  |  ON    | 20 MHz              | Divide by 5        |
  -- |  1   |  1  |  ON    | 10 MHz              | Divide by 10       |
  hmc1031_d1           <= reg_14(1);
  hmc1031_d0           <= reg_14(0);
--  
end architecture rtl;
