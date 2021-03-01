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

entity axi4_lite_master is
  --generic(
  --  S_DATA_WIDTH : integer := 8
  --  );
  port (
    -- AXI MASTER PORT
    m_axi_aclk    : in  std_logic;
    m_axi_aresetn : in  std_logic;
    m_axi_addr    : in  std_logic_vector(3 downto 0);
    m_axi_strb    : in  std_logic_vector(3 downto 0);
    m_axi_wdata   : in  std_logic_vector(31 downto 0);
    m_axi_rdata   : out std_logic_vector(31 downto 0);
    m_axi_wen     : in  std_logic;
    m_axi_ren     : in  std_logic;
    m_axi_busy    : out std_logic;
    -- AXI SLAVE PORT
    -- write address channel
    s_axi_awaddr  : out std_logic_vector(3 downto 0);
    s_axi_awvalid : out std_logic;
    s_axi_awready : in  std_logic;
    -- write data channel
    s_axi_wdata   : out std_logic_vector(31 downto 0);
    s_axi_wstrb   : out std_logic_vector(3 downto 0);
    s_axi_wvalid  : out std_logic;
    s_axi_wready  : in  std_logic;
    -- write response channel 
    s_axi_bresp   : in  std_logic_vector(1 downto 0);
    s_axi_bvalid  : in  std_logic;
    s_axi_bready  : out std_logic;
    -- read adress channel
    s_axi_araddr  : out std_logic_vector(3 downto 0);
    s_axi_arvalid : out std_logic;
    s_axi_arready : in  std_logic;
    -- read data channel
    s_axi_rdata   : in  std_logic_vector(31 downto 0);
    -- read response channel
    s_axi_rresp   : in  std_logic_vector(1 downto 0);
    s_axi_rvalid  : in  std_logic;
    s_axi_rready  : out std_logic
    );
end axi4_lite_master;

architecture rtl of axi4_lite_master is
  --
  type state_type is (st_idle, st_write, st_read);
  signal state, next_state    : state_type;
  signal wr_busy_s, wr_busy_a : std_logic := '0';
  signal rd_busy_s, rd_busy_a : std_logic := '0';
  signal awready_i            : std_logic := '0';
  signal wready_i             : std_logic := '0';
  signal bvalid_i             : std_logic := '0';
  signal arready_i            : std_logic := '0';
  signal rvalid_i             : std_logic := '0';
  signal wr_done              : std_logic := '0';
  signal rd_done              : std_logic := '0';
--
begin

  -------------------------------------------------------------------------------
  -- MAIN FSM
  -------------------------------------------------------------------------------
  SYNC_PROC : process (m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if m_axi_aresetn = '0' then
        state     <= st_idle;
        wr_busy_s <= '0';
        rd_busy_s <= '0';
      else
        state     <= next_state;
        wr_busy_s <= wr_busy_a;
        rd_busy_s <= rd_busy_a;
      end if;
    end if;
  end process;

  --MOORE State-Machine - Outputs based on state only
  OUTPUT_DECODE : process (state, m_axi_addr)
  begin
    if state = st_idle then
      wr_busy_a <= '0';
      rd_busy_a <= '0';
    elsif state = st_write then
      wr_busy_a <= '1';
      rd_busy_a <= '0';
    elsif state = st_read then
      wr_busy_a <= '0';
      rd_busy_a <= '1';
    else
      wr_busy_a <= '0';
      rd_busy_a <= '0';
    end if;
  end process;

  NEXT_STATE_DECODE : process (state, m_axi_aresetn, m_axi_wen, m_axi_ren, wr_done, rd_done)
  begin
    next_state <= state;
    case state is
      when st_idle =>
        if m_axi_aresetn = '1' then
          if m_axi_wen = '1' then
            next_state <= st_write;
          elsif m_axi_ren = '1' then
            next_state <= st_read;
          else
            next_state <= st_idle;
          end if;
        else
          next_state <= st_idle;
        end if;
      when st_write =>
        if wr_done = '1' then
          next_state <= st_idle;
        else
          next_state <= st_write;
        end if;
      when st_read =>
        if rd_done = '1' then
          next_state <= st_idle;
        else
          next_state <= st_read;
        end if;
      when others =>
        next_state <= st_idle;
    end case;
  end process;

  -------------------------------------------------------------------------------
  --  -- AXI SLAVE PORT
  -------------------------------------------------------------------------------
  --  -- write address channel
  --  s_axi_awaddr  : out std_logic_vector(3 downto 0);
  --  s_axi_awvalid : out std_logic;
  --  s_axi_awready : in  std_logic;
  --  -- write data channel
  --  s_axi_wdata   : out std_logic_vector(31 downto 0);
  --  s_axi_wstrb   : out std_logic_vector(3 downto 0);
  --  s_axi_wvalid  : out std_logic;
  --  s_axi_wready  : in  std_logic;
  --  -- write response channel 
  --  s_axi_bresp   : in  std_logic_vector(1 downto 0);
  --  s_axi_bvalid  : in  std_logic;
  --  s_axi_bready  : out std_logic;
  --  -- read adress channel
  --  s_axi_araddr  : out std_logic_vector(3 downto 0);
  --  s_axi_arvalid : out std_logic;
  --  s_axi_arready : in  std_logic;
  --  -- read data channel
  --  s_axi_rdata   : in  std_logic_vector(31 downto 0);
  --  -- read response channel
  --  s_axi_rresp   : in  std_logic_vector(1 downto 0);
  --  s_axi_rvalid  : in  std_logic;
  --  s_axi_rready  : out std_logic;
  -------------------------------------------------------------------------------
  p_wr : process(m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if wr_done = '1' then
        s_axi_awaddr  <= (others => '0');
        s_axi_awvalid <= '0';
        s_axi_wdata   <= (others => '0');
        s_axi_wstrb   <= (others => '0');
        s_axi_wvalid  <= '0';
        s_axi_bready  <= '0';
      elsif wr_busy_s = '1' then
        s_axi_awaddr  <= m_axi_addr;
        s_axi_awvalid <= '1';
        s_axi_wdata   <= m_axi_wdata;
        s_axi_wstrb   <= m_axi_strb;
        s_axi_wvalid  <= '1';
        s_axi_bready  <= '1';
      end if;
    end if;
  end process;

  p_wr_done : process(m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if wr_busy_s = '1' and s_axi_awready = '1' then
        awready_i <= '1';
      elsif wr_busy_s = '0' then
        awready_i <= '0';
      end if;

      if wr_busy_s = '1' and s_axi_wready = '1' then
        wready_i <= '1';
      elsif wr_busy_s = '0' then
        wready_i <= '0';
      end if;

      if wr_busy_s = '1' and s_axi_bvalid = '1' then
        bvalid_i <= '1';
      elsif wr_busy_s = '0' then
        bvalid_i <= '0';
      end if;
    end if;
  end process;
  wr_done <= (awready_i or s_axi_awready) and (wready_i or s_axi_wready) and (s_axi_bvalid or bvalid_i);

  p_rd : process(m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if rd_done = '1' then
        s_axi_araddr  <= (others => '0');
        s_axi_arvalid <= '0';
        s_axi_rready  <= '0';
      elsif rd_busy_s = '1' then
        s_axi_araddr  <= m_axi_addr;
        s_axi_arvalid <= '1';
        s_axi_rready  <= '1';
      end if;
    end if;
  end process;

  p_rd_done : process(m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if rd_busy_s = '1' and s_axi_arready = '1' then
        arready_i   <= '1';
      elsif rd_busy_s = '0' then
        arready_i <= '0';
      end if;

      if rd_busy_s = '1' and s_axi_rvalid = '1' then
        rvalid_i <= '1';
        m_axi_rdata <= s_axi_rdata;
      elsif rd_busy_s = '0' then
        rvalid_i <= '0';
      end if;
    end if;
  end process;
  rd_done <= (arready_i or s_axi_arready) and (s_axi_rvalid or rvalid_i);

  m_axi_busy <= wr_busy_s or rd_busy_s;
-------------------------------------------------------------------------------
-- process(m_axi_aclk)
-- begin
--   if rising_edge(m_axi_aclk) then
--  
--   end if;
-- end process;
-------------------------------------------------------------------------------

end rtl;
