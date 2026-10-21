-- Four-channel raw ADC interface extracted from TOP_V2.
-- Automatic PN9 startup: see ../README.md and setup_adc_autostart.tcl.
-- Generate the clock IP using create_adc_xung_clk.tcl.
-- Main top: ADC_orihard. Receiver and clock/reset helpers are included below.
-- No ILA, DC filter or FIFO IP is required by this raw-data interface.
-- See ADC_ALIGN_VIO.md for channel mapping and project integration.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.adc_training_pkg.all;

library UNISIM;
use UNISIM.VComponents.all;

entity ADC_orihard_receiver is
    generic (is_clk_inverted : std_logic := '0';
             ALIGN_MODE_INIT : std_logic_vector(2 downto 0) := "001");
    port (
        clk_200m : in  std_logic;
        Proc_Clk_333M : in  std_logic;
        SYS_RST : in  std_logic;
        IDELAY_RST : in std_logic;
        align_mode_async : in std_logic_vector(2 downto 0);
        align_apply_async : in std_logic;
        train_enable_async : in std_logic;
        run_ready_async : in std_logic;
        trained, training_failed : out std_logic;
        debug_mode : out std_logic_vector(2 downto 0);
        debug_tap : out std_logic_vector(8 downto 0);

        -- ADC differential clock
        AD_DCO_P : in  std_logic;
        AD_DCO_N : in  std_logic;

        -- ADC differential over-range
        AD_DOR_P : in  std_logic;
        AD_DOR_N : in  std_logic;

        -- ADC differential data
        AD_D0_P  : in  std_logic;
        AD_D0_N  : in  std_logic;

        AD_D2_P  : in  std_logic;
        AD_D2_N  : in  std_logic;

        AD_D4_P  : in  std_logic;
        AD_D4_N  : in  std_logic;

        AD_D6_P  : in  std_logic;
        AD_D6_N  : in  std_logic;

        AD_D8_P  : in  std_logic;
        AD_D8_N  : in  std_logic;

        AD_D10_P : in  std_logic;
        AD_D10_N : in  std_logic;

        AD_D12_P : in  std_logic;
        AD_D12_N : in  std_logic;

        AD_D14_P : in  std_logic;
        AD_D14_N : in  std_logic;

        ------------------------------------------------------------
        -- Outputs
        ------------------------------------------------------------
        ADC_DATA_OUT : out std_logic_vector(15 downto 0);
        ADC_CLK_OUT  : out std_logic
    );
end ADC_orihard_receiver;


architecture RTL of ADC_orihard_receiver is

    ------------------------------------------------------------
    -- Differential input signals
    ------------------------------------------------------------
    signal data_0  : std_logic;
    signal data_2  : std_logic;
    signal data_4  : std_logic;
    signal data_6  : std_logic;
    signal data_8  : std_logic;
    signal data_10 : std_logic;
    signal data_12 : std_logic;
    signal data_14 : std_logic;

    signal ad_clk  : std_logic;
    -- Asynchronous assertion, local-DCO synchronous release for IDDRE1.
    signal adc_rst_sync : std_logic_vector(2 downto 0) := (others => '1');
    attribute ASYNC_REG : string;
    attribute SHREG_EXTRACT : string;
    attribute ASYNC_REG of adc_rst_sync : signal is "TRUE";
    attribute SHREG_EXTRACT of adc_rst_sync : signal is "NO";

    signal data_or : std_logic;

    ------------------------------------------------------------
    -- ADC DDR signals
    ------------------------------------------------------------
    signal ad_data_temp : std_logic_vector(7 downto 0);
    signal ad_data_temp_Delayed : std_logic_vector(7 downto 0);

    signal ad_in_odd  : std_logic_vector(7 downto 0);
    signal ad_in_even : std_logic_vector(7 downto 0);

    signal mode_meta, mode_sync : std_logic_vector(2 downto 0) := ALIGN_MODE_INIT;
    signal apply_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal apply_seen : std_logic := '0';
    signal train_sync, run_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal manual_pulse : std_logic;
    signal capture_clk, delay_ready, delay_vtc, vtc_request : std_logic;
    signal delay_loads : std_logic_vector(7 downto 0);
    signal delay_counts, delay_values : std_logic_vector(71 downto 0);
    signal delay_target : std_logic_vector(8 downto 0);
    signal delay_lane_targets : std_logic_vector(71 downto 0);
    signal deskew_active : std_logic;
    signal deskew_lane_fail : std_logic_vector(7 downto 0);
    attribute ASYNC_REG of mode_meta, mode_sync, apply_sync, train_sync, run_sync : signal is "TRUE";
    attribute SHREG_EXTRACT of mode_meta, mode_sync, apply_sync, train_sync, run_sync : signal is "NO";

    ------------------------------------------------------------
    -- Final ADC data
    ------------------------------------------------------------
    signal ad_data : std_logic_vector(15 downto 0);

begin

    reset_normal : if is_clk_inverted = '0' generate
        process(ad_clk, SYS_RST)
        begin
            if SYS_RST = '1' then
                adc_rst_sync <= (others => '1');
            elsif rising_edge(ad_clk) then
                adc_rst_sync <= adc_rst_sync(1 downto 0) & '0';
            end if;
        end process;
    end generate;

    reset_inverted : if is_clk_inverted = '1' generate
        process(ad_clk, SYS_RST)
        begin
            if SYS_RST = '1' then
                adc_rst_sync <= (others => '1');
            elsif falling_edge(ad_clk) then
                adc_rst_sync <= adc_rst_sync(1 downto 0) & '0';
            end if;
        end process;
    end generate;


    ----------------------------------------------------------------
    -- ADC DATA bit 0
    ----------------------------------------------------------------
    IBUFDS_inst_0 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_0,
            I  => AD_D0_P,
            IB => AD_D0_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 2
    ----------------------------------------------------------------
    IBUFDS_inst_2 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_2,
            I  => AD_D2_P,
            IB => AD_D2_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 4
    ----------------------------------------------------------------
    IBUFDS_inst_4 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_4,
            I  => AD_D4_P,
            IB => AD_D4_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 6
    ----------------------------------------------------------------
    IBUFDS_inst_6 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_6,
            I  => AD_D6_P,
            IB => AD_D6_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 8
    ----------------------------------------------------------------
    IBUFDS_inst_8 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_8,
            I  => AD_D8_P,
            IB => AD_D8_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 10
    ----------------------------------------------------------------
    IBUFDS_inst_10 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_10,
            I  => AD_D10_P,
            IB => AD_D10_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 12
    ----------------------------------------------------------------
    IBUFDS_inst_12 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_12,
            I  => AD_D12_P,
            IB => AD_D12_N
        );


    ----------------------------------------------------------------
    -- ADC DATA bit 14
    ----------------------------------------------------------------
    IBUFDS_inst_14 : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_14,
            I  => AD_D14_P,
            IB => AD_D14_N
        );


    ----------------------------------------------------------------
    -- ADC DCO clock
    ----------------------------------------------------------------
    IBUFDS_inst_clk : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => ad_clk,
            I  => AD_DCO_P,
            IB => AD_DCO_N
        );


    ----------------------------------------------------------------
    -- ADC DOR
    ----------------------------------------------------------------
    IBUFDS_inst_or : IBUFDS
        generic map (
            DQS_BIAS => "TRUE"
        )
        port map (
            O  => data_or,
            I  => AD_DOR_P,
            IB => AD_DOR_N
        );


    ----------------------------------------------------------------
    -- Combine ADC input bits
    --
    -- bit 7 = D14
    -- bit 6 = D12
    -- bit 5 = D10
    -- bit 4 = D8
    -- bit 3 = D6
    -- bit 2 = D4
    -- bit 1 = D2
    -- bit 0 = D0
    ----------------------------------------------------------------
    ad_data_temp <=
        data_14 &
        data_12 &
        data_10 &
        data_8  &
        data_6  &
        data_4  &
        data_2  &
        data_0;

 GEN_IDELAYE3 : for pin_count in 0 to 7 generate


  IDELAYE3_ADC_inst : IDELAYE3
   generic map (
      CASCADE => "NONE",          -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
      DELAY_FORMAT => "TIME",     -- Units of the DELAY_VALUE (COUNT, TIME)
      DELAY_SRC => "IDATAIN",     -- Delay input (DATAIN, IDATAIN)
      DELAY_TYPE => "VAR_LOAD",      -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      DELAY_VALUE => 34,           -- Input delay value setting
      IS_CLK_INVERTED => '0',     -- Optional inversion for CLK
      IS_RST_INVERTED => '0',     -- Optional inversion for RST
      REFCLK_FREQUENCY => 333.3333,  -- IDELAYCTRL clock input frequency in MHz (200.0-800.0)
      SIM_DEVICE => "ULTRASCALE_PLUS", -- Match the xcvu9p UltraScale+ device in simulation.
      UPDATE_MODE => "ASYNC"      -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
   )
   port map (
      CASC_OUT => open,       -- 1-bit output: Cascade delay output to ODELAY input cascade
      CNTVALUEOUT => delay_counts(9*pin_count+8 downto 9*pin_count), -- 9-bit output: Counter value output
      DATAOUT => ad_data_temp_Delayed(pin_count),         -- 1-bit output: Delayed data output
      CASC_IN => '0',         -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
      CASC_RETURN => '0', -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
      CE => '0',                   -- 1-bit input: Active-High enable increment/decrement input
      CLK => capture_clk,                 -- 1-bit input: Clock input
      CNTVALUEIN => delay_values(9*pin_count+8 downto 9*pin_count),   -- 9-bit input: Counter value input
      DATAIN => '0',           -- 1-bit input: Data input from the logic
      EN_VTC => delay_vtc,           -- 1-bit input: Keep delay constant over VT
      IDATAIN => ad_data_temp(pin_count),         -- 1-bit input: Data input from the IOBUF
      INC => '0',                 -- 1-bit input: Increment / Decrement tap delay input
      LOAD => delay_loads(pin_count),               -- 1-bit input: Load DELAY_VALUE input
      RST => IDELAY_RST              -- Released before IDELAYCTRL reset, not gated by RDY.
   );  
   end generate GEN_IDELAYE3;
    ----------------------------------------------------------------
    -- IDDRE1
    --
    -- Capture both edges of ADC DCO
    ----------------------------------------------------------------
 clk_NOT_inverted: if is_clk_inverted = '0' generate
 
 GEN_IDDRE1 : for pin_count in 0 to 7 generate
   
        IDDRE1_inst : IDDRE1
            generic map (
                DDR_CLK_EDGE  => "SAME_EDGE_PIPELINED",

                -- CB is internally inverted
                IS_CB_INVERTED => '1',

                -- C is not inverted
                IS_C_INVERTED  => '0'
            )
            port map (
                Q1 => ad_in_odd(pin_count),
                Q2 => ad_in_even(pin_count),

                C  => ad_clk,
                CB => ad_clk,

                D  => ad_data_temp_Delayed(pin_count),

                R  => adc_rst_sync(2)
            );

    end generate GEN_IDDRE1;
    end generate clk_NOT_inverted;
 clk_Inverted: if is_clk_inverted = '1' generate
 
 GEN_IDDRE1 : for pin_count in 0 to 7 generate
   
        IDDRE1_inst : IDDRE1
            generic map (
                DDR_CLK_EDGE  => "SAME_EDGE_PIPELINED",

                -- Capture on the opposite DCO edge in this optional variant.
                IS_CB_INVERTED => '0',

                IS_C_INVERTED  => '1'
            )
            port map (
                Q1 => ad_in_odd(pin_count),
                Q2 => ad_in_even(pin_count),

                C  => ad_clk,
                CB => ad_clk,

                D  => ad_data_temp_Delayed(pin_count),

                R  => adc_rst_sync(2)
            );

    end generate GEN_IDDRE1;
    end generate clk_inverted;

    ----------------------------------------------------------------
    -- All calibration and sample logic uses this channel's capture clock.
    capture_clk <= ad_clk when is_clk_inverted = '0' else not ad_clk;
    debug_tap <= delay_target;
    manual_pulse <= apply_sync(2) xor apply_seen;
    process(capture_clk, adc_rst_sync)
    begin
        if adc_rst_sync(2) = '1' then
            mode_meta <= ALIGN_MODE_INIT; mode_sync <= ALIGN_MODE_INIT;
            apply_sync <= (others => '0'); apply_seen <= '0';
            train_sync <= (others => '0'); run_sync <= (others => '0');
        elsif rising_edge(capture_clk) then
            mode_meta <= align_mode_async; mode_sync <= mode_meta;
            apply_sync <= apply_sync(1 downto 0) & align_apply_async;
            apply_seen <= apply_sync(2);
            train_sync <= train_sync(0) & train_enable_async;
            run_sync <= run_sync(0) & run_ready_async;
        end if;
    end process;
    -- Each physical ADC uses its own DCO. The common-tap scan is retained;
    -- unsuccessful scans fall back to independent lane eye centers.
    u_delay_loader : entity work.adc_idelay_loader
        generic map (PER_LANE => true)
        port map (clk => capture_clk, rst => adc_rst_sync(2),
                  vtc_request => vtc_request, target => delay_target,
                  counts => delay_counts, values => delay_values,
                  loads => delay_loads, en_vtc => delay_vtc, ready => delay_ready,
                  lane_targets => delay_lane_targets);
    u_trainer : entity work.adc_lane_pn9_trainer
        port map (clk => capture_clk, rst => adc_rst_sync(2),
                  enable => train_sync(1), delay_ready => delay_ready,
                  q1 => ad_in_odd, q2 => ad_in_even,
                  manual_mode => mode_sync, manual_apply => manual_pulse,
                  manual_enable => run_sync(1), tap_target => delay_target,
                  vtc_request => vtc_request, mode_out => debug_mode,
                  data_out => ad_data, done => trained, failed => training_failed,
                  lane_targets => delay_lane_targets, deskew_active => deskew_active,
                  lane_fail => deskew_lane_fail);

    -- Raw samples update on the edge selected by is_clk_inverted.
    ADC_DATA_OUT <= ad_data;
    ADC_CLK_OUT <= ad_clk;
