
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.conv_pkg.all;

library UNISIM;
use UNISIM.VComponents.all;


--====================================================================
-- TOP
--====================================================================
entity TOP_v2 is
    port (

        ----------------------------------------------------------------
        -- System Clock / Reset
        ----------------------------------------------------------------
        sys_clk_p : in std_logic;
        sys_clk_n : in std_logic;
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
        -- FMC Clock
        ----------------------------------------------------------------
        FMC_CLK1_P : in std_logic;
        FMC_CLK1_N : in std_logic;

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

        FMC_LED1 : out std_logic;
        FMC_LED2 : out std_logic;

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
        -- Trigger / Sync
        ----------------------------------------------------------------
        F_TRIG_IN_P : in std_logic;
        F_TRIG_IN_N : in std_logic;

        F_SYNC_P : in std_logic;
        F_SYNC_N : in std_logic;

        ----------------------------------------------------------------
        -- LEDs
        ----------------------------------------------------------------
        led : out std_logic_vector(3 downto 0)
    );
end TOP_v2;


architecture RTL of TOP_v2 is


    ----------------------------------------------------------------
    -- Clock signals
    ----------------------------------------------------------------
    signal clk_25m    : std_logic;
    signal clk_100m   : std_logic;
    signal clk_200m   : std_logic;
    signal Proc_Clk_333M   : std_logic;
    signal sys_locked : std_logic;

    signal ad_clk : std_logic;

    ----------------------------------------------------------------
    -- Sync / Trigger
    ----------------------------------------------------------------
    signal ad_sync  : std_logic;
    signal ad_sync2 : std_logic;

    ----------------------------------------------------------------
    -- Signals missing explicitly in original Verilog
    ----------------------------------------------------------------
    signal ad_rstn : std_logic;

    signal ad_kk : std_logic_vector(7 downto 0);
    signal ad_dl : std_logic_vector(7 downto 0);

    ----------------------------------------------------------------
    -- ADC reconstructed data and ADC clocks
    ----------------------------------------------------------------
    signal sAD1_DATA : std_logic_vector(15 downto 0);
    signal sAD2_DATA : std_logic_vector(15 downto 0);
    signal sAD3_DATA : std_logic_vector(15 downto 0);
    signal sAD4_DATA : std_logic_vector(15 downto 0);

    signal sAD1_CLK : std_logic;
    signal sAD2_CLK : std_logic;
    signal sAD3_CLK : std_logic;
    signal sAD4_CLK : std_logic;

    ----------------------------------------------------------------
    -- LED counter
    ----------------------------------------------------------------
    signal led_cnt : unsigned(25 downto 0) := (others => '0');

    ----------------------------------------------------------------
    -- AD9516 unused/debug outputs
    ----------------------------------------------------------------
    signal pll_pd     : std_logic;
    signal pll_led_ld : std_logic;
    signal pll_refmon : std_logic;

    ----------------------------------------------------------------
    -- ADC controller unused SDO
    ----------------------------------------------------------------
    signal adc1_sdo : std_logic;
    signal adc2_sdo : std_logic;
    signal adc3_sdo : std_logic;
    signal adc4_sdo : std_logic;
    
    
    signal Power_on_rst : std_logic;
    signal wr_en_ADC,Rd_en_ADC : std_logic;
    signal Wr_Clk_ADC : std_logic_vector (3 downto 0);
    signal full : std_logic_vector (3 downto 0);
    signal empty : std_logic_vector (3 downto 0);
    signal wr_data_count         : BinArray10(3 downto 0);
    signal rd_data_count_Adc     : BinArray10(3 downto 0);
    signal ADCin_Data            : BinArray16(3 downto 0);
    signal ADC_out_Data          : BinArray16(3 downto 0);    
    ----------------------------------------------------------------
    -- ILA probe
    ----------------------------------------------------------------
    signal ila_probe : std_logic_vector(49 downto 0);

 SIGNAL CpSl_AD9516_REF_SEL_o_INT,CpSl_AD9516_nRst_o_INT : std_logic;
 SIGNAL AD1_SCLK_INT : std_logic;
 SIGNAL AD1_CSB_INT  : std_logic;
 SIGNAL AD1_SDIO_INT : std_logic;
 signal  IDELAY_CTRL_RDY  : STD_LOGIC;

    ----------------------------------------------------------------
    -- Clock Wizard
    ----------------------------------------------------------------
    component clk_sys is
        port (
            clk_out1  : out std_logic;
            clk_out2  : out std_logic;
            clk_out3  : out std_logic;
            clk_out4  : out std_logic;
            reset     : in  std_logic;
            locked    : out std_logic;
            clk_in1_p : in  std_logic;
            clk_in1_n : in  std_logic
        );
    end component;


    ----------------------------------------------------------------
    -- AD9516 Controller
    ----------------------------------------------------------------
    component M_AD9516_Ctrl is
        port (
            S6_25MCLK   : in  std_logic;
            SYS_RSTn    : in  std_logic;

            PLL_RESET   : out std_logic;
            PLL_SCK     : out std_logic;
            PLL_CSN     : out std_logic;
            PLL_SDIO    : out std_logic;
            PLL_SDO     : in  std_logic;
            PLL_LD      : in  std_logic;
            PLL_REF_sel : out std_logic;
            PLL_PD      : out std_logic;
            PLL_SYNCN   : out std_logic;
            LED_LD      : out std_logic;
            PLL_REFMON  : out std_logic
        );
    end component;


    ----------------------------------------------------------------
    -- ADC SPI Controller
    ----------------------------------------------------------------
    component AD_CTR is
        port (
            S6_25MCLK : in  std_logic;
            SYS_RSTn  : in  std_logic;

            ad_kk     : out std_logic_vector(7 downto 0);
            ad_dl     : out std_logic_vector(7 downto 0);

            ADC_SCK   : out std_logic;
            ADC_CSN   : out std_logic;
            ADC_SDIO  : out std_logic;
            ADC_SDO   : in  std_logic
        );
    end component;


    ----------------------------------------------------------------
    -- ILA
    ----------------------------------------------------------------
    component ila_tt is
        port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(49 downto 0)
        );
    end component;
    
