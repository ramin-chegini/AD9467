library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity AD_DATA_v2 is
    generic (is_clk_inverted : std_logic:= '0');
    port (
        clk_200m : in  std_logic;
        Proc_Clk_333M : in  std_logic;
        SYS_RST : in  std_logic;
        data_val : in  std_logic;

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
end AD_DATA_v2;


architecture RTL of AD_DATA_v2 is

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
    signal data_or : std_logic;

    ------------------------------------------------------------
    -- ADC DDR signals
    ------------------------------------------------------------
    signal ad_data_temp : std_logic_vector(7 downto 0);
    signal ad_data_temp_Delayed : std_logic_vector(7 downto 0);

    signal ad_in_odd  : std_logic_vector(7 downto 0);
    signal ad_in_even : std_logic_vector(7 downto 0);

    signal ad_in_ev_dl : std_logic_vector(7 downto 0);

    ------------------------------------------------------------
    -- Final ADC data
    ------------------------------------------------------------
    signal ad_data : std_logic_vector(15 downto 0);

    signal ad_data_DCRemoved : std_logic_vector(15 downto 0);


    ------------------------------------------------------------
    -- DC Removal Component
    ------------------------------------------------------------
    component DC_Removal_v2 is
        port (
            Clk : in  std_logic;
            rst : in  std_logic;
            x   : in  std_logic_vector(15 downto 0);
            y   : out std_logic_vector(15 downto 0)
        );
    end component;


    ------------------------------------------------------------
    -- ILA Component
    ------------------------------------------------------------
    component ila_zb is
        port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(15 downto 0)
        );
    end component;


