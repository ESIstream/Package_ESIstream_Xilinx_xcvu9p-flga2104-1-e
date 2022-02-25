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

library work;
use work.esistream_pkg.all;
use work.tb_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library STD;
use STD.textio.all;

library unisim;
use unisim.vcomponents.all;

entity tb_rx_esistream_top is
end entity tb_rx_esistream_top;

architecture behavioral of tb_rx_esistream_top is
---------------- Constants ----------------
  constant GEN_ESISTREAM       : boolean                               := true;
  constant GEN_ILA             : boolean                               := false;
  constant GEN_GPIO            : boolean                               := true;
  constant NB_LANES            : natural                               := 8;
  constant COMMA               : std_logic_vector(31 downto 0)         := x"FF0000FF";
  signal sso_p                 : std_logic                             := '0';
  signal sso_n                 : std_logic                             := '1';
  signal CLK_125MHZ_P          : std_logic                             := '0';
  signal CLK_125MHZ_N          : std_logic                             := '1';
  signal clk_100               : std_logic                             := '0';
  --
  signal tb_uart_ready         : std_logic                             := '0';
  signal tb_sync_in            : std_logic                             := '0';
  signal tb_ip_ready           : std_logic                             := '0';
  signal tb_lanes_ready        : std_logic                             := '0';
  signal tb_isrunning          : std_logic                             := '0';
  signal tb_be_status          : std_logic                             := '0';
  signal tb_cb_status          : std_logic                             := '0';
  signal tb_valid_status       : std_logic                             := '0';
  --
  signal tx_ip_ready           : std_logic                             := '0';
  signal rx_ip_ready           : std_logic                             := '0';
  signal ip_ready              : std_logic                             := '0';
  signal tx_d_ctrl             : std_logic_vector(1 downto 0)          := (others => '0');
  signal rx_prbs_en            : std_logic                             := '0';
  signal tx_prbs_en            : std_logic                             := '0';
  signal tx_disp_en            : std_logic                             := '0';
  signal tx_lss                : std_logic                             := '0';
  signal sync                  : std_logic                             := '0';
  signal rst                   : std_logic                             := '0';
  signal rstn                  : std_logic                             := '0';
  signal rst_check             : std_logic                             := '0';
  signal sysrst                : std_logic                             := '0';
  --
  signal m2c_cfg               : std_logic_vector(4 downto 1)          := (others => '0');
  signal c2m_led               : std_logic_vector(4 downto 1)          := (others => '0');
  -- signal spare_8_uart_tx       : std_logic := '0';
  -- signal spare_9_uart_rx       : std_logic := '0';
  signal spare                 : std_logic_vector(7 downto 1)          := (others => '0');
  signal fpga_ref_clk          : std_logic                             := '0';
  signal ref_sel_ext           : std_logic                             := '0';
  signal ref_sel               : std_logic                             := '0';
  signal clk_sel               : std_logic                             := '0';
  signal synco_sel             : std_logic                             := '0';
  signal sync_sel              : std_logic                             := '0';
  signal hmc1031_d1            : std_logic                             := '0';
  signal hmc1031_d0            : std_logic                             := '0';
  signal pll_muxout            : std_logic                             := '1';
  signal clkoutB_p             : std_logic                             := '0';
  signal clkoutB_n             : std_logic                             := '0';
  signal ev12aq600_rstn        : std_logic                             := '0';
  signal adc_sclk              : std_logic                             := '0';
  signal adc_cs_u              : std_logic                             := '0';
  signal adc_mosi              : std_logic                             := '0';
  signal adc_miso              : std_logic                             := '0';
  signal csn_pll               : std_logic                             := '0';
  signal sclk                  : std_logic                             := '0';
  signal miso                  : std_logic                             := '0';
  signal mosi                  : std_logic                             := '0';
  signal csn                   : std_logic                             := '0';
  signal synctrig_p            : std_logic                             := '0';
  signal synctrig_n            : std_logic                             := '0';
  signal synco_p               : std_logic                             := '0';
  signal synco_n               : std_logic                             := '0';