end RTL;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Runs from the parent 100 MHz clock, never from the MMCM being recovered.
-- Resetting an unlocked MMCM from its own output clock can deadlock.
entity adc_clock_supervisor is
    generic (RESET_CYCLES : positive := 512;
             TIMEOUT_CYCLES : positive := 100000);
    port (clk, reset_n, locked_async, ready_async : in std_logic;
          mmcm_reset, locked_sync_out, ready_sync_out : out std_logic;
          debug_status : out std_logic_vector(15 downto 0));
end entity;

architecture rtl of adc_clock_supervisor is
    type clock_state is (reset_clock, wait_lock, wait_ready, healthy);
    signal state : clock_state := reset_clock;
    signal count : natural range 0 to TIMEOUT_CYCLES-1 := 0;
    signal locked_sync, ready_sync : std_logic_vector(1 downto 0) := "00";
    signal reset_release : std_logic_vector(2 downto 0) := "000";
    signal retries : unsigned(7 downto 0) := (others => '0');
    signal seen_lock, seen_ready : std_logic := '0';
    signal reset_reg : std_logic := '1';
    attribute ASYNC_REG : string;
    attribute SHREG_EXTRACT : string;
    attribute ASYNC_REG of locked_sync, ready_sync, reset_release : signal is "TRUE";
    attribute SHREG_EXTRACT of locked_sync, ready_sync, reset_release : signal is "NO";