COMPONENT ADCsData_Sync 
    Port ( 
            Wr_Clk          : in STD_LOGIC;
            Rd_Clk          : in STD_LOGIC;
            rst             : in STD_LOGIC;            
            full            : out STD_LOGIC;            
            empty           : out STD_LOGIC;    
            wr_en           : in STD_LOGIC;
            rd_en           : in STD_LOGIC;        
            wr_data_count   : out STD_LOGIC_VECTOR(9 downto 0);
            rd_data_count   : out STD_LOGIC_VECTOR(9 downto 0);
            ADCs_In         : in STD_LOGIC_VECTOR(15 downto 0);
            ADCs_Out        : out STD_LOGIC_VECTOR(15 downto 0)
           );
end COMPONENT;

begin


    ----------------------------------------------------------------
    -- ADC reset
    --
    -- ad_rstn was not driven in the original Verilog.
    -- Here it follows PLL lock detect.
    ----------------------------------------------------------------
    ad_rstn <= CpSl_AD9516_LD_i;


    ----------------------------------------------------------------
    -- System clock generator
    ----------------------------------------------------------------
    U_CLK : clk_sys
        port map (
            clk_out1  => clk_25m,
            clk_out2  => clk_100m,
            clk_out3  => clk_200m,
            clk_out4  => Proc_Clk_333M,

            reset     => not(rst_n),
            locked    => sys_locked,

            clk_in1_p => sys_clk_p,
            clk_in1_n => sys_clk_n
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

    ----------------------------------------------------------------
    -- FMC differential clock input
    ----------------------------------------------------------------
    IBUFDS_adcclk : IBUFDS
        generic map (
            DQS_BIAS => "FALSE"
        )
        port map (
            O  => ad_clk,
            I  => FMC_CLK1_P,
            IB => FMC_CLK1_N
        );


    ----------------------------------------------------------------
    -- SYNC differential input
    ----------------------------------------------------------------
    IBUFDS_sync : IBUFDS
        generic map (
            DQS_BIAS => "FALSE"
        )
        port map (
            O  => ad_sync,
            I  => F_SYNC_P,
            IB => F_SYNC_N
        );


    ----------------------------------------------------------------
    -- Trigger differential input
    ----------------------------------------------------------------
    IBUFDS_sync2 : IBUFDS
        generic map (
            DQS_BIAS => "FALSE"
        )
        port map (
            O  => ad_sync2,
            I  => F_TRIG_IN_P,
            IB => F_TRIG_IN_N
        );


    ----------------------------------------------------------------
    -- AD9516 configuration
    ----------------------------------------------------------------
    U_M_AD9516_Ctrl : M_AD9516_Ctrl
        port map (
            S6_25MCLK   => clk_25m,
            SYS_RSTn    => sys_locked,

            PLL_RESET   => CpSl_AD9516_nRst_o_int,
            PLL_SCK     => CpSl_AD9516_Sclk_o,
            PLL_CSN     => CpSl_AD9516_nCS_o,
            PLL_SDIO    => CpSl_AD9516_SDIO_o,
            PLL_SDO     => CpSl_AD9516_SDO_i,
            PLL_LD      => CpSl_AD9516_LD_i,
            PLL_REF_sel => CpSl_AD9516_REF_SEL_o_int,
            PLL_PD      => pll_pd,
            PLL_SYNCN   => CpSl_AD9516_nSYNC_o,
            LED_LD      => pll_led_ld,
            PLL_REFMON  => pll_refmon
        );


    ----------------------------------------------------------------
    -- ADC1 SPI Controller
    ----------------------------------------------------------------
    U_ADC1_Ctrl : AD_CTR
        port map (
            S6_25MCLK => clk_25m,
            SYS_RSTn  => CpSl_AD9516_LD_i,

            ad_kk     => ad_kk,
            ad_dl     => ad_dl,

            ADC_SCK   => AD1_SCLK_int,
            ADC_CSN   => AD1_CSB_int,
            ADC_SDIO  => AD1_SDIO_int,
            ADC_SDO   => adc1_sdo
        );


    ----------------------------------------------------------------
    -- ADC2 SPI Controller
    ----------------------------------------------------------------
    U_ADC2_Ctrl : AD_CTR
        port map (
            S6_25MCLK => clk_25m,
            SYS_RSTn  => CpSl_AD9516_LD_i,

            ad_kk     => open,
            ad_dl     => open,

            ADC_SCK   => AD2_SCLK,
            ADC_CSN   => AD2_CSB,
            ADC_SDIO  => AD2_SDIO,
            ADC_SDO   => adc2_sdo
        );


    ----------------------------------------------------------------
    -- ADC3 SPI Controller
    ----------------------------------------------------------------
    U_ADC3_Ctrl : AD_CTR
        port map (
            S6_25MCLK => clk_25m,
            SYS_RSTn  => CpSl_AD9516_LD_i,

            ad_kk     => open,
            ad_dl     => open,

            ADC_SCK   => AD3_SCLK,
            ADC_CSN   => AD3_CSB,
            ADC_SDIO  => AD3_SDIO,
            ADC_SDO   => adc3_sdo
        );


    ----------------------------------------------------------------
    -- ADC4 SPI Controller
    ----------------------------------------------------------------
    U_ADC4_Ctrl : AD_CTR
        port map (
            S6_25MCLK => clk_25m,
            SYS_RSTn  => CpSl_AD9516_LD_i,

            ad_kk     => open,
            ad_dl     => open,

            ADC_SCK   => AD4_SCLK,
            ADC_CSN   => AD4_CSB,
            ADC_SDIO  => AD4_SDIO,
            ADC_SDO   => adc4_sdo
        );


    ----------------------------------------------------------------
    -- ADC1 DATA
    ----------------------------------------------------------------
    u_ad1 : entity work.AD_DATA_v2
        Generic map (is_clk_inverted => '1')
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => Power_on_rst,
            data_val => '0',

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

            ADC_DATA_OUT => ADCin_Data(0),
            ADC_CLK_OUT  => sAD1_CLK
        );


    ----------------------------------------------------------------
    -- ADC2 DATA
    ----------------------------------------------------------------
    u_ad2 : entity work.AD_DATA_v2
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => Power_on_rst,
            data_val => '0',

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

            ADC_DATA_OUT => ADCin_Data(1),
            ADC_CLK_OUT  => sAD2_CLK
        );


    ----------------------------------------------------------------
    -- ADC3 DATA
    ----------------------------------------------------------------
    u_ad3 : entity work.AD_DATA_v2
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => Power_on_rst,
            data_val => '0',

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

            ADC_DATA_OUT => ADCin_Data(2),
            ADC_CLK_OUT  => sAD3_CLK
        );


    ----------------------------------------------------------------
    -- ADC4 DATA
    ----------------------------------------------------------------
    u_ad4 : entity work.AD_DATA_v2
        port map (
            clk_200m => clk_200m,
            Proc_Clk_333M => Proc_Clk_333M,
            SYS_RST => Power_on_rst,
            data_val => '0',

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

            ADC_DATA_OUT => ADCin_Data(3),
            ADC_CLK_OUT  => sAD4_CLK
        );