--
  signal lfsr_init             : slv_17_array_n(NB_LANES-1 downto 0)   := (others => (others => '1'));
  signal clk_bit               : std_logic                             := '0';
  signal tx_clk                : std_logic                             := '0';
  signal txp                   : std_logic_vector(NB_LANES-1 downto 0) := (others => '0');
  signal txn                   : std_logic_vector(NB_LANES-1 downto 0) := (others => '1');
  constant NB_CLK_CYC          : std_logic_vector(31 downto 0)         := (others => '0');
  constant RST_CNTR_INIT       : std_logic_vector(11 downto 0)         := (others => '0');
  signal uart_tx               : std_logic                             := '0';
  signal uart_rx               : std_logic                             := '0';
  --
  -- -- UART IP constants:
  constant ADDR_RX_FIFO        : std_logic_vector(3 downto 0)          := x"0";
  constant ADDR_TX_FIFO        : std_logic_vector(3 downto 0)          := x"4";
  constant ADDR_STAT           : std_logic_vector(3 downto 0)          := x"8";
  constant ADDR_CTRL           : std_logic_vector(3 downto 0)          := x"C";
  --
  signal m1_axi_addr           : std_logic_vector(3 downto 0)          := (others => '0');
  signal m1_axi_strb           : std_logic_vector(3 downto 0)          := (others => '0');
  signal m1_axi_wdata          : std_logic_vector(31 downto 0)         := (others => '0');
  signal m1_axi_rdata          : std_logic_vector(31 downto 0)         := (others => '0');
  signal m1_axi_wen            : std_logic                             := '0';
  signal m1_axi_ren            : std_logic                             := '0';
  signal m1_axi_busy           : std_logic                             := '0';
  signal s1_interrupt          : std_logic                             := '0';
  --
  signal reg3                  : std_logic_vector(7 downto 0)          := (others => '0');
  constant SPI_START_ENABLE    : std_logic_vector(7 downto 0)          := x"02";
  constant SPI_START_DISABLE   : std_logic_vector(7 downto 0)          := x"FD";
  constant SPI_SS_EXTERNAL_PLL : std_logic_vector(7 downto 0)          := x"01";
  constant SPI_SS_EV12AQ600    : std_logic_vector(7 downto 0)          := x"00";
  --
  signal manual_mode           : std_logic                             := '0';
  --
  signal spare_0               : std_logic                             := '0';
  --
  signal gpio_dip_sw           : std_logic_vector(4 downto 1) := (others => '0');
  signal gpio_led              : std_logic_vector(7 downto 0) := (others => '0');
  signal gpio_sw_n             : std_logic := '0';
  signal gpio_sw_w             : std_logic := '0';
  signal gpio_sw_s             : std_logic := '0';
  signal gpio_sw_e             : std_logic := '0';
  signal gpio_sw_c             : std_logic := '0';                                               
  --
begin
--
--############################################################################################################################
--############################################################################################################################
-- Clock Generation
--############################################################################################################################
--############################################################################################################################
  CLK_125MHZ_P <= not CLK_125MHZ_P after 4 ns;  -- PL system clock for registers map, UART communication with computer...
  CLK_125MHZ_N <= not CLK_125MHZ_N after 4 ns;
  --
  clk_100      <= not clk_100      after 5 ns;    -- clock for UART testbench module used to simulate the computer.
  --