begin
    assert RESET_CYCLES >= 4 and RESET_CYCLES <= TIMEOUT_CYCLES
        report "Invalid ADC clock supervisor timing" severity failure;
    -- A binary state decoder can glitch on wait_lock (01) -> wait_ready
    -- (10), momentarily decoding reset_clock (00). MMCM RST is asynchronous:
    -- keep it on one flip-flop, not a combinational state decode.
    mmcm_reset <= reset_reg;
    -- Export settled status into the same 100 MHz domain as the top-level ILA.
    locked_sync_out <= locked_sync(1);
    ready_sync_out <= ready_sync(1);
    debug_status(15 downto 8) <= std_logic_vector(retries);
    debug_status(7 downto 6) <= std_logic_vector(to_unsigned(clock_state'pos(state), 2));
    debug_status(5) <= seen_lock;
    debug_status(4) <= seen_ready;
    debug_status(3) <= '1' when state = reset_clock else '0';
    debug_status(2) <= reset_n;
    debug_status(1) <= locked_sync(1);
    debug_status(0) <= ready_sync(1);

    process(clk, reset_n)
    begin
        if reset_n = '0' then reset_release <= "000";
        elsif rising_edge(clk) then reset_release <= reset_release(1 downto 0) & '1'; end if;
    end process;

    process(clk, reset_n)
        variable retry : boolean;
    begin
        if reset_n = '0' then
            reset_reg <= '1';
            locked_sync <= "00"; ready_sync <= "00";
            state <= reset_clock; count <= 0;
            retries <= (others => '0'); seen_lock <= '0'; seen_ready <= '0';
        elsif rising_edge(clk) then
          if reset_release(2) = '0' then
            reset_reg <= '1';
            locked_sync <= "00"; ready_sync <= "00";
            state <= reset_clock; count <= 0;
            retries <= (others => '0'); seen_lock <= '0'; seen_ready <= '0';
          else
            locked_sync <= locked_sync(0) & locked_async;
            ready_sync <= ready_sync(0) & ready_async;
            if locked_sync(1) = '1' then seen_lock <= '1'; end if;
            if ready_sync(1) = '1' then seen_ready <= '1'; end if;
            retry := false;
            case state is
                when reset_clock =>
                    if count = RESET_CYCLES-1 then
                        state <= wait_lock; count <= 0; reset_reg <= '0';
                    else count <= count+1; end if;
                when wait_lock =>
                    if locked_sync(1) = '1' then state <= wait_ready; count <= 0;
                    elsif count = TIMEOUT_CYCLES-1 then retry := true;
                    else count <= count+1; end if;
                when wait_ready =>
                    if locked_sync(1) = '0' then retry := true;
                    elsif ready_sync(1) = '1' then state <= healthy; count <= 0;
                    elsif count = TIMEOUT_CYCLES-1 then retry := true;
                    else count <= count+1; end if;
                when healthy =>
                    if locked_sync(1) = '0' then retry := true;
                    elsif ready_sync(1) = '1' then count <= 0;
                    elsif count = TIMEOUT_CYCLES-1 then retry := true;
                    else count <= count+1; end if;
            end case;
            if retry then
                reset_reg <= '1';
                state <= reset_clock; count <= 0;
                if retries /= 255 then retries <= retries+1; end if;
            end if;
          end if;
        end if;
    end process;
end architecture;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Assert even with a stopped MMCM output; release only in the 333 MHz domain.
entity adc_delay_reset_sequencer is
    generic (DELAY_WAIT : positive := 32; CTRL_WAIT : positive := 64);
    port (clk, rst : in std_logic;
          delay_reset, ctrl_reset : out std_logic);
end entity;
architecture rtl of adc_delay_reset_sequencer is
    signal reset_release : std_logic_vector(2 downto 0) := "111";
    signal count : natural range 0 to CTRL_WAIT-1 := 0;
    attribute ASYNC_REG : string;
    attribute SHREG_EXTRACT : string;
    attribute ASYNC_REG of reset_release : signal is "TRUE";
    attribute SHREG_EXTRACT of reset_release : signal is "NO";
begin
    assert CTRL_WAIT > DELAY_WAIT report "Release IDELAYE3 before IDELAYCTRL" severity failure;
    process(clk, rst)
    begin
        if rst = '1' then reset_release <= "111";
        elsif rising_edge(clk) then reset_release <= reset_release(1 downto 0) & '0'; end if;
    end process;
    process(clk, reset_release)
    begin
        if reset_release(2) = '1' then
            count <= 0; delay_reset <= '1'; ctrl_reset <= '1';
        elsif rising_edge(clk) then
            if count >= DELAY_WAIT-1 then delay_reset <= '0'; end if;
            if count = CTRL_WAIT-1 then ctrl_reset <= '0';
            else count <= count+1; end if;
        end if;
    end process;
end architecture;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.adc_training_pkg.all;
library UNISIM;
use UNISIM.VComponents.all;
entity ADC_orihard is
    port (

        ----------------------------------------------------------------
        -- System Clock / Reset
        ----------------------------------------------------------------
        sys_clk   : in std_logic; -- Parent buffered 100 MHz clock
        rst_n     : in std_logic;

        ----------------------------------------------------------------
        -- AD9516
        ----------------------------------------------------------------
        CpSl_AD9516_Sclk_o    : out std_logic;
        CpSl_AD9516_nCS_o     : out std_logic;
        CpSl_AD9516_SDO_i     : in  std_logic;
        CpSl_AD9516_SDIO_o    : out std_logic;
        CpSl_AD9516_nRst_o    : out std_logic;

        CpSl_AD9516_REF_SEL_o : out std_logic;
        CpSl_AD9516_nSYNC_o   : out std_logic;
        CpSl_AD9516_LD_i      : in  std_logic;

        ----------------------------------------------------------------
        -- ADC1
        ----------------------------------------------------------------
        AD1_DCO_P : in std_logic;
        AD1_DCO_N : in std_logic;

        AD1_DOR_P : in std_logic;
        AD1_DOR_N : in std_logic;

        AD1_D0_P  : in std_logic;
        AD1_D0_N  : in std_logic;
        AD1_D2_P  : in std_logic;
        AD1_D2_N  : in std_logic;
        AD1_D4_P  : in std_logic;
        AD1_D4_N  : in std_logic;
        AD1_D6_P  : in std_logic;
        AD1_D6_N  : in std_logic;
        AD1_D8_P  : in std_logic;
        AD1_D8_N  : in std_logic;
        AD1_D10_P : in std_logic;
        AD1_D10_N : in std_logic;
        AD1_D12_P : in std_logic;
        AD1_D12_N : in std_logic;
        AD1_D14_P : in std_logic;
        AD1_D14_N : in std_logic;

        AD1_CSB  : out std_logic;
        AD1_SCLK : out std_logic;
        AD1_SDIO : out std_logic;


        ----------------------------------------------------------------
        -- ADC2
        ----------------------------------------------------------------
        AD2_DCO_P : in std_logic;
        AD2_DCO_N : in std_logic;

        AD2_DOR_P : in std_logic;
        AD2_DOR_N : in std_logic;

        AD2_D0_P  : in std_logic;
        AD2_D0_N  : in std_logic;
        AD2_D2_P  : in std_logic;
        AD2_D2_N  : in std_logic;
        AD2_D4_P  : in std_logic;
        AD2_D4_N  : in std_logic;
        AD2_D6_P  : in std_logic;
        AD2_D6_N  : in std_logic;
        AD2_D8_P  : in std_logic;
        AD2_D8_N  : in std_logic;
        AD2_D10_P : in std_logic;
        AD2_D10_N : in std_logic;
        AD2_D12_P : in std_logic;
        AD2_D12_N : in std_logic;
        AD2_D14_P : in std_logic;
        AD2_D14_N : in std_logic;

        AD2_CSB  : out std_logic;
        AD2_SCLK : out std_logic;
        AD2_SDIO : out std_logic;

        ----------------------------------------------------------------
        -- ADC3
        ----------------------------------------------------------------
        AD3_DCO_P : in std_logic;
        AD3_DCO_N : in std_logic;

        AD3_DOR_P : in std_logic;
        AD3_DOR_N : in std_logic;

        AD3_D0_P  : in std_logic;
        AD3_D0_N  : in std_logic;
        AD3_D2_P  : in std_logic;
        AD3_D2_N  : in std_logic;
        AD3_D4_P  : in std_logic;
        AD3_D4_N  : in std_logic;
        AD3_D6_P  : in std_logic;
        AD3_D6_N  : in std_logic;
        AD3_D8_P  : in std_logic;
        AD3_D8_N  : in std_logic;
        AD3_D10_P : in std_logic;
        AD3_D10_N : in std_logic;
        AD3_D12_P : in std_logic;
        AD3_D12_N : in std_logic;
        AD3_D14_P : in std_logic;
        AD3_D14_N : in std_logic;

        AD3_CSB  : out std_logic;
        AD3_SCLK : out std_logic;
        AD3_SDIO : out std_logic;

        ----------------------------------------------------------------
        -- ADC4
        ----------------------------------------------------------------
        AD4_DCO_P : in std_logic;
        AD4_DCO_N : in std_logic;

        AD4_DOR_P : in std_logic;
        AD4_DOR_N : in std_logic;

        AD4_D0_P  : in std_logic;
        AD4_D0_N  : in std_logic;
        AD4_D2_P  : in std_logic;
        AD4_D2_N  : in std_logic;
        AD4_D4_P  : in std_logic;
        AD4_D4_N  : in std_logic;
        AD4_D6_P  : in std_logic;
        AD4_D6_N  : in std_logic;
        AD4_D8_P  : in std_logic;
        AD4_D8_N  : in std_logic;
        AD4_D10_P : in std_logic;
        AD4_D10_N : in std_logic;
        AD4_D12_P : in std_logic;
        AD4_D12_N : in std_logic;
        AD4_D14_P : in std_logic;
        AD4_D14_N : in std_logic;

        AD4_CSB  : out std_logic;
        AD4_SCLK : out std_logic;
        AD4_SDIO : out std_logic;

        ----------------------------------------------------------------
        -- Raw outputs, each in its own ADC DCO clock domain.
        ADC1_DATA : out std_logic_vector(15 downto 0);
        ADC2_DATA : out std_logic_vector(15 downto 0);
        ADC3_DATA : out std_logic_vector(15 downto 0);
        ADC4_DATA : out std_logic_vector(15 downto 0);
        ADC1_CLK  : out std_logic;
        ADC2_CLK  : out std_logic;
        ADC3_CLK  : out std_logic;
        ADC4_CLK  : out std_logic;
        IDELAY_READY : out std_logic;
        ADC_READY : out std_logic;
        ADC_TRAIN_FAILED : out std_logic;
        CLOCK_LOCKED : out std_logic
    );
end ADC_orihard;
architecture RTL of ADC_orihard is
    signal align_apply : std_logic_vector(0 downto 0);
    signal align_mode_ch1 : std_logic_vector(2 downto 0);
    signal align_mode_ch2 : std_logic_vector(2 downto 0);
    signal align_mode_ch3 : std_logic_vector(2 downto 0);
    signal align_mode_ch4 : std_logic_vector(2 downto 0);
    component vio_adc_align is
        port (clk : in std_logic;
              probe_in0, probe_in1, probe_in2, probe_in3 : in std_logic_vector(15 downto 0);
              probe_out0 : out std_logic_vector(2 downto 0);
              probe_out1 : out std_logic_vector(2 downto 0);
              probe_out2 : out std_logic_vector(2 downto 0);
              probe_out3 : out std_logic_vector(2 downto 0);
              probe_out4 : out std_logic_vector(0 downto 0));
    end component;

    type mode_array is array(0 to 3) of std_logic_vector(2 downto 0);
    type tap_array is array(0 to 3) of std_logic_vector(8 downto 0);
    type status_array is array(0 to 3) of std_logic_vector(15 downto 0);
    signal learned_mode : mode_array;
    signal learned_tap : tap_array;
    signal status_raw, status_meta, status_sync : status_array := (others => (others => '0'));
    signal train_done, train_fail : std_logic_vector(3 downto 0);
    signal train_enable, startup_ready, startup_fail, receiver_reset : std_logic;
    signal adc_spi_clk, adc_spi_csn, adc_spi_data : std_logic;
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of status_meta, status_sync : signal is "TRUE";
    -- clk_25m is a legacy name: the Clocking Wizard actually supplies 20 MHz.
    signal clk_25m, clk_200m, Proc_Clk_333M : std_logic;
    signal sys_locked, sys_reset, adc_reset_n : std_logic;
    signal pll_control_reset_n, startup_reset_n : std_logic;
    signal Power_on_rst : std_logic := '1';
    signal delay_reset : std_logic := '1';
    signal IDELAY_CTRL_RDY : std_logic;
    signal delay_reset_request : std_logic;
    signal clock_status : std_logic_vector(15 downto 0);
    attribute MARK_DEBUG : string;
    -- Keep debug on registered status only. MARK_DEBUG on IDELAYCTRL.RDY
    -- adds DONT_TOUCH and prevents the placer's per-bank controller replication.
    attribute MARK_DEBUG of clock_status : signal is "TRUE";
    component adc_xung_clk is
        port (
            clk_out1  : out std_logic;
            clk_out2  : out std_logic;
            clk_out3  : out std_logic;
            clk_out4  : out std_logic;
            reset     : in  std_logic;
            locked    : out std_logic;
            clk_in1   : in  std_logic
        );
    end component;
begin
    u_vio_adc_align : vio_adc_align
        port map (clk => clk_200m,
                  probe_in0 => status_sync(0),
                  probe_in1 => status_sync(1),
                  probe_in2 => status_sync(2),
                  probe_in3 => status_sync(3),
                  probe_out0 => align_mode_ch1,
                  probe_out1 => align_mode_ch2,
                  probe_out2 => align_mode_ch3,
                  probe_out3 => align_mode_ch4,
                  probe_out4 => align_apply);

    u_clock_supervisor : entity work.adc_clock_supervisor
        port map (clk => sys_clk, reset_n => rst_n,
                  locked_async => sys_locked, ready_async => IDELAY_CTRL_RDY,
                  mmcm_reset => sys_reset, locked_sync_out => CLOCK_LOCKED,
                  ready_sync_out => IDELAY_READY, debug_status => clock_status);
    -- ADC startup waits for PLL lock. The AD9516 SPI controller must run
    -- before that lock exists, so it has a separate reset below.
    adc_reset_n <= rst_n and sys_locked and CpSl_AD9516_LD_i;
    pll_control_reset_n <= sys_locked and not sys_reset;
    startup_reset_n <= adc_reset_n and not Power_on_rst;
    -- Consumers must wait for ADC_READY; raw outputs also contain test data
    -- during calibration. Each ADC_DATA output belongs to its own ADC_CLK.
    ADC_READY <= startup_ready;
    ADC_TRAIN_FAILED <= startup_fail;
    receiver_reset <= Power_on_rst or not adc_reset_n or not IDELAY_CTRL_RDY;
    status_gen : for ch in 0 to 3 generate
        -- [15] trained, [14] channel failure, [13] RUN, [12] startup failure,
        -- [11:9] active mode, [8:0] selected tap (not instantaneous VTC count).
        status_raw(ch) <= train_done(ch) & train_fail(ch) & startup_ready & startup_fail
                          & learned_mode(ch) & learned_tap(ch);
    end generate;
    process(clk_200m)
    begin
        if rising_edge(clk_200m) then status_meta <= status_raw; status_sync <= status_meta; end if;
    end process;
    -- UG571 component reset order: release IDELAYE3 before IDELAYCTRL.
    -- EN_VTC stays high while receiver/application reset waits for RDY.
    -- Startup's 100 ms wait also exceeds the required post-RDY 64 cycles.
    delay_reset_request <= not rst_n or not sys_locked or sys_reset;
    u_delay_reset_sequencer : entity work.adc_delay_reset_sequencer
        port map (clk => Proc_Clk_333M, rst => delay_reset_request,
                  delay_reset => delay_reset, ctrl_reset => Power_on_rst);
    U_CLK : adc_xung_clk
        port map (
            clk_out1  => clk_25m,
            clk_out2  => open,
            clk_out3  => clk_200m,
            clk_out4  => Proc_Clk_333M,

            reset     => sys_reset,
            locked    => sys_locked,

            clk_in1   => sys_clk
        );
 IDELAYCTRL_inst : IDELAYCTRL
   generic map (
      SIM_DEVICE => "ULTRASCALE"  -- Set the device version for simulation functionality (ULTRASCALE)
   )
   port map (
      RDY => IDELAY_CTRL_RDY,       -- 1-bit output: Ready output
      REFCLK => Proc_Clk_333M, -- 1-bit input: Reference clock input
      RST => Power_on_rst        -- 1-bit input: Active-High reset input. Asynchronous assert, synchronous deassert to
                        -- REFCLK
   );

    U_M_AD9516_Ctrl : entity work.M_AD9516_Ctrl
        port map (
            S6_25MCLK   => clk_25m,
            SYS_RSTn    => pll_control_reset_n,

            PLL_RESET   => CpSl_AD9516_nRst_o,
            PLL_SCK     => CpSl_AD9516_Sclk_o,
            PLL_CSN     => CpSl_AD9516_nCS_o,
            PLL_SDIO    => CpSl_AD9516_SDIO_o,
            PLL_SDO     => CpSl_AD9516_SDO_i,
            PLL_LD      => CpSl_AD9516_LD_i,
            PLL_REF_sel => CpSl_AD9516_REF_SEL_o,
            PLL_PD      => open,
            PLL_SYNCN   => CpSl_AD9516_nSYNC_o,
            LED_LD      => open,
            PLL_REFMON  => open
        );


    ----------------------------------------------------------------
    -- Configure all four ADCs identically, train independently, then leave PN9.
    -- SPI control runs from the 20 MHz control clock, independent of each
    -- ADC DCO. RUN is released only after all four local trainers succeed.
    u_startup : entity work.ad9467_startup
        port map (clk => clk_25m, reset_n => startup_reset_n,
                  clocks_ready => IDELAY_CTRL_RDY,
                  trained_async => train_done, failed_async => train_fail,
                  spi_clk => adc_spi_clk, spi_csn => adc_spi_csn, spi_data => adc_spi_data,
                  train_enable => train_enable, run_ready => startup_ready,
                  startup_failed => startup_fail);
    AD1_SCLK <= adc_spi_clk; AD2_SCLK <= adc_spi_clk;
    AD3_SCLK <= adc_spi_clk; AD4_SCLK <= adc_spi_clk;
    AD1_CSB <= adc_spi_csn; AD2_CSB <= adc_spi_csn;
    AD3_CSB <= adc_spi_csn; AD4_CSB <= adc_spi_csn;
    AD1_SDIO <= adc_spi_data; AD2_SDIO <= adc_spi_data;
    AD3_SDIO <= adc_spi_data; AD4_SDIO <= adc_spi_data;

    u_ad1 : entity work.ADC_orihard_receiver
        Generic map (is_clk_inverted => '0', ALIGN_MODE_INIT => "100")
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => receiver_reset,
            IDELAY_RST => delay_reset,
            align_mode_async => align_mode_ch1,
            align_apply_async => align_apply(0),
            train_enable_async => train_enable, run_ready_async => startup_ready,
            trained => train_done(0), training_failed => train_fail(0),
            debug_mode => learned_mode(0), debug_tap => learned_tap(0),

            AD_DCO_P => AD1_DCO_P,
            AD_DCO_N => AD1_DCO_N,

            AD_DOR_P => AD1_DOR_P,
            AD_DOR_N => AD1_DOR_N,

            AD_D0_P  => AD1_D0_P,
            AD_D0_N  => AD1_D0_N,

            AD_D2_P  => AD1_D2_P,
            AD_D2_N  => AD1_D2_N,

            AD_D4_P  => AD1_D4_P,
            AD_D4_N  => AD1_D4_N,

            AD_D6_P  => AD1_D6_P,
            AD_D6_N  => AD1_D6_N,

            AD_D8_P  => AD1_D8_P,
            AD_D8_N  => AD1_D8_N,

            AD_D10_P => AD1_D10_P,
            AD_D10_N => AD1_D10_N,

            AD_D12_P => AD1_D12_P,
            AD_D12_N => AD1_D12_N,

            AD_D14_P => AD1_D14_P,
            AD_D14_N => AD1_D14_N,

            ADC_DATA_OUT => ADC1_DATA,
            ADC_CLK_OUT  => ADC1_CLK
        );


    ----------------------------------------------------------------
    -- ADC2 DATA
    ----------------------------------------------------------------
    u_ad2 : entity work.ADC_orihard_receiver
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => receiver_reset,
            IDELAY_RST => delay_reset,
            align_mode_async => align_mode_ch2,
            align_apply_async => align_apply(0),
            train_enable_async => train_enable, run_ready_async => startup_ready,
            trained => train_done(1), training_failed => train_fail(1),
            debug_mode => learned_mode(1), debug_tap => learned_tap(1),

            AD_DCO_P => AD2_DCO_P,
            AD_DCO_N => AD2_DCO_N,

            AD_DOR_P => AD2_DOR_P,
            AD_DOR_N => AD2_DOR_N,

            AD_D0_P  => AD2_D0_P,
            AD_D0_N  => AD2_D0_N,

            AD_D2_P  => AD2_D2_P,
            AD_D2_N  => AD2_D2_N,

            AD_D4_P  => AD2_D4_P,
            AD_D4_N  => AD2_D4_N,

            AD_D6_P  => AD2_D6_P,
            AD_D6_N  => AD2_D6_N,

            AD_D8_P  => AD2_D8_P,
            AD_D8_N  => AD2_D8_N,

            AD_D10_P => AD2_D10_P,
            AD_D10_N => AD2_D10_N,

            AD_D12_P => AD2_D12_P,
            AD_D12_N => AD2_D12_N,

            AD_D14_P => AD2_D14_P,
            AD_D14_N => AD2_D14_N,

            ADC_DATA_OUT => ADC2_DATA,
            ADC_CLK_OUT  => ADC2_CLK
        );


    ----------------------------------------------------------------
    -- ADC3 DATA
    ----------------------------------------------------------------
    u_ad3 : entity work.ADC_orihard_receiver
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => receiver_reset,
            IDELAY_RST => delay_reset,
            align_mode_async => align_mode_ch3,
            align_apply_async => align_apply(0),
            train_enable_async => train_enable, run_ready_async => startup_ready,
            trained => train_done(2), training_failed => train_fail(2),
            debug_mode => learned_mode(2), debug_tap => learned_tap(2),

            AD_DCO_P => AD3_DCO_P,
            AD_DCO_N => AD3_DCO_N,

            AD_DOR_P => AD3_DOR_P,
            AD_DOR_N => AD3_DOR_N,

            AD_D0_P  => AD3_D0_P,
            AD_D0_N  => AD3_D0_N,

            AD_D2_P  => AD3_D2_P,
            AD_D2_N  => AD3_D2_N,

            AD_D4_P  => AD3_D4_P,
            AD_D4_N  => AD3_D4_N,

            AD_D6_P  => AD3_D6_P,
            AD_D6_N  => AD3_D6_N,

            AD_D8_P  => AD3_D8_P,
            AD_D8_N  => AD3_D8_N,

            AD_D10_P => AD3_D10_P,
            AD_D10_N => AD3_D10_N,

            AD_D12_P => AD3_D12_P,
            AD_D12_N => AD3_D12_N,

            AD_D14_P => AD3_D14_P,
            AD_D14_N => AD3_D14_N,

            ADC_DATA_OUT => ADC3_DATA,
            ADC_CLK_OUT  => ADC3_CLK
        );


    ----------------------------------------------------------------
    -- ADC4 DATA
    ----------------------------------------------------------------
    u_ad4 : entity work.ADC_orihard_receiver
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => receiver_reset,
            IDELAY_RST => delay_reset,
            align_mode_async => align_mode_ch4,
            align_apply_async => align_apply(0),
            train_enable_async => train_enable, run_ready_async => startup_ready,
            trained => train_done(3), training_failed => train_fail(3),
            debug_mode => learned_mode(3), debug_tap => learned_tap(3),

            AD_DCO_P => AD4_DCO_P,
            AD_DCO_N => AD4_DCO_N,

            AD_DOR_P => AD4_DOR_P,
            AD_DOR_N => AD4_DOR_N,

            AD_D0_P  => AD4_D0_P,
            AD_D0_N  => AD4_D0_N,

            AD_D2_P  => AD4_D2_P,
            AD_D2_N  => AD4_D2_N,

            AD_D4_P  => AD4_D4_P,
            AD_D4_N  => AD4_D4_N,

            AD_D6_P  => AD4_D6_P,
            AD_D6_N  => AD4_D6_N,

            AD_D8_P  => AD4_D8_P,
            AD_D8_N  => AD4_D8_N,

            AD_D10_P => AD4_D10_P,
            AD_D10_N => AD4_D10_N,

            AD_D12_P => AD4_D12_P,
            AD_D12_N => AD4_D12_N,

            AD_D14_P => AD4_D14_P,
            AD_D14_N => AD4_D14_N,

            ADC_DATA_OUT => ADC4_DATA,
            ADC_CLK_OUT  => ADC4_CLK
        );

end RTL;