Power_ON_Reset : entity work.power_on_reset
port map(
           proc_clk    => clk_200m,
           mmcm_locked => sys_locked,
           proc_rst    => Power_on_rst
);

Wr_Clk_ADC(0) <= sAD1_CLK;
Wr_Clk_ADC(1) <= sAD2_CLK;
Wr_Clk_ADC(2) <= sAD3_CLK;
Wr_Clk_ADC(3) <= sAD4_CLK;
    
ADCsData_Sync1 : for i in 0 to 3 generate
Inst_ADCsData_Sync : ADCsData_Sync
port map
        (
            Wr_Clk           => Wr_Clk_ADC(i),
            Rd_Clk           => sAD1_CLK,
            rst              => Power_on_rst,
            full             => full(i),
            empty            => empty(i),
            wr_en            => wr_en_ADC,
            rd_en            => Rd_en_ADC,
            wr_data_count    => wr_data_count(i),
            rd_data_count    => rd_data_count_Adc(i),
            ADCs_In          => ADCin_Data(i),
            ADCs_Out         => ADC_out_Data(i)
           );
           
           
 end generate;  
 
 ADC0_Syncronization:Process(Wr_Clk_ADC(0),Power_on_rst,CpSl_AD9516_LD_i)
variable FifoState0: std_logic_vector(3 downto 0);
begin
        if (Power_on_rst ='1' or CpSl_AD9516_LD_i = '0') then  
            FifoState0:=x"0";
            wr_en_ADC     <='0';
            Rd_en_ADC     <='0';
        elsif(rising_edge(Wr_Clk_ADC(0)))then
            case FifoState0 is 
                when x"0" =>
                    if(CpSl_AD9516_LD_i = '1') then
                        wr_en_ADC  <= '1';
                        FifoState0:=x"1";                    
                    end if;
                when x"1" =>
                    if (wr_data_count(0) >= x"005") then
                        Rd_en_ADC <= '1';
                    end if;
                when others =>
            end case;
        end if;
