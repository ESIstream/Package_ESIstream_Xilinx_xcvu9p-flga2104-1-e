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

entity register_map is
  generic(
    CLK_FREQUENCY_HZ : integer := 100000000;  --! timer system clock frequency [Hz] 
    TIME_US          : integer := 2000        --! time to count [us] 
    );
  port (
    clk          : in  std_logic;
    rstn         : in  std_logic;
    interrupt_en : in  std_logic;
    m_axi_addr   : out std_logic_vector(3 downto 0);
    m_axi_strb   : out std_logic_vector(3 downto 0);
    m_axi_wdata  : out std_logic_vector(31 downto 0);
    m_axi_rdata  : in  std_logic_vector(31 downto 0);
    m_axi_wen    : out std_logic;
    m_axi_ren    : out std_logic;
    m_axi_busy   : in  std_logic;
    interrupt    : in  std_logic;             -- Active high, clk indicating UART RX FIFO not empty
    uart_ready   : out std_logic;
    reg_0        : out std_logic_vector(31 downto 0);
    reg_1        : out std_logic_vector(31 downto 0);
    reg_2        : out std_logic_vector(31 downto 0);
    reg_3        : out std_logic_vector(31 downto 0);
    reg_4        : out std_logic_vector(31 downto 0);
    reg_5        : out std_logic_vector(31 downto 0);
    reg_6        : out std_logic_vector(31 downto 0);
    reg_7        : out std_logic_vector(31 downto 0);
    reg_8        : in  std_logic_vector(31 downto 0);
    reg_9        : in  std_logic_vector(31 downto 0);
    reg_10       : in  std_logic_vector(31 downto 0);
    reg_11       : in  std_logic_vector(31 downto 0);
    reg_12       : out std_logic_vector(31 downto 0);
    reg_13       : out std_logic_vector(31 downto 0);
    reg_14       : out std_logic_vector(31 downto 0);
    reg_15       : out std_logic_vector(31 downto 0);
    reg_16       : out std_logic_vector(31 downto 0);
    reg_17       : out std_logic_vector(31 downto 0);
    reg_18       : in  std_logic_vector(31 downto 0);
    reg_19       : in  std_logic_vector(31 downto 0);
    reg_4_os     : out std_logic;
    reg_5_os     : out std_logic;
    reg_6_os     : out std_logic;
    reg_7_os     : out std_logic;
    reg_10_os    : out std_logic;
    reg_12_os    : out std_logic
    );
end register_map;

architecture rtl of register_map is
  signal reg_addr          : std_logic_vector(15 downto 0) := (others => '0');
  signal reg_rdata         : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_wdata         : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_wen           : std_logic                     := '0';
  signal reg_ren           : std_logic                     := '0';
  --
  constant reg_0_addr      : integer                       := 0;
  constant reg_1_addr      : integer                       := 1;
  constant reg_2_addr      : integer                       := 2;
  constant reg_3_addr      : integer                       := 3;
  constant reg_4_addr      : integer                       := 4;
  constant reg_5_addr      : integer                       := 5;
  constant reg_6_addr      : integer                       := 6;
  constant reg_7_addr      : integer                       := 7;
  constant reg_8_addr      : integer                       := 8;
  constant reg_9_addr      : integer                       := 9;
  constant reg_10_addr     : integer                       := 10;
  constant reg_11_addr     : integer                       := 11;
  constant reg_12_addr     : integer                       := 12;
  constant reg_13_addr     : integer                       := 13;
  constant reg_14_addr     : integer                       := 14;
  constant reg_15_addr     : integer                       := 15;
  constant reg_16_addr     : integer                       := 16;
  constant reg_17_addr     : integer                       := 17;
  constant reg_18_addr     : integer                       := 18;
  constant reg_19_addr     : integer                       := 19;
  constant reg_status_addr : integer                       := 255;
  --
  signal reg_0_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_1_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_2_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_3_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_4_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_5_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_6_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_7_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_8_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_9_m           : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_10_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_11_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_12_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_13_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_14_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_15_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_16_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_17_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_18_m          : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_19_m          : std_logic_vector(31 downto 0) := (others => '0');
  --
  signal n_m_axi_busy      : std_logic                     := '0';
  signal n_m_axi_busy_re   : std_logic                     := '0';
  signal interrupt_mem     : std_logic                     := '0';