--############################################################################################################################
--############################################################################################################################
-- Unit under test
--############################################################################################################################
--############################################################################################################################   
  rx_esistream_top_1 : entity work.rx_esistream_top
    generic map (
      GEN_ESISTREAM          => GEN_ESISTREAM,
      GEN_ILA                => GEN_ILA,
      GEN_GPIO               => GEN_GPIO,
      NB_LANES               => NB_LANES,
      RST_CNTR_INIT          => RST_CNTR_INIT,
      NB_CLK_CYC             => NB_CLK_CYC,
      CLK_MHz                => 100.0,
      SPI_CLK_MHz            => 10.0,
      SYNCTRIG_PULSE_WIDTH   => 7,
      SYNCTRIG_MAX_DELAY     => 10,
      SYNCTRIG_COUNTER_WIDTH => 8,
      FIFO_DATA_WIDTH        => 24,
      FIFO_DEPTH             => 8)
    port map (
      sso_n           => sso_n,
      sso_p           => sso_p,
      sso2_n          => sso_n,
      sso2_p          => sso_p,
      CLK_125MHZ_P    => CLK_125MHZ_P,
      CLK_125MHZ_N    => CLK_125MHZ_N,
      rxp             => txp,
      rxn             => txn,
      gpio_dip_sw     => gpio_dip_sw,
      gpio_led        => gpio_led,   
      gpio_sw_n       => gpio_sw_n,  
      gpio_sw_w       => gpio_sw_w,  
      gpio_sw_s       => gpio_sw_s,  
      gpio_sw_e       => gpio_sw_e,  
      gpio_sw_c       => gpio_sw_c,      
      m2c_cfg         => m2c_cfg,
      c2m_led         => c2m_led,
      spare_8_uart_tx => uart_tx,
      spare_9_uart_rx => uart_rx,
      spare           => spare,
      fpga_ref_clk    => fpga_ref_clk,
      ref_sel_ext     => ref_sel_ext,
      ref_sel         => ref_sel,
      clk_sel         => clk_sel,
      synco_sel       => synco_sel,
      sync_sel        => sync_sel,
      hmc1031_d1      => hmc1031_d1,
      hmc1031_d0      => hmc1031_d0,
      pll_muxout      => pll_muxout,
      clkoutB_p       => clkoutB_p,
      clkoutB_n       => clkoutB_n,
      rstn            => ev12aq600_rstn,
      adc_sclk        => adc_sclk,
      adc_cs_u        => adc_cs_u,
      adc_mosi        => adc_mosi,
      adc_miso        => adc_miso,
      csn_pll         => csn_pll,
      sclk            => sclk,
      miso            => miso,
      mosi            => mosi,
      csn             => csn,
      synctrig_p      => synctrig_p,
      synctrig_n      => synctrig_n,
      synco_p         => synco_p,
      synco_n         => synco_n);

  -- --
  spare(7)        <= tx_d_ctrl(1);
  spare(6)        <= tx_d_ctrl(0);
  spare(5)        <= rx_prbs_en;
  spare(4)        <= manual_mode;
  spare(3)        <= '0';
  m2c_cfg(1)      <= rst;
  m2c_cfg(2)      <= sync;
  m2c_cfg(3)      <= rst_check;
  m2c_cfg(4)      <= sysrst;
  -- --             
  tb_uart_ready   <= spare(1);
  tb_ip_ready     <= c2m_led(1);
  tb_lanes_ready  <= c2m_led(2);
  tb_cb_status    <= c2m_led(3);
  tb_be_status    <= c2m_led(4);
  tb_valid_status <= spare(2);
  --                
  rx_ip_ready     <= tb_ip_ready;
  ip_ready        <= tx_ip_ready and rx_ip_ready;