end process;
Inst_ila_ADC_Inspector :entity work.ila_ADC_Inspector_12
PORT MAP 
(
    clk         =>  sAD1_CLK,             
    probe0      =>  ADC_out_Data(0) , 
    probe1      =>  ADC_out_Data(1) ,  
    probe2      =>  ADC_out_Data(2) , 
    probe3      =>  ADC_out_Data(3) 
);
    ----------------------------------------------------------------
    -- LED Counter
    ----------------------------------------------------------------
    process(clk_25m, sys_locked)
    begin
        if sys_locked = '0' then

            led_cnt <= (others => '0');

        elsif rising_edge(clk_25m) then

            led_cnt <= led_cnt + 1;

        end if;
    end process;


    ----------------------------------------------------------------
    -- LEDs
    ----------------------------------------------------------------
    led(0) <= led_cnt(25);
    led(1) <= led_cnt(24);
    led(2) <= led_cnt(23);
    led(3) <= led_cnt(22);

    FMC_LED1 <= led_cnt(23);
    FMC_LED2 <= led_cnt(22);


    ----------------------------------------------------------------
    -- ILA
    --
    -- Original Verilog connected 11 signals to a 50-bit probe.
    -- Remaining upper bits are filled with zero.
    ----------------------------------------------------------------
    ila_probe <=
        (49 downto 14 => '0')     &
        rd_en_ADC                 &
        wr_en_ADC                 &
        Power_on_rst                 &
        sys_locked                 &
        CpSl_AD9516_LD_i           &
        CpSl_AD9516_REF_SEL_o_INT      &
        CpSl_AD9516_nRst_o_INT         &
        CpSl_AD9516_SDO_i          &
        AD1_SCLK_INT                   &
        AD1_CSB_INT                    &
        AD1_SDIO_INT                   &
        ad_sync                    &
        ad_sync2                   &
        '0';
CpSl_AD9516_REF_SEL_o <= CpSl_AD9516_REF_SEL_o_INT;
CpSl_AD9516_nRst_o    <= CpSl_AD9516_nRst_o_INT;
AD1_SCLK   <= AD1_SCLK_INT;
AD1_CSB    <= AD1_CSB_INT ;
AD1_SDIO   <= AD1_SDIO_INT;

    your_instance_name : ila_tt
        port map (
            clk    => clk_100m,
            probe0 => ila_probe
        );


end RTL;

