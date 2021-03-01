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
-- 1.0          2020            Teledyne-e2v Creation
-------------------------------------------------------------------------------
-- Description: odelaye3: ug571, UltraScale Architecture SelectIO Resources
----------------------------------------------------------------------------------------------------
--
-- -- VAR_LOAD Mode
--
-- The VAR_LOAD method is suitable for both COUNT and TIME mode usage of the delay line.
-- In both modes, the tap amount can be read from the CNTVALUEOUT bus and changed
-- through the CNTVALUEIN bus or INC port if necessary.
-- Note: The procedure to calculate the value to update the delay line is different for IDELAY and
-- ODELAY, and different for TIME and COUNT mode.
-- If DELAY_TYPE is VAR_LOAD and DELAY_FORMAT is TIME, the procedure to update the delay
-- line follows:
-- -- 
-- 1. Wait for DELAYCTRL.RDY to go High.
-- 2. Make EN_VTC Low to modify the delay line.
-- 3. Wait for at least 10 clock cycles.
-- 4. Read CNTVALUEOUT[8:0] and load the value into a register.
-- 5. Check if updating the delay line is necessary.
-- 6. Calculate the new delay value to be written in the delay line.
-- -- a. Increment or decrement the current tap position (Org_Val) by 8 taps for glitchless
-- -- transition. Jumps higher than 8 taps might result in the delay line jump causing data
-- -- to glitch.
-- -- Note: This step might require fewer than 8 taps.
-- -- b. Put the new delay line value on the CNTVALUEIN[8:0] bus.
-- -- c. Wait for one clock cycle and pulse LOAD High for a clock cycle.
-- -- d. Check if the new delay line value (New_Val) is reached.
-- -- - If not, wait 5 clock cycles and continue from step a.
-- -- - If so, continue to step 7.
-- or
-- -- a. Calculate the difference (Dif_Val) between New_Val and Org_Val and the direction to
-- --  step.
-- -- b. Make the INC input High or Low to increment or decrement the delay line.
-- -- c. Toggle the CE pin to execute the increment or decrement.
-- -- d. Decrement the Dif_Val and check if it is zero.
-- -- - If not continue from step a.
-- -- - If so, continue to step 7.
-- 7. Wait for at least 10 clock cycles.
-- 8. Set EN_VTC High for VT compensation.
-- 9. Go back to step 2 for a new delay line update.
--
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
    
entity odelaye3_wrapper is
  port (
    --! general    
    clk         : in  std_logic;
    refclk      : in  std_logic;
    rst         : in  std_logic;
    set_delay   : in  std_logic;
    in_delay    : in  std_logic_vector(8 downto 0);
    get_delay   : in  std_logic;
    out_delay   : out std_logic_vector(8 downto 0);
    sync        : in  std_logic;
    sync_odelay : out std_logic
    );
end;


architecture rtl of odelaye3_wrapper is

  signal idelayctrl_rdy    : std_logic                    := '0';
  signal out_delay_o       : std_logic_vector(8 downto 0) := (others => '0');
  signal in_delay_i        : std_logic_vector(8 downto 0) := (others => '0');
  signal odelaye3_en_vtc   : std_logic                    := '0';
  signal odelaye3_load     : std_logic                    := '0';
  --
  type t_state is (ST_SET_NEW_DELAY, ST_WAIT_1, ST_LOAD, ST_LOAD_WAIT, ST_LOAD_CE, ST_WAIT_2);
  signal state             : t_state;
  signal next_state        : t_state;
  --
  signal odelaye3_ce       : std_logic                    := '0';
  --
  signal cntr              : unsigned(3 downto 0)         := (others => '0');
  signal cntr_enable       : std_logic                    := '0';
  signal cntr_end          : std_logic                    := '0';
  signal cntr_end_d        : std_logic                    := '0';
  signal cntr_end_re       : std_logic                    := '0';
  -- 
  signal cntr_enable_i     : std_logic                    := '0';
  signal odelaye3_en_vtc_i : std_logic                    := '0';
  signal odelaye3_load_i   : std_logic                    := '0';
  signal odelaye3_ce_i     : std_logic                    := '0';
