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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity spi_fifo is
  generic (
    DATA_WIDTH : integer := 8;
    FIFO_DEPTH : integer := 10
    );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    wr_en        : in  std_logic;
    rd_en        : in  std_logic;
    din          : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    dout         : out std_logic_vector(DATA_WIDTH-1 downto 0);
    full         : out std_logic;
    empty        : out std_logic;
    almost_empty : out std_logic;
    rd_counter   : out std_logic_vector(FIFO_DEPTH-1 downto 0)
    );
end spi_fifo;

architecture rtl of spi_fifo is

  constant CNTR_MAX         : unsigned(FIFO_DEPTH-1 downto 0) := (others => '1');
  constant CNTR_ONE         : unsigned(FIFO_DEPTH-1 downto 0) := to_unsigned(1, FIFO_DEPTH);
  constant CNTR_NULL        : unsigned(FIFO_DEPTH-1 downto 0) := (others => '0');
  --
  type FIFO_ARRAY is array(0 to ((2**FIFO_DEPTH)-1)) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal fifo           : FIFO_ARRAY                      := (others => (others => '0'));
  --
  signal ptr_rd         : unsigned(FIFO_DEPTH-1 downto 0) := (others => '0');
  signal ptr_wr         : unsigned(FIFO_DEPTH-1 downto 0) := (others => '0');
  signal ptr_cntr       : unsigned(FIFO_DEPTH-1 downto 0) := (others => '0');
  signal full_o         : std_logic                       := '0';
  signal empty_o        : std_logic                       := '0';
  signal almost_empty_o : std_logic                       := '0';
  signal wr_data        : std_logic                       := '0';
  signal rd_data        : std_logic                       := '0';

begin

  wr_data        <= wr_en and not full_o;
  rd_data        <= rd_en and not empty_o;
  rd_counter     <= std_logic_vector(ptr_cntr);
  full           <= full_o;
  empty          <= empty_o;
  almost_empty   <= almost_empty_o;
  --
  full_o         <= '1' when ptr_cntr = CNTR_MAX  else '0';
  empty_o        <= '1' when ptr_cntr = CNTR_NULL else '0';
  almost_empty_o <= '1' when ptr_cntr = CNTR_ONE  else '0';

  p_rd_data : process (clk)
  begin
    if rising_edge(clk) then
      dout <= fifo(to_integer(ptr_rd));
    end if;
  end process;

  p_wr_data : process (clk)
  begin
    if rising_edge(clk) then
      if (wr_data = '1') then
        fifo(to_integer(ptr_wr)) <= din;
      end if;
    end if;
  end process;

  p_ptr_wr : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ptr_wr <= (others => '0');
      else
        if (wr_data = '1') then
          ptr_wr <= ptr_wr + to_unsigned(1, FIFO_DEPTH);
        end if;
      end if;
    end if;
  end process;

  p_ptr_rd : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ptr_rd <= (others => '0');
      else
        if (rd_data = '1') then
          ptr_rd <= ptr_rd + to_unsigned(1, FIFO_DEPTH);
        end if;
      end if;
    end if;
  end process;

  p_ptr_cntr : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ptr_cntr <= (others => '0');
      else
        if wr_data = '1' and rd_data = '0' then
          ptr_cntr <= ptr_cntr + to_unsigned(1, FIFO_DEPTH);
        elsif wr_data = '0' and rd_data = '1' then
          ptr_cntr <= ptr_cntr - to_unsigned(1, FIFO_DEPTH);
        else
          ptr_cntr <= ptr_cntr;
        end if;
      end if;
    end if;
  end process;

end rtl;