--============================================================================================================================
-- Stimulus
--============================================================================================================================
  my_tb : process
    -- 
    procedure axi4_lite_write
      (
        signal clk         : in  std_logic;
        constant addr      : in  std_logic_vector;
        constant data      : in  std_logic_vector;
        signal m_axi_addr  : out std_logic_vector;
        signal m_axi_strb  : out std_logic_vector;
        signal m_axi_wdata : out std_logic_vector;
        signal m_axi_wen   : out std_logic;
        signal m_axi_busy  : in  std_logic) is
    begin
      wait until rising_edge(clk);
      m_axi_addr  <= addr;
      m_axi_strb  <= "0001";
      m_axi_wdata <= x"000000"&data;
      m_axi_wen   <= '1';
      wait until rising_edge(clk);
      m_axi_wen   <= '0';
      wait until falling_edge(m_axi_busy);
    end axi4_lite_write;
    --
    procedure axi4_lite_read(
      signal clk         : in  std_logic;
      constant addr      : in  std_logic_vector;
      signal rdata       : out std_logic_vector;
      signal m_axi_addr  : out std_logic_vector;
      signal m_axi_rdata : in  std_logic_vector;
      signal m_axi_ren   : out std_logic;
      signal m_axi_busy  : in  std_logic) is
    begin
      wait until rising_edge(clk);
      m_axi_addr <= addr;
      m_axi_ren  <= '1';
      wait until rising_edge(clk);
      m_axi_ren  <= '0';
      wait until falling_edge(m_axi_busy);
      rdata      <= m_axi_rdata;
    end axi4_lite_read;
    --
    procedure write_log(
      signal clk       : in std_logic;
      signal cb_status : in std_logic;
      signal be_status : in std_logic) is
      file logfile     : text;
      variable fstatus : file_open_status;
      variable result  : std_logic_vector(1 downto 0);
      variable buf     : line;
    begin
      --
      result := cb_status & be_status;
      --
      --file_open(fstatus, logfile, "log.txt", write_mode);
      file_open(fstatus, logfile, "c:\vw\xilinx_ku040\tb_log.txt", append_mode);
      L1 : write(buf, string'("tb result: [cb_status & be_status] = ["));
      L2 : write(buf, to_bitvector(result));
      L3 : write(buf, string'("] "));
      L4 : writeline(logfile, buf);
      file_close(logfile);
    end write_log;
    --
    procedure send_sync_manual(
      signal clk          : in  std_logic;
      signal lanes_ready  : in  std_logic;
      signal valid_status : in  std_logic;
      signal sync         : out std_logic;
      signal manual_mode  : out std_logic) is
    begin
      wait until rising_edge(clk);
      manual_mode <= '1';
      report "manual mode 1...";
      wait until rising_edge(clk);
      sync        <= '1';
      wait until rising_edge(clk);
      sync        <= '0';
      report "sync sent...";
      wait for 500 ns;
      wait until rising_edge(clk);
      manual_mode <= '0';
      report "manual mode 0...";
      report "wait lanes_ready";
      wait until rising_edge(lanes_ready);
      report "lanes ready...";
      report "wait valid_status";
      wait until rising_edge(valid_status);
      report "valid status...";
    end send_sync_manual;
    --
    procedure send_sync(
      signal clk          : in  std_logic;
      signal lanes_ready  : in  std_logic;
      signal valid_status : in  std_logic;
      signal sync         : out std_logic;
      signal manual_mode  : out std_logic) is
    begin
      wait until rising_edge(clk);
      sync        <= '1';
      wait until rising_edge(clk);
      sync        <= '0';
      report "sync sent...";
      report "wait lanes_ready";
      wait until rising_edge(lanes_ready);
      report "lanes ready...";
      report "wait valid_status";
      wait until rising_edge(valid_status);
      report "valid status...";
    end send_sync;
    --
  begin
    -------------------------------- 
    -- tb start
    --------------------------------
    sysrst      <= '1';
    rst         <= '1';
    rst_check   <= '1';
    rx_prbs_en  <= '1';
    tx_prbs_en  <= '1';
    tx_disp_en  <= '1';
    tx_d_ctrl   <= "01";                                                                                            -- [00: all x"000"; 11: all x"FFF" else ramp mode]
    reg3        <= SPI_SS_EV12AQ600;
    --reg3     <= SPI_SS_EXTERNAL_PLL;
    sync        <= '0';
    manual_mode <= '0';
    wait for 100 ns;
    sysrst      <= '0';
    wait for 100 ns;
    rst_check   <= '0';
    wait for 100 ns;
    rst         <= '0';
    report "release reset...";
    report "start testbench...";
    ----------------------------------------------------------------------------------------------------
    -- TEST 1: 
    ----------------------------------------------------------------------------------------------------
    if GEN_ESISTREAM then
      report "test 1...";
      wait for 1000 ns;
      wait until rising_edge(clk_100);
      rst <= '1';
      wait until rising_edge(clk_100);
      rst <= '0';
      --
      wait until rising_edge(tb_ip_ready);
      -- send 1st sync:
      send_sync(clk_100, tb_lanes_ready, tb_valid_status, sync, manual_mode);
      wait for 100 ns;
      write_log(clk_100, tb_cb_status, tb_be_status);
      --
      wait for 2000 ns;
      -- send 2nd sync:
      send_sync(clk_100, tb_lanes_ready, tb_valid_status, sync, manual_mode);
      wait for 100 ns;
      write_log(clk_100, tb_cb_status, tb_be_status);
    ----------------------------------------------------------------------------------------------------
    -- TEST 2: Uncomment lines below and comment TEST 1 lines above
    --         Set boolean constant GEN_ESISTREAM to false to speed up simulation for
    -- uart & spi communication tests below.
    -- uart 115200, 8-bit
    ----------------------------------------------------------------------------------------------------
    else
      report "test 2...";
      report "wait uart_ready";
      wait until rising_edge(tb_uart_ready);
      -------------------------------- 
      -- s1 enable interrupt of tb uart_wrapper_1 module
      -------------------------------- 
      axi4_lite_write(clk_100, ADDR_CTRL, x"10", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);  -- s1 enable interrupt
      wait for 200 us;

      -------------------------------- 
      -- UART WRITE command 
      --------------------------------
      -- spi slave select command, external pll
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"03", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, reg3, m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      wait for 1 ms;
      wait until rising_edge(clk_100);
      -- spi write fifo in 
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"04", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"55", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"AA", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"55", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      wait for 1 ms;
      wait until rising_edge(clk_100);
      -- spi write fifo in 
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"04", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"87", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"65", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"43", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      --
      reg3 <= reg3 or SPI_START_ENABLE;
      wait for 1 ms;
      wait until rising_edge(clk_100);
      -- spi start command
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"03", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, x"00", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      axi4_lite_write(clk_100, ADDR_TX_FIFO, reg3, m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);
      wait for 1 ms;
      wait until rising_edge(clk_100);
    -- wait until rising_edge(s1_interrupt);                                                                     -- Wait TX FIFO empty
    -- wait until rising_edge(s1_interrupt);                                                                     -- Wait ACK
    -- axi4_lite_read(clk, ADDR_RX_FIFO, s1_rdata, m1_axi_addr, m1_axi_rdata, m1_axi_ren, m1_axi_busy);
    -- -- axi4_lite_write(clk_100, ADDR_CTRL, x"10", m1_axi_addr, m1_axi_strb, m1_axi_wdata, m1_axi_wen, m1_axi_busy);  -- s1 enable interrupt
    -- -- wait until rising_edge(s1_interrupt);                                                                     -- Wait TX FIFO empty
    -- -- wait until rising_edge(s1_interrupt);                                                                     -- Wait ACK
    -- -- axi4_lite_read(clk_100, ADDR_RX_FIFO, s1_rdata, m1_axi_addr, m1_axi_rdata, m1_axi_ren, m1_axi_busy);
    end if;
    assert false report "Test finish" severity failure;
    wait;
  end process;

  gen_esistream_hdl : if GEN_ESISTREAM = true generate
    clk_bit <= not clk_bit after clk_bit_half_period;

    tx_esistream_emulator_1 : entity work.tx_emu_esistream_top
      generic map (
        NB_LANES => NB_LANES,
        COMMA    => COMMA)
      port map (
        rst         => rst,
        clk         => clk_bit,
        sync_in     => synctrig_p,
        prbs_en     => tx_prbs_en,
        disp_en     => tx_disp_en,
        lfsr_init   => lfsr_init,
        data_ctrl   => tx_d_ctrl,
        sso_p       => sso_p,
        sso_n       => sso_n,
        tx_clk      => tx_clk,
        tx_ip_ready => tx_ip_ready,
        txp         => txp,
        txn         => txn,
        lss         => tx_lss);  -- when '1' lane synchronization sequence (FAS + PSS) sent on txp/n lanes else normal data.
  end generate gen_esistream_hdl;

  -- Simulate PC:
  rstn <= not rst;
  uart_wrapper_1 : entity work.uart_wrapper
    port map (
      clk         => clk_100,
      rstn        => rstn,
      m_axi_addr  => m1_axi_addr,
      m_axi_strb  => m1_axi_strb,
      m_axi_wdata => m1_axi_wdata,
      m_axi_rdata => m1_axi_rdata,
      m_axi_wen   => m1_axi_wen,
      m_axi_ren   => m1_axi_ren,
      m_axi_busy  => m1_axi_busy,
      interrupt   => s1_interrupt,
      tx          => uart_tx,
      rx          => uart_rx);
--
end behavioral;
