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

entity uart_wrapper is
  --generic(
  --  S_DATA_WIDTH : integer := 8
  --  );
  port (
    -- AXI MASTER PORT
    clk           : in  std_logic;
    rstn          : in  std_logic;
    m_axi_addr    : in  std_logic_vector(3 downto 0);
    m_axi_strb    : in  std_logic_vector(3 downto 0);
    m_axi_wdata   : in  std_logic_vector(31 downto 0);
    m_axi_rdata   : out std_logic_vector(31 downto 0);
    m_axi_wen     : in  std_logic;
    m_axi_ren     : in  std_logic;
    m_axi_busy    : out std_logic;
    -- UART PORT
    interrupt     : out std_logic;
    tx            : out std_logic;
    rx            : in  std_logic
    );
end uart_wrapper;

architecture rtl of uart_wrapper is
  --
  signal s_axi_awaddr     : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_axi_awvalid    : std_logic                     := '0';
  signal s_axi_awready    : std_logic                     := '0';
  signal s_axi_wdata      : std_logic_vector(31 downto 0) := (others => '0');
  signal s_axi_wstrb      : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_axi_wvalid     : std_logic                     := '0';
  signal s_axi_wready     : std_logic                     := '0';
  signal s_axi_bresp      : std_logic_vector(1 downto 0);
  signal s_axi_bvalid     : std_logic                     := '0';
  signal s_axi_bready     : std_logic                     := '0';
  signal s_axi_araddr     : std_logic_vector(3 downto 0);
  signal s_axi_arvalid    : std_logic                     := '0';
  signal s_axi_arready    : std_logic                     := '0';
  signal s_axi_rdata      : std_logic_vector(31 downto 0) := (others => '0');
  signal s_axi_rresp      : std_logic_vector(1 downto 0)  := (others => '0');
  signal s_axi_rvalid     : std_logic                     := '0';
  signal s_axi_rready     : std_logic                     := '0';
  --
begin
  axi4_lite_master_1 : entity work.axi4_lite_master
    port map (
      m_axi_aclk    => clk,
      m_axi_aresetn => rstn,
      m_axi_addr    => m_axi_addr,
      m_axi_strb    => m_axi_strb,
      m_axi_wdata   => m_axi_wdata,
      m_axi_rdata   => m_axi_rdata,
      m_axi_wen     => m_axi_wen,
      m_axi_ren     => m_axi_ren,
      m_axi_busy    => m_axi_busy,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready);
  --
  axi_uartlite_0_1 : entity work.axi_uartlite_0
    port map (
      s_axi_aclk    => clk,
      s_axi_aresetn => rstn,
      interrupt     => interrupt,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready,
      rx            => rx,
      tx            => tx);

-------------------------------------------------------------------------------
-- process(m_axi_aclk)
-- begin
--   if rising_edge(m_axi_aclk) then
--  
--   end if;
-- end process;
-------------------------------------------------------------------------------

end rtl;
