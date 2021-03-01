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

entity register_map_fsm is
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
    reg_addr     : out std_logic_vector(15 downto 0);
    reg_rdata    : in  std_logic_vector(31 downto 0);
    reg_wdata    : out std_logic_vector(31 downto 0);
    reg_wen      : out std_logic;
    reg_ren      : in  std_logic
    );
end register_map_fsm;

architecture rtl of register_map_fsm is
  --
  type state_type is (st_idle, st_adh, st_adl, st_wd3, st_wd2, st_wd1, st_wd0, st_ack);
  signal state, next_state             : state_type;
  --
  constant ADDR_RX_FIFO                : std_logic_vector(3 downto 0)    := x"0";
  constant ADDR_TX_FIFO                : std_logic_vector(3 downto 0)    := x"4";
  constant ADDR_STAT                   : std_logic_vector(3 downto 0)    := x"8";
  constant ADDR_CTRL                   : std_logic_vector(3 downto 0)    := x"C";
  constant ACK_BYTE                    : std_logic_vector(7 downto 0)    := x"AC";
  --
  signal busy_s, busy_a                : std_logic                       := '0';
  signal m_axi_wr_en_s, m_axi_wr_en_a  : std_logic                       := '0';
  signal m_axi_rd_en_s, m_axi_rd_en_a  : std_logic                       := '0';
  signal reg_wr_en_s, reg_wr_en_a      : std_logic                       := '0';
  signal wr_ack_s, wr_ack_a            : std_logic                       := '0';
  signal timer_start_s, timer_start_a  : std_logic                       := '0';
  --
  signal timer_done                    : std_logic                       := '0';
  signal m_axi_wr_en_d, m_axi_wr_en_d2 : std_logic                       := '0';
  signal m_axi_rd_en_d, m_axi_rd_en_d2 : std_logic                       := '0';
  --
  type slv_8_array_n is array (natural range <>) of std_logic_vector(8-1 downto 0);
  signal uart_adata                    : slv_8_array_n(5 downto 0)       := (others => (others => '0'));
  --
  signal rst                           : std_logic                       := '0';
  constant CNTR_WIDTH                  : integer                         := 3;
  signal cntr                          : unsigned(CNTR_WIDTH-1 downto 0) := to_unsigned(5, CNTR_WIDTH);
  signal n_m_axi_busy                  : std_logic                       := '0';
  signal n_m_axi_busy_re               : std_logic                       := '0';
