-- AD9516 clock-generator setup used by ADC_orihard.
-- After reset, send the 63 board-specific register writes once, MSB first.
-- Each SPI frame contains a 16-bit instruction and one 8-bit data byte.
-- This controller writes only: PLL_SDO is not used for register readback.
-- S6_25MCLK is a legacy name; the current top supplies a 20 MHz clock.
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity M_AD9516_Ctrl is
	  port(
				  ----------------------------------
				  --clock and reset port
				  ----------------------------------
				  S6_25MCLK		                  :	in		std_logic                       ;	-- 20 MHz in ADC_orihard
				  SYS_RSTn		                  :	in 	  std_logic                       ;	--active is low	
				  ----------------------------------                                    
				  --AD9516 SPI port                                                     
				  ----------------------------------	                                  
				  PLL_RESET		                  :	out 	std_logic                       ;	
				  PLL_SCK			                  :	out 	std_logic                       ;									 
				  PLL_CSN			                  :	out 	std_logic                       ;									 
				  PLL_SDIO		                  :	out	  std_logic                       ;									 	
				  PLL_SDO			                  :	in 	  std_logic                       ;	
				                                                                        
				  PLL_LD			                  :	in 	  std_logic                       ;
				  PLL_REF_sel	                  :	out 	std_logic                       ;
				  PLL_PD			                  :	out 	std_logic                       ;
				  PLL_SYNCN		                  :	out 	std_logic                       ;
				  LED_LD		                  	:	out 	std_logic                       ;
				  PLL_REFMON	                  :	out 	std_logic                       
    );
end M_AD9516_Ctrl;

architecture Behavioral of M_AD9516_Ctrl is

	signal  AD9516_SCLK		                :	std_logic                             ;
	signal  AD9516_CS_N		                :	std_logic                             ;
	signal  AD9516_SDIO		                :	std_logic                             ;
	signal  AD9516_SDO		                :	std_logic                             ;
	                                      
	signal  config_reg		                :	std_logic_vector(23 downto 0)         ;
	signal  spi_reg				                :	std_logic_vector(23 downto 0)         ;
	signal  config_reg_cnt                :	std_logic_vector(7 downto 0)          ;
	signal  wr_reg_cnt		                :	std_logic_vector(7 downto 0)          ;
	                                                                              
	signal  rst_cnt				                :	std_logic_vector(27 downto 0)         ;
	signal  reset 				                :	std_logic                             ;
	                                      
	type 	  statetype is (config_wait,config_start,idle0,idle1,idle2,idle3,wr_clkl0,wr_clkl1,wr_clkh0,wr_clkh1,config_wait1,config_end);
	signal  spi_cntr_status               : statetype                             ;
	