--
begin

  -- uart ready :
  process(clk)
  begin
    if rising_edge(clk) then
      if rstn = '0' then
        uart_ready    <= '0';
        interrupt_mem <= '0';
      else
        if interrupt_en = '1' then
          interrupt_mem <= '1';
        elsif interrupt_mem = '1' and n_m_axi_busy_re = '1' then
          interrupt_mem <= '0';
          uart_ready    <= '1';
        end if;
      end if;
    end if;
  end process;

  n_m_axi_busy <= not m_axi_busy;
  risingedge_1 : entity work.risingedge
    port map (
      rst => '0',
      clk => clk,
      d   => n_m_axi_busy,
      re  => n_m_axi_busy_re);

  register_map_fsm_1 : entity work.register_map_fsm
    generic map (
      CLK_FREQUENCY_HZ => CLK_FREQUENCY_HZ,
      TIME_US          => TIME_US)
    port map (
      clk          => clk,
      rstn         => rstn,
      interrupt_en => interrupt_en,
      m_axi_addr   => m_axi_addr,
      m_axi_strb   => m_axi_strb,
      m_axi_wdata  => m_axi_wdata,
      m_axi_rdata  => m_axi_rdata,
      m_axi_wen    => m_axi_wen,
      m_axi_ren    => m_axi_ren,
      m_axi_busy   => m_axi_busy,
      interrupt    => interrupt,
      reg_addr     => reg_addr,
      reg_rdata    => reg_rdata,
      reg_wdata    => reg_wdata,
      reg_wen      => reg_wen,
      reg_ren      => reg_ren);

  wr_p : process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rstn = '0' then
        reg_0_m   <= (others => '0');
        reg_1_m   <= (others => '0');
        reg_2_m   <= (others => '0');
        reg_3_m   <= (others => '0');
        reg_4_m   <= (others => '0');
        reg_5_m   <= x"00000001";
        reg_6_m   <= (others => '0');
        reg_7_m   <= (others => '0');
        reg_4_os  <= '0';
        reg_5_os  <= '0';
        reg_6_os  <= '0';
        reg_7_os  <= '0';
        reg_12_os <= '0';
        reg_13_m   <= (others => '0');
        reg_14_m   <= (others => '0');
        reg_15_m   <= (others => '0');
        reg_16_m   <= (others => '0');
        reg_17_m   <= (others => '0');
      elsif reg_addr(15) = '0' and reg_wen = '1' then  -- write operation
        case to_integer(unsigned(reg_addr(14 downto 0))) is
          when reg_0_addr => reg_0_m <= reg_wdata;
          when reg_1_addr => reg_1_m <= reg_wdata;
          when reg_2_addr => reg_2_m <= reg_wdata;
          when reg_3_addr => reg_3_m <= reg_wdata;
          when reg_4_addr => reg_4_m <= reg_wdata;
                             reg_4_os <= '1';
          when reg_5_addr => reg_5_m <= reg_wdata;
                             reg_5_os <= '1';
          when reg_6_addr => reg_6_m <= reg_wdata;
                             reg_6_os <= '1';
          when reg_7_addr => reg_7_m <= reg_wdata;
                             reg_7_os <= '1';
          when reg_12_addr => reg_12_m <= reg_wdata;
                              reg_12_os <= '1';
          when reg_13_addr => reg_13_m <= reg_wdata;
          when reg_14_addr => reg_14_m <= reg_wdata;
          when reg_15_addr => reg_15_m <= reg_wdata;
          when reg_16_addr => reg_16_m <= reg_wdata;
          when reg_17_addr => reg_17_m <= reg_wdata;
          when others => null;
        end case;
      else
        reg_4_os  <= '0';
        reg_5_os  <= '0';
        reg_6_os  <= '0';
        reg_7_os  <= '0';
        reg_12_os <= '0';
      end if;
    end if;
  end process;
  --
  rd_p : process (clk)
  begin  -- process
    if rising_edge(clk) then
      if reg_addr(15) = '1' then                       -- read operation
        case to_integer(unsigned(reg_addr(14 downto 0))) is
          when reg_0_addr  => reg_rdata <= reg_0_m;
          when reg_1_addr  => reg_rdata <= reg_1_m;
          when reg_2_addr  => reg_rdata <= reg_2_m;
          when reg_3_addr  => reg_rdata <= reg_3_m;
          when reg_4_addr  => reg_rdata <= reg_4_m;
          when reg_5_addr  => reg_rdata <= reg_5_m;
          when reg_6_addr  => reg_rdata <= reg_6_m;
          when reg_7_addr  => reg_rdata <= reg_7_m;
          when reg_8_addr  => reg_rdata <= reg_8_m;
          when reg_9_addr  => reg_rdata <= reg_9_m;
          when reg_10_addr => reg_rdata <= reg_10_m;
                              if reg_wen = '1' then
                                reg_10_os <= '1';
                              else
                                reg_10_os <= '0';
                              end if;
          when reg_11_addr     => reg_rdata <= reg_11_m;
          when reg_12_addr     => reg_rdata <= reg_12_m;
          when reg_18_addr     => reg_rdata <= reg_18_m;
          when reg_19_addr     => reg_rdata <= reg_19_m;
          when reg_status_addr => reg_rdata <= x"20152018";
          when others          => null;
        end case;
      else
        reg_10_os <= '0';
      end if;
    end if;
  end process;

  reg_0    <= reg_0_m;   --wr
  reg_1    <= reg_1_m;   --wr
  reg_2    <= reg_2_m;   --wr
  reg_3    <= reg_3_m;   --wr
  reg_4    <= reg_4_m;   --wr
  reg_5    <= reg_5_m;   --wr
  reg_6    <= reg_6_m;   --wr
  reg_7    <= reg_7_m;   --wr
  reg_8_m  <= reg_8;     --rd
  reg_9_m  <= reg_9;     --rd
  reg_10_m <= reg_10;    --rd
  reg_11_m <= reg_11;    --rd
  reg_12   <= reg_12_m;  --wr
  reg_13   <= reg_13_m;  --wr
  reg_14   <= reg_14_m;  --wr
  reg_15   <= reg_15_m;  --wr
  reg_16   <= reg_16_m;  --wr
  reg_17   <= reg_17_m;  --wr
  reg_18_m <= reg_18;    --rd
  reg_19_m <= reg_19;    --rd

-------------------------------------------------------------------------------
-- process(clk)
-- begin
--   if rising_edge(clk) then
--  
--   end if;
-- end process;
-------------------------------------------------------------------------------

end rtl;