--
begin

  addr_ren_wen_p : process(clk)
  begin
    if rising_edge(clk) then
      m_axi_rd_en_d  <= m_axi_rd_en_s;
      m_axi_wr_en_d  <= m_axi_wr_en_s;
      m_axi_rd_en_d2 <= m_axi_rd_en_d;
      m_axi_wr_en_d2 <= m_axi_wr_en_d;
      m_axi_strb     <= "0001";
      --if m_axi_rd_en_s = '1' then
      if m_axi_rd_en_d2 = '1' then
        m_axi_addr <= ADDR_RX_FIFO;
        m_axi_ren  <= '1';
        m_axi_wen  <= '0';
      --elsif m_axi_wr_en_s = '1' then
      elsif m_axi_wr_en_d2 = '1' then
        m_axi_addr               <= ADDR_TX_FIFO;
        m_axi_ren                <= '0';
        m_axi_wen                <= '1';
        m_axi_wdata(31 downto 8) <= (others => '0');
        if cntr < 4 then
          m_axi_wdata(7 downto 0) <= reg_rdata(8*(to_integer(cntr))+7 downto 8*(to_integer(cntr)));
        end if;
      elsif wr_ack_s = '1' then
        m_axi_addr               <= ADDR_TX_FIFO;
        m_axi_ren                <= '0';
        m_axi_wen                <= '1';
        m_axi_wdata(31 downto 8) <= (others => '0');
        m_axi_wdata(7 downto 0)  <= ACK_BYTE;
      elsif interrupt_en = '1' then
        m_axi_addr               <= ADDR_CTRL;
        m_axi_ren                <= '0';
        m_axi_wen                <= '1';
        m_axi_wdata(31 downto 8) <= (others => '0');
        m_axi_wdata(7 downto 0)  <= x"10";
        -- TX and RX FIFO should be reset if a UART command occurs before interrupt_en ...
      else
        m_axi_ren <= '0';
        m_axi_wen <= '0';
      end if;
    end if;
  end process;

  cntr_p : process(clk)
  begin
    if rising_edge(clk) then
      if busy_s = '1' then
        --if interrupt = '1' then
        if m_axi_wr_en_s = '1' or m_axi_rd_en_s = '1' then
          if cntr = 0 then
            cntr <= cntr;
          else
            cntr <= cntr-1;
          end if;
        end if;
      else
        cntr <= to_unsigned(5, cntr'length);
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

  w_uart_adata : process(clk)
  begin
    if rising_edge(clk) then
      if n_m_axi_busy_re = '1' then
        uart_adata(to_integer(cntr)) <= m_axi_rdata(7 downto 0);
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- MAIN FSM
  -------------------------------------------------------------------------------
  SYNC_PROC : process (clk)
  begin
    if rising_edge(clk) then
      if rstn = '0' or interrupt_en = '1' then
        state         <= st_idle;
        timer_start_s <= '0';
        m_axi_rd_en_s <= '0';
        m_axi_wr_en_s <= '0';
        busy_s        <= '1';
        reg_wr_en_s   <= '0';
        wr_ack_s      <= '0';
      else
        state         <= next_state;
        timer_start_s <= timer_start_a;
        m_axi_rd_en_s <= m_axi_rd_en_a;
        m_axi_wr_en_s <= m_axi_wr_en_a;
        busy_s        <= busy_a;
        reg_wr_en_s   <= reg_wr_en_a;
        wr_ack_s      <= wr_ack_a;
      end if;
    end if;
  end process;

  --MOORE State-Machine - Outputs based on state only
  OUTPUT_DECODE : process (state, interrupt, uart_adata(5)(7), n_m_axi_busy_re)
  begin
    if state = st_idle then
      busy_a        <= '0';
      reg_wr_en_a   <= '0';
      m_axi_wr_en_a <= '0';
      if interrupt = '1' then
        m_axi_rd_en_a <= '1';
        timer_start_a <= '1';
      else
        m_axi_rd_en_a <= '0';
        timer_start_a <= '0';
      end if;
      wr_ack_a <= '0';
    --  
    elsif state = st_adh then
      timer_start_a <= '1';
      busy_a        <= '1';
      reg_wr_en_a   <= '0';
      m_axi_wr_en_a <= '0';
      if interrupt = '1' then
        m_axi_rd_en_a <= '1';
      else
        m_axi_rd_en_a <= '0';
      end if;
      wr_ack_a <= '0';
    --  
    elsif state = st_adl then
      timer_start_a <= '1';
      busy_a        <= '1';
      reg_wr_en_a   <= '0';
      if uart_adata(5)(7) = '0' and interrupt = '1' then
        m_axi_rd_en_a <= '1';
        m_axi_wr_en_a <= '0';
      elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '1';
      else
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '0';
      end if;
      wr_ack_a <= '0';
    --  
    elsif state = st_wd3 then
      timer_start_a <= '1';
      busy_a        <= '1';
      reg_wr_en_a   <= '0';
      if uart_adata(5)(7) = '0' and interrupt = '1' then
        m_axi_rd_en_a <= '1';
        m_axi_wr_en_a <= '0';
      elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '1';
      else
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '0';
      end if;
      wr_ack_a <= '0';
    --
    elsif state = st_wd2 then
      timer_start_a <= '1';
      busy_a        <= '1';
      reg_wr_en_a   <= '0';
      if uart_adata(5)(7) = '0' and interrupt = '1' then
        m_axi_rd_en_a <= '1';
        m_axi_wr_en_a <= '0';
      elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '1';
      else
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '0';
      end if;
      wr_ack_a <= '0';
    --
    elsif state = st_wd1 then
      timer_start_a <= '1';
      busy_a        <= '1';
      reg_wr_en_a   <= '0';
      if uart_adata(5)(7) = '0' and interrupt = '1' then
        m_axi_rd_en_a <= '1';
        m_axi_wr_en_a <= '0';
      elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '1';
      else
        m_axi_rd_en_a <= '0';
        m_axi_wr_en_a <= '0';
      end if;
      wr_ack_a <= '0';
    --
    elsif state = st_wd0 then
      timer_start_a <= '1';
      busy_a        <= '1';
      m_axi_rd_en_a <= '0';
      m_axi_wr_en_a <= '0';
      if n_m_axi_busy_re = '1' then
        reg_wr_en_a <= '1';
        wr_ack_a    <= '1';
      else
        reg_wr_en_a <= '0';
        wr_ack_a    <= '0';
      end if;
    elsif state = st_ack then
      timer_start_a <= '1';
      busy_a        <= '1';
      m_axi_rd_en_a <= '0';
      m_axi_wr_en_a <= '0';
      wr_ack_a      <= '0';
      reg_wr_en_a   <= '0';
    --
    else
      timer_start_a <= '1';
      busy_a        <= '0';
      m_axi_rd_en_a <= '0';
      m_axi_wr_en_a <= '0';
      wr_ack_a      <= '0';
      reg_wr_en_a   <= '0';
    end if;
  end process;

  NEXT_STATE_DECODE : process (state, interrupt, uart_adata(5)(7), n_m_axi_busy_re, timer_done)
  begin
    next_state <= state;
    case state is
      --
      when st_idle =>
        if interrupt = '1' then
          next_state <= st_adh;
        else
          next_state <= st_idle;
        end if;
      --
      when st_adh =>
        if timer_done = '1' then
          next_state <= st_idle;
        elsif interrupt = '1' then
          next_state <= st_adl;
        else
          next_state <= st_adh;
        end if;
      --
      when st_adl =>
        if timer_done = '1' then
          next_state <= st_idle;
        elsif uart_adata(5)(7) = '0' and interrupt = '1' then
          next_state <= st_wd3;
        elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
          next_state <= st_wd3;
        else
          next_state <= st_adl;
        end if;
      --
      when st_wd3 =>
        if timer_done = '1' then
          next_state <= st_idle;
        elsif uart_adata(5)(7) = '0' and interrupt = '1' then
          next_state <= st_wd2;
        elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
          next_state <= st_wd2;
        else
          next_state <= st_wd3;
        end if;
      --
      when st_wd2 =>
        if timer_done = '1' then
          next_state <= st_idle;
        elsif uart_adata(5)(7) = '0' and interrupt = '1' then
          next_state <= st_wd1;
        elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
          next_state <= st_wd1;
        else
          next_state <= st_wd2;
        end if;
      --
      when st_wd1 =>
        if timer_done = '1' then
          next_state <= st_idle;
        elsif uart_adata(5)(7) = '0' and interrupt = '1' then
          next_state <= st_wd0;
        elsif uart_adata(5)(7) = '1' and n_m_axi_busy_re = '1' then
          next_state <= st_wd0;
        else
          next_state <= st_wd1;
        end if;
      --
      when st_wd0 =>
        if timer_done = '1' then
          next_state <= st_idle;
        elsif n_m_axi_busy_re = '1' then
          next_state <= st_ack;
        else
          next_state <= st_wd0;
        end if;
      --if uart_adata(5)(7) = '0' and n_m_axi_busy_re = '1' then
      --  next_state <= st_idle;
      --elsif uart_adata(5)(7) = '1' and interrupt = '1' then  -- wait TX FIFO empty
      --  next_state <= st_idle;
      --else
      --  next_state <= st_wd0;
      --end if;
      when st_ack =>
        if interrupt = '1' or timer_done = '1' then  -- wait TX FIFO empty
          next_state <= st_idle;
        else
          next_state <= st_ack;
        end if;
      when others =>
        next_state <= st_idle;
    end case;
  end process;

  reg_bus_wr : process(clk)
  begin
    if rising_edge(clk) then
      reg_addr <= uart_adata(5) & uart_adata(4);
      if reg_wr_en_s = '1' then
        reg_wdata <= uart_adata(3) & uart_adata(2) & uart_adata(1) & uart_adata(0);
        reg_wen   <= '1';
      else
        reg_wen <= '0';
      end if;
    end if;
  end process;

  -- timeout timer
  timer_1 : entity work.timer
    generic map (
      CLK_FREQUENCY_HZ => CLK_FREQUENCY_HZ,
      TIME_US          => TIME_US)
    port map (
      rst         => '0',
      clk         => clk,
      timer_start => timer_start_s,
      timer_busy  => open,  --timer_busy,
      timer_done  => timer_done);
  
end rtl;