begin

	PLL_RESET 	 <= SYS_RSTn;
	PLL_PD	 	 <= '1';
	PLL_REF_sel  <= '0';  -- Board pin level; register 0x01C=0x44 selects REF2 directly.
	
	PLL_SYNCN	 <= '1';
	PLL_REFMON	 <= '0';
	
	PLL_SCK	    <= AD9516_SCLK;								 
	PLL_CSN	    <= AD9516_CS_N;									 
	PLL_SDIO	 	 <= AD9516_SDIO;	

	LED_LD <= PLL_LD;

	process(S6_25MCLK)
	begin
		if rising_edge(S6_25MCLK) then
			case config_reg_cnt is

            -- Board profile: PLL settings, output drivers and clock dividers.
            -- Keep write order: 0x0232 = 0x01 applies buffered settings.
            -- Use the exact AD9516 variant and board reference to change this table.
                    when x"00" => config_reg <= x"0000" & x"A5";
                    when x"01" => config_reg <= x"0000" & x"99";
                    when x"02" => config_reg <= x"0010" & x"7C";
                    when x"03" => config_reg <= x"0011" & x"01";
                    when x"04" => config_reg <= x"0012" & x"00";
                    when x"05" => config_reg <= x"0013" & x"0A";
                    when x"06" => config_reg <= x"0014" & x"0F";
                    when x"07" => config_reg <= x"0015" & x"00";
                    when x"08" => config_reg <= x"0016" & x"05";
                    when x"09" => config_reg <= x"0017" & x"00";
                    when x"0A" => config_reg <= x"0018" & x"00";
                    when x"0B" => config_reg <= x"0232" & x"01"; -- IO_UPDATE
                    when x"0C" => config_reg <= x"0018" & x"01";
                    when x"0D" => config_reg <= x"0232" & x"01"; -- IO_UPDATE
                    when x"0E" => config_reg <= x"0000" & x"18";
                    when x"0F" => config_reg <= x"0004" & x"00";
                    when x"10" => config_reg <= x"0010" & x"7C";
                    when x"11" => config_reg <= x"0011" & x"01";
                    when x"12" => config_reg <= x"0012" & x"00";
                    when x"13" => config_reg <= x"0013" & x"00";
                    when x"14" => config_reg <= x"0014" & x"0F";
                    when x"15" => config_reg <= x"0015" & x"00";
                    when x"16" => config_reg <= x"0016" & x"05";
                    when x"17" => config_reg <= x"0017" & x"00";
                    when x"18" => config_reg <= x"0018" & x"07";
                    when x"19" => config_reg <= x"0019" & x"00";
                    when x"1A" => config_reg <= x"001A" & x"00";
                    when x"1B" => config_reg <= x"001B" & x"00";
                    when x"1C" => config_reg <= x"001C" & x"44";
                    when x"1D" => config_reg <= x"001D" & x"00";
                    when x"1E" => config_reg <= x"00F0" & x"08";
                    when x"1F" => config_reg <= x"00F1" & x"08";
                    when x"20" => config_reg <= x"00F2" & x"08";
                    when x"21" => config_reg <= x"00F3" & x"08";
                    when x"22" => config_reg <= x"00F4" & x"08";
                    when x"23" => config_reg <= x"00F5" & x"08";
                    when x"24" => config_reg <= x"0140" & x"43";
                    when x"25" => config_reg <= x"0141" & x"43";
                    when x"26" => config_reg <= x"0142" & x"43";
                    when x"27" => config_reg <= x"0143" & x"43";
                    when x"28" => config_reg <= x"0190" & x"11";
                    when x"29" => config_reg <= x"0191" & x"00";
                    when x"2A" => config_reg <= x"0192" & x"00";
                    when x"2B" => config_reg <= x"0193" & x"11";
                    when x"2C" => config_reg <= x"0194" & x"00";
                    when x"2D" => config_reg <= x"0195" & x"00";
                    when x"2E" => config_reg <= x"0196" & x"11";
                    when x"2F" => config_reg <= x"0197" & x"00";
                    when x"30" => config_reg <= x"0198" & x"00";
                    when x"31" => config_reg <= x"0199" & x"22";
                    when x"32" => config_reg <= x"019A" & x"00";
                    when x"33" => config_reg <= x"019B" & x"11";
                    when x"34" => config_reg <= x"019C" & x"00";
                    when x"35" => config_reg <= x"019D" & x"00";
                    when x"36" => config_reg <= x"019E" & x"22";
                    when x"37" => config_reg <= x"019F" & x"00";
                    when x"38" => config_reg <= x"01A0" & x"11";
                    when x"39" => config_reg <= x"01A1" & x"00";
                    when x"3A" => config_reg <= x"01A2" & x"00";
                    when x"3B" => config_reg <= x"01E0" & x"01"; -- VCO divider: /3
                    when x"3C" => config_reg <= x"01E1" & x"02";
                    when x"3D" => config_reg <= x"0230" & x"00";
                    when x"3E" => config_reg <= x"0232" & x"01"; -- IO_UPDATE
				when others =>
					config_reg <= x"000000";
			end case;
		end if;
	end process;
	
	process(S6_25MCLK,SYS_RSTn)
	begin
		if SYS_RSTn = '0' then
			spi_cntr_status <= config_wait;
			AD9516_SCLK		<= '0';
			AD9516_CS_N		<= '1';
			AD9516_SDIO		<= '0';
			spi_reg			  <= (others => '0');
			config_reg_cnt<= (others => '0');
			wr_reg_cnt		<= (others => '0');
		elsif rising_edge(S6_25MCLK) then
			case spi_cntr_status is
				when config_wait => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					
					spi_cntr_status <= config_start;	
				when config_start => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					
					spi_cntr_status <= idle0;
				when idle0 => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					
					spi_cntr_status <= idle1;
				when idle1 => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					
					spi_cntr_status <= idle2;
				when idle2 => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					
					spi_cntr_status <= idle3;
				when idle3 => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '0';
					AD9516_SDIO		<= '0';
					
					spi_reg <= config_reg;
					spi_cntr_status <= wr_clkl0;
				when wr_clkl0 =>
					-- Present the next bit while SCLK is low; the chip reads it high.
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '0';
					AD9516_SDIO		<= spi_reg(23);
					
					spi_cntr_status <= wr_clkl1;
				when wr_clkl1 => 
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '0';
					AD9516_SDIO		<= spi_reg(23);
					
					spi_cntr_status <= wr_clkh0;
				when wr_clkh0 => 
					AD9516_SCLK		<= '1';
					AD9516_CS_N		<= '0';
					AD9516_SDIO		<= spi_reg(23);
					
					spi_cntr_status <= wr_clkh1;
				when wr_clkh1 => 
					AD9516_SCLK		<= '1';
					AD9516_CS_N		<= '0';
					AD9516_SDIO		<= spi_reg(23);
					
					spi_reg 		<= spi_reg(22 downto 0)&spi_reg(23);
					wr_reg_cnt 		<= wr_reg_cnt + 1;
					spi_cntr_status <= config_wait1;			
				when config_wait1 =>
					-- A complete frame is 24 bits. Advance only after its last bit.
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '0';
					if wr_reg_cnt = x"18" then
						wr_reg_cnt <= (others => '0');
						
						if config_reg_cnt = x"3E" then
							spi_cntr_status <= config_end;
							config_reg_cnt  <= (others => '0');
						else
							spi_cntr_status <= config_start;
							config_reg_cnt  <= config_reg_cnt + 1;
						end if;
					else
						spi_cntr_status <= wr_clkl0;
					end if;
					
				when config_end =>
					-- Configuration runs once per reset; leave the SPI bus idle.
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					spi_cntr_status <= config_end;
				when others =>
					AD9516_SCLK		<= '0';
					AD9516_CS_N		<= '1';
					AD9516_SDIO		<= '0';
					spi_cntr_status <= config_wait;
				end case;		
		end if;
	end process;

end Behavioral;