begin

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
      DELAY_TYPE => "FIXED",      -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      DELAY_VALUE => 34,           -- Input delay value setting
      IS_CLK_INVERTED => '0',     -- Optional inversion for CLK
      IS_RST_INVERTED => '0',     -- Optional inversion for RST
      REFCLK_FREQUENCY => 333.3333,  -- IDELAYCTRL clock input frequency in MHz (200.0-800.0)
      SIM_DEVICE => "ULTRASCALE", -- Set the device version for simulation functionality (ULTRASCALE)
      UPDATE_MODE => "ASYNC"      -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
   )
   port map (
      CASC_OUT => open,       -- 1-bit output: Cascade delay output to ODELAY input cascade
      CNTVALUEOUT => open, -- 9-bit output: Counter value output
      DATAOUT => ad_data_temp_Delayed(pin_count),         -- 1-bit output: Delayed data output
      CASC_IN => '0',         -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
      CASC_RETURN => '0', -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
      CE => '0',                   -- 1-bit input: Active-High enable increment/decrement input
      CLK => Proc_Clk_333M,                 -- 1-bit input: Clock input
      CNTVALUEIN => "000000000",   -- 9-bit input: Counter value input
      DATAIN => '0',           -- 1-bit input: Data input from the logic
      EN_VTC => '1',--EN_VTC,           -- 1-bit input: Keep delay constant over VT
      IDATAIN => ad_data_temp(pin_count),         -- 1-bit input: Data input from the IOBUF
      INC => '0',                 -- 1-bit input: Increment / Decrement tap delay input
      LOAD => '0',--ADC1_delay_update,               -- 1-bit input: Load DELAY_VALUE input
      RST => SYS_RST                 -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
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

                R  => SYS_RST
            );

    end generate GEN_IDDRE1;
    
      ----------------------------------------------------------------
    -- ADC 16-bit reconstruction
    ----------------------------------------------------------------
    process(ad_clk)
    begin

        if rising_edge(ad_clk) then

            --------------------------------------------------------
            -- Delay EVEN sample by one ADC clock
            --------------------------------------------------------
            ad_in_ev_dl <= ad_in_even;


            --------------------------------------------------------
            -- Select bit ordering
            --------------------------------------------------------
            if data_val = '1' then

                ad_data <=
                    ad_in_ev_dl(7) & ad_in_odd(7) &
                    ad_in_ev_dl(6) & ad_in_odd(6) &
                    ad_in_ev_dl(5) & ad_in_odd(5) &
                    ad_in_ev_dl(4) & ad_in_odd(4) &
                    ad_in_ev_dl(3) & ad_in_odd(3) &
                    ad_in_ev_dl(2) & ad_in_odd(2) &
                    ad_in_ev_dl(1) & ad_in_odd(1) &
                    ad_in_ev_dl(0) & ad_in_odd(0);

            else

                ad_data <=
                    ad_in_odd(7) & ad_in_even(7) &
                    ad_in_odd(6) & ad_in_even(6) &
                    ad_in_odd(5) & ad_in_even(5) &
                    ad_in_odd(4) & ad_in_even(4) &
                    ad_in_odd(3) & ad_in_even(3) &
                    ad_in_odd(2) & ad_in_even(2) &
                    ad_in_odd(1) & ad_in_even(1) &
                    ad_in_odd(0) & ad_in_even(0);

            end if;

        end if;

    end process;

    
    end generate clk_NOT_inverted;
 clk_Inverted: if is_clk_inverted = '1' generate
 
 GEN_IDDRE1 : for pin_count in 0 to 7 generate
   
        IDDRE1_inst : IDDRE1
            generic map (
                DDR_CLK_EDGE  => "SAME_EDGE_PIPELINED",

                -- CB is internally inverted
                IS_CB_INVERTED => '0',

                -- C is not inverted
                IS_C_INVERTED  => '1'
            )
            port map (
                Q1 => ad_in_odd(pin_count),
                Q2 => ad_in_even(pin_count),

                C  => ad_clk,
                CB => ad_clk,

                D  => ad_data_temp_Delayed(pin_count),

                R  => SYS_RST
            );

    end generate GEN_IDDRE1;
    
      ----------------------------------------------------------------
    -- ADC 16-bit reconstruction
    ----------------------------------------------------------------
    process(ad_clk)
    begin

        if falling_edge(ad_clk) then

            --------------------------------------------------------
            -- Delay EVEN sample by one ADC clock
            --------------------------------------------------------
            ad_in_ev_dl <= ad_in_even;


            --------------------------------------------------------
            -- Select bit ordering
            --------------------------------------------------------
            if data_val = '1' then

                ad_data <=
                    ad_in_ev_dl(7) & ad_in_odd(7) &
                    ad_in_ev_dl(6) & ad_in_odd(6) &
                    ad_in_ev_dl(5) & ad_in_odd(5) &
                    ad_in_ev_dl(4) & ad_in_odd(4) &
                    ad_in_ev_dl(3) & ad_in_odd(3) &
                    ad_in_ev_dl(2) & ad_in_odd(2) &
                    ad_in_ev_dl(1) & ad_in_odd(1) &
                    ad_in_ev_dl(0) & ad_in_odd(0);

            else

                ad_data <=
                    ad_in_odd(7) & ad_in_even(7) &
                    ad_in_odd(6) & ad_in_even(6) &
                    ad_in_odd(5) & ad_in_even(5) &
                    ad_in_odd(4) & ad_in_even(4) &
                    ad_in_odd(3) & ad_in_even(3) &
                    ad_in_odd(2) & ad_in_even(2) &
                    ad_in_odd(1) & ad_in_even(1) &
                    ad_in_odd(0) & ad_in_even(0);

            end if;

        end if;

    end process;

    
 end generate clk_inverted;


  

    ----------------------------------------------------------------
    -- DC Removal
    --
    -- Reset is permanently disabled, exactly like:
    -- .rst(1'b0)
    ----------------------------------------------------------------
    DC_Remover_ADC : DC_Removal_v2
        port map (
            Clk => ad_clk,
            rst => '0',
            x   => ad_data,
            y   => ad_data_DCRemoved
        );


    ----------------------------------------------------------------
    -- ILA : DC-Removed ADC data
    ----------------------------------------------------------------
    u_adc : ila_zb
        port map (
            clk    => ad_clk,
            probe0 => ad_data_DCRemoved
        );


    ----------------------------------------------------------------
    -- ILA : Raw ADC data
    ----------------------------------------------------------------
    u_adc1 : ila_zb
        port map (
            clk    => ad_clk,
            probe0 => ad_data
        );


    ----------------------------------------------------------------
    -- Module outputs
    ----------------------------------------------------------------

    -- Raw 16-bit reconstructed ADC data
    ADC_DATA_OUT <= ad_data_DCRemoved;

    -- ADC DCO after differential input buffer
    ADC_CLK_OUT <= ad_clk;


end RTL;