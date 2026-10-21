----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:28:56 06/06/2017 
-- Design Name: 
-- Module Name:    AD95616_Config - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AD_CTR is
	  port(
				  ----------------------------------
				  --clock and reset port
				  ----------------------------------
				  S6_25MCLK		                  :	in		std_logic                       ;	--25MHz
				  SYS_RSTn		                  :	in 	  std_logic                       ;	--active is low	
				  
				  ad_kk                           : in std_logic_vector(7 downto 0);
				  ad_dl                           : in std_logic_vector(7 downto 0);
				  ----------------------------------                                    
				  --AD9516 SPI port                                                     
				  ----------------------------------	                                  
				  ADC_RESET		                  :	out 	std_logic                       ;	
				  ADC_SCK			                  :	out 	std_logic                       ;									 
				  ADC_CSN			                  :	out 	std_logic                       ;									 
				  ADC_SDIO		                  :	out	  std_logic                       ;									 	
				  ADC_SDO			                  :	in 	  std_logic                       	
				                                                                        
    );
end AD_CTR;

architecture Behavioral of AD_CTR is

	signal  AD_SCLK		                :	std_logic                             ;
	signal  AD_CS_N		                :	std_logic                             ;
	signal  AD_SDIO		                :	std_logic                             ;
	signal  AD_SDO		                :	std_logic                             ;
	                                      
	signal  config_reg		                :	std_logic_vector(23 downto 0)         ;
	signal  spi_reg				                :	std_logic_vector(23 downto 0)         ;
	signal  config_reg_cnt                :	std_logic_vector(7 downto 0)          ;
	signal  wr_reg_cnt		                :	std_logic_vector(7 downto 0)          ;
	                                                                              
	signal  rst_cnt				                :	std_logic_vector(27 downto 0)         ;
	signal  reset 				                :	std_logic                             ;
	                                      
	type 	  statetype is (config_wait,config_start,idle0,idle1,idle2,idle3,wr_clkl0,wr_clkl1,wr_clkh0,wr_clkh1,config_wait1,config_end);
	signal  spi_cntr_status               : statetype                             ;
	
begin


	ADC_SCK	    <= AD_SCLK;								 
	ADC_CSN	    <= AD_CS_N;									 
	ADC_SDIO	 	 <= AD_SDIO;	


	process(S6_25MCLK)
	begin
		if rising_edge(S6_25MCLK) then
			case config_reg_cnt is

                    when x"00" => config_reg <= x"0000" & x"18";										
                    when x"01" => config_reg <= x"0008" & x"00";     
                    when x"02" => config_reg <= x"0036" & x"22";---x"07";    
                    when x"03" => config_reg <= x"000F" & x"00";    
                    when x"04" => config_reg <= x"0010" & x"00";    
                    when x"05" => config_reg <= x"0014" & x"09";    --   
                    when x"06" => config_reg <= x"0015" & x"00";    --
                    when x"07" => config_reg <= x"0016" & x"00";    --
                    when x"08" => config_reg <= x"0018" & x"0A";    --
                    when x"09" => config_reg <= x"002C" & x"00";    --
                    
                    when x"0A" => config_reg <= x"000D" & x"00";--ad_kk;    --    
                   -- when x"0A" => config_reg <= x"0036" & x"22";    --      
                    when x"0B" => config_reg <= x"0107" & x"20";    --       
                    when x"0C" => config_reg <= x"00FF" & x"01";                                
  
				when others =>
					config_reg <= x"000000";
			end case;
		end if;
	end process;
	
	process(S6_25MCLK,SYS_RSTn)
	begin
		if SYS_RSTn = '0' then
			spi_cntr_status <= config_wait;
			AD_SCLK		<= '0';
			AD_CS_N		<= '1';
			AD_SDIO		<= '0';
			spi_reg			  <= (others => '0');
			config_reg_cnt<= (others => '0');
			wr_reg_cnt		<= (others => '0');
		elsif rising_edge(S6_25MCLK) then
			case spi_cntr_status is
				when config_wait => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					
					spi_cntr_status <= config_start;	
				when config_start => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					
					spi_cntr_status <= idle0;
				when idle0 => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					
					spi_cntr_status <= idle1;
				when idle1 => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					
					spi_cntr_status <= idle2;
				when idle2 => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					
					spi_cntr_status <= idle3;
				when idle3 => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '0';
					AD_SDIO		<= '0';
					
					spi_reg <= config_reg;
					spi_cntr_status <= wr_clkl0;
				when wr_clkl0 => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '0';
					AD_SDIO		<= spi_reg(23);
					
					spi_cntr_status <= wr_clkl1;
				when wr_clkl1 => 
					AD_SCLK		<= '0';
					AD_CS_N		<= '0';
					AD_SDIO		<= spi_reg(23);
					
					spi_cntr_status <= wr_clkh0;
				when wr_clkh0 => 
					AD_SCLK		<= '1';
					AD_CS_N		<= '0';
					AD_SDIO		<= spi_reg(23);
					
					spi_cntr_status <= wr_clkh1;
				when wr_clkh1 => 
					AD_SCLK		<= '1';
					AD_CS_N		<= '0';
					AD_SDIO		<= spi_reg(23);
					
					spi_reg 		<= spi_reg(22 downto 0)&spi_reg(23);
					wr_reg_cnt 		<= wr_reg_cnt + 1;
					spi_cntr_status <= config_wait1;			
				when config_wait1 =>
					AD_SCLK		<= '0';
					AD_CS_N		<= '0';
					if wr_reg_cnt = x"18" then
						wr_reg_cnt <= (others => '0');
						
						if config_reg_cnt = x"0F" then
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
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					spi_cntr_status <= config_end;
				when others =>
					AD_SCLK		<= '0';
					AD_CS_N		<= '1';
					AD_SDIO		<= '0';
					spi_cntr_status <= config_wait;
				end case;		
		end if;
	end process;

end Behavioral;