--
-- 
begin

  IDELAYCTRL_inst : IDELAYCTRL
    generic map (
      SIM_DEVICE => "ULTRASCALE"  -- Must be set to "ULTRASCALE"
      )
    port map (
      RDY    => idelayctrl_rdy,   -- 1-bit output: Ready output
      REFCLK => refclk,           -- 1-bit input: Reference clock input
      RST    => rst               -- 1-bit input: Active high reset input. Asynchronous assert, synchronous deassert to REFCLK.
      );
  
  -- --
  -- When the DELAY_FORMAT attribute is set to TIME mode, the DELAY_VALUE attribute
  -- represents time in ps. Unlike IDELAYE3, the ODELAYE3 has no clock/data align delay. The
  -- total delay through the ODELAYE3 is thus the value of the DELAY_VALUE.
  -- --
  -- In TIME mode, the DELAY_VALUE represents time in ps, but the value read or written from or
  -- to the delay line by the CNTVALUEIN[8:0] and/or CNTVALUEOU[8:0] is expressed in taps. So
  -- changing the time of a delay line requires some calculation, which is provided in the
  -- DELAY_MODE/VAR_LOAD paragraph of ug571 Xilinx technical documentation.
  -- When the DELAY_FORMAT attribute is set to COUNT mode, the DELAY_VALUE attribute represents
  -- an amount of taps.
  -- -- 
  ODELAYE3_inst : ODELAYE3
    generic map (
      CASCADE          => "NONE",        -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
      DELAY_FORMAT     => "TIME",        -- (COUNT, TIME): 0 to 1250 (TIME UltraScale), 0 to 1100 (TIME UltraScale+), 0 to 511 (COUNT)
      DELAY_TYPE       => "VAR_LOAD",    -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      DELAY_VALUE      => 40,            -- [ps] when TIME Output delay tap setting
      IS_CLK_INVERTED  => '0',           -- Optional inversion for CLK
      IS_RST_INVERTED  => '0',           -- Optional inversion for RST
      REFCLK_FREQUENCY => 300.0,         -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0).
      SIM_DEVICE       => "ULTRASCALE_PLUS",  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
      UPDATE_MODE      => "MANUAL"       -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
      )
    port map (
      CASC_OUT    => open,               -- 1-bit output: Cascade delay output to IDELAY input cascade
      CNTVALUEOUT => out_delay_o,        -- 9-bit output: Counter value output
      DATAOUT     => sync_odelay,        -- 1-bit output: Delayed data from ODATAIN input port
      CASC_IN     => '0',                -- 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
      CASC_RETURN => '0',                -- 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
      CE          => odelaye3_ce,        -- 1-bit input: Active high enable increment/decrement input
      CLK         => clk,                -- 1-bit input: Clock input
      CNTVALUEIN  => in_delay_i,           -- 9-bit input: Counter value input
      EN_VTC      => odelaye3_en_vtc,    -- 1-bit input: Keep delay constant over VT
      INC         => '0',                -- 1-bit input: Increment/Decrement tap delay input
      LOAD        => odelaye3_load,      -- 1-bit input: Load DELAY_VALUE input
      ODATAIN     => sync,               -- 1-bit input: Data input
      RST         => rst                 -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
      );

  out_delay <= out_delay_o;
  
  p_delay_in : process (clk)
  begin
    if rising_edge(clk) then
      if (get_delay = '1') and (cntr_end_re = '1') then
        in_delay_i <= out_delay_o;
      elsif (cntr_end_re = '1') then
        in_delay_i <= in_delay;
      else
        in_delay_i <= in_delay_i;
      end if;
    end if;
  end process;
  
  SYNC_PROC : process (clk)
  begin
    if rising_edge(clk) then
      if (rst = '1') then
        state           <= ST_SET_NEW_DELAY;
        odelaye3_en_vtc <= '1';
        odelaye3_load   <= '0';
        cntr_enable     <= '0';
        odelaye3_ce     <= '0';
      else
        state           <= next_state;
        odelaye3_en_vtc <= odelaye3_en_vtc_i;
        odelaye3_load   <= odelaye3_load_i;
        cntr_enable     <= cntr_enable_i;
        odelaye3_ce     <= odelaye3_ce_i;
      end if;
      
    end if;
  end process;

  --MOORE State-Machine - Outputs based on state only
  OUTPUT_DECODE : process (state)
  begin
    --insert statements to decode internal output signals
    --below is simple example
    if state = ST_SET_NEW_DELAY then
      cntr_enable_i     <= '0';
      odelaye3_en_vtc_i <= '1';
      odelaye3_load_i   <= '0';
      odelaye3_ce_i     <= '0';
    elsif state = ST_WAIT_1 then
      cntr_enable_i     <= '1';
      odelaye3_en_vtc_i <= '0';
      odelaye3_load_i   <= '0';
      odelaye3_ce_i     <= '0';
    elsif state = ST_LOAD then
      cntr_enable_i     <= '0';
      odelaye3_en_vtc_i <= '0';
      odelaye3_load_i   <= '1';
      odelaye3_ce_i     <= '0';
    elsif state = ST_LOAD_WAIT then
      cntr_enable_i     <= '0';
      odelaye3_en_vtc_i <= '0';
      odelaye3_load_i   <= '0';
      odelaye3_ce_i     <= '0';
    elsif state = ST_LOAD_CE then
      cntr_enable_i     <= '0';
      odelaye3_en_vtc_i <= '0';
      odelaye3_load_i   <= '1';
      odelaye3_ce_i     <= '1';
    else  --elsif state = ST_WAIT_2 then
      cntr_enable_i     <= '1';
      odelaye3_en_vtc_i <= '0';
      odelaye3_load_i   <= '0';
      odelaye3_ce_i     <= '0';
    end if;
  end process;

  NEXT_STATE_DECODE : process (state, idelayctrl_rdy, cntr_end_re, set_delay)
  begin
    next_state <= state;
    case (state) is

      when ST_SET_NEW_DELAY =>
        if idelayctrl_rdy = '1' and set_delay = '1' then
          next_state <= ST_WAIT_1;
        else
          next_state <= ST_SET_NEW_DELAY;
        end if;

      when ST_WAIT_1 =>
        if cntr_end_re = '0' then
          next_state <= ST_WAIT_1;
        else
          next_state <= ST_LOAD;
        end if;

      when ST_LOAD =>
        next_state <= ST_LOAD_WAIT;

      when ST_LOAD_WAIT =>
        next_state <= ST_LOAD_CE;

      when ST_LOAD_CE =>
        next_state <= ST_WAIT_2;

      when ST_WAIT_2 =>
        if cntr_end_re = '0' then
          next_state <= ST_WAIT_2;
        else
          next_state <= ST_SET_NEW_DELAY;
        end if;

      when others =>
        next_state <= ST_SET_NEW_DELAY;

    end case;
  end process;

  p_cntr : process(clk)
  begin
    if rising_edge(clk) then
      cntr_end_d  <= cntr_end;
      cntr_end_re <= cntr_end and not cntr_end_d;
      if cntr_enable = '1' then
        if cntr = 0 then
          cntr     <= cntr;
          cntr_end <= '1';
        else
          cntr     <= cntr-1;
          cntr_end <= '0';
        end if;
      else
        cntr     <= (others => '1');
        cntr_end <= '0';
      end if;
    end if;
  end process;

end;
