----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:38:34 12/21/2013 
-- Design Name: 
-- Module Name:    DC_Remover - Behavioral 
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
--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
--use ieee.numeric_std.all;

--use ieee.std_logic_misc.all;
--use ieee.std_logic_arith.all;
--use work.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--entity DC_Remover is
--	generic(
--		Nx	: natural := 16;
--		Ny	: natural := 16;
--		Nk	: natural := 8
--	);
--	port(
--		Clk	: in std_logic;
--		x	: in std_logic_vector(Nx - 1 downto 0);	
--		y	: out std_logic_vector(Ny - 1 downto 0)
--	);
--end DC_Remover;

--architecture bhv of DC_Remover is

--	constant Na		: natural := Nx + Nk;

--	signal Acc		: std_logic_vector(Na - 1 downto 0) := (others => '0');
	
--	signal Acc_H8	: std_logic_vector(Na - 1 downto 0);
--	signal sub_o1	: std_logic_vector(Na - 1 downto 0);
--	signal x_Na		: std_logic_vector(Na - 1 downto 0);
--	signal Acc_Fin	: std_logic_vector(Na - 1 downto 0);
--			signal   	LAST_DC      :STD_LOGIC_VECTOR(Ny + Nk -1 downto 0):=(others=>'0');


--begin

--		process(Clk)
--	variable   MULTIPLIER_OUT :STD_LOGIC_VECTOR(Ny + Nk -1  downto 0):=(others=>'0');
--	variable   SUBTRACTOR_OUT :STD_LOGIC_VECTOR(Ny-1 downto 0):=(others=>'0');
--	variable   cntavg	      : integer range 0 to 15 := 0;
--begin
--	if rising_edge(Clk) then
--		SUBTRACTOR_OUT := x - LAST_DC(Ny + Nk -1 downto Nk);
--		MULTIPLIER_OUT := SXT(SUBTRACTOR_OUT, Ny + Nk);
--		LAST_DC <= MULTIPLIER_OUT + LAST_DC;
--		if cntavg = 7 then
--			y <= x - LAST_DC(Ny + Nk -1 downto Nk);
			
--		else
--			cntavg := cntavg + 1;
--		end if;
--	end if;

--end process;
	
--end bhv;
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--library	unisim;
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity DC_removal_v2 is
generic(
	Data_width :integer:= 16;
	Integ_mag	: integer:= 21);
port(
	Clk		: in std_logic;
	rst		: in std_logic;
	
	x	: in std_logic_vector (Data_width-1 downto 0 );
	y	: out std_logic_vector(Data_width - 1 downto 0);

	DC_out  		: out std_logic_vector (Data_width-1 downto 0 );
	sigma_dc_dn	: out std_logic_vector (Data_width-1 downto 0 );
	DataOut 		: out std_logic_vector (Data_width-1 downto 0 )
	);
end entity;

architecture Rtl of DC_removal_v2 is 
signal	Datain_t1_d1,
		Datain_t2_d1	: std_logic_vector (Data_width downto 0 );

signal sigma_16bit_d1,sigma_16bit_d2,sigma_16bit_d3,sigma_16bit_d4:std_logic_vector (15 downto 0 );		

signal data_in_val_d1,
		data_in_val_d2,
		data_in_val_d3,
		data_in_val_d4:std_logic;
	
signal  Integ_out_rnd	: signed (Data_width downto 0 );
signal	Datain_mul_gain	: signed (Data_width+Integ_mag downto 0 );
signal  Sighn_Datain_t1_d1: std_logic;
signal  Sighn_Integ_acc: std_logic;

signal 	dataout_tmp,
		dataout_tmp2: signed (Data_width downto 0 );
signal	dataout_tmp3: signed (Data_width-1 downto 0 );

signal DC_out_tmp,
		DC_out_tmp1,
		DC_out_tmp2	:signed (Data_width downto 0 );
signal	DC_out_tmp3	:signed (Data_width-1 downto 0 );
		
signal	Integ_acc_tmp,
		Integ_acc		: signed (Data_width+Integ_mag downto 0 );
begin

process(clk)
begin
	if(clk'event and clk='1') then
			Datain_t1_d1 <= x(x'left) & x;
	end if;
end process;
 

process(clk)
begin
	if(clk'event and clk='1') then
--		if(ce='1') then

			Dataout_tmp <= signed(Datain_t1_d1)-Integ_out_rnd;
			DC_out_tmp <= Integ_out_rnd;
			
			Sighn_Datain_t1_d1 <= Datain_t1_d1(Datain_t1_d1'left);
			Sighn_Integ_acc <= Integ_acc(Integ_acc'left);

	
--		end if;
	end if;
end process;

Datain_mul_gain	(Data_width+Integ_mag downto Data_width+1) <= (others => Dataout_tmp(Dataout_tmp'left));
Datain_mul_gain	(Data_width downto 0) <= signed(Dataout_tmp);
Integ_acc_tmp	<= Integ_acc + signed(Datain_mul_gain);
 
process(clk,rst)
begin
	if(rst='1') then
		Integ_acc <= (others=>'0');
	elsif(clk'event and clk='1') then
		Integ_acc <= Integ_acc_tmp;
	end if;
end process;

Integ_out_rnd <= Integ_acc(Data_width+Integ_mag downto Integ_mag);

process(clk)
begin
	if(clk'event and clk='1') then
    
			if(Sighn_Datain_t1_d1='1' and Sighn_Integ_acc='0' and Dataout_tmp(Dataout_tmp'left)='0') then
			--input is negetive, accumulate is positive, data_out is positive so overflow
				dataout_tmp2(Data_width-2 downto 0) <= (0=>'1',others=> '0');
				dataout_tmp2(Data_width downto Data_width-1) <= (others=>'1');
			elsif( Sighn_Datain_t1_d1='0' and Sighn_Integ_acc='1' and Dataout_tmp(Dataout_tmp'left)='1') then	
			--input is positive, accumulate is neg, data_out is neg so overflow
				dataout_tmp2(Data_width-2 downto 0) <= (others=> '1');
				dataout_tmp2(Data_width downto Data_width-1) <= (others=>'0');
			else
				dataout_tmp2 <= Dataout_tmp;
			end if;	
				
				dc_out_tmp2 <= DC_out_tmp;

				if(dataout_tmp2(Data_width)=dataout_tmp2(Data_width-1)) then
				--one high bit truncate
					dataout_tmp3 <= dataout_tmp2(Data_width-1 downto 0);
				else	
				
					dataout_tmp3 (Data_width-1) <= (dataout_tmp2(Data_width));
					dataout_tmp3(Data_width-2 downto 0) <= (others=>not(dataout_tmp2(Data_width)));
				end if;

				if(dc_out_tmp2(Data_width)=dc_out_tmp2(Data_width-1)) then
				--one high bit truncate
					dc_out_tmp3 <= DC_out_tmp2(Data_width-1 downto 0 );		
				else
					dc_out_tmp3(Data_width-1) <= dc_out_tmp2(Data_width);
					dc_out_tmp3(Data_width-2 downto 0) <= (others=>not(dc_out_tmp2(Data_width)));
				end if;	
				

--				test_out <= std_logic_vector(Integ_acc_tmp(Data_width+Integ_mag downto Data_width+Integ_mag -31));
				
--		end if;
	end if;
end process;

y      <= std_logic_vector(dataout_tmp3);
DC_out <= std_logic_vector(dc_out_tmp3);


end rtl;

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:38:34 12/21/2013 
-- Design Name: 
-- Module Name:    DC_Remover - Behavioral 
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
--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
--use ieee.numeric_std.all;

--use ieee.std_logic_misc.all;
--use ieee.std_logic_arith.all;
--use work.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--entity DC_Remover is
--	generic(
--		Nx	: natural := 16;
--		Ny	: natural := 16;
--		Nk	: natural := 8
--	);
--	port(
--		Clk	: in std_logic;
--		x	: in std_logic_vector(Nx - 1 downto 0);	
--		y	: out std_logic_vector(Ny - 1 downto 0)
--	);
--end DC_Remover;

--architecture bhv of DC_Remover is

--	constant Na		: natural := Nx + Nk;

--	signal Acc		: std_logic_vector(Na - 1 downto 0) := (others => '0');
	
--	signal Acc_H8	: std_logic_vector(Na - 1 downto 0);
--	signal sub_o1	: std_logic_vector(Na - 1 downto 0);
--	signal x_Na		: std_logic_vector(Na - 1 downto 0);
--	signal Acc_Fin	: std_logic_vector(Na - 1 downto 0);
--			signal   	LAST_DC      :STD_LOGIC_VECTOR(Ny + Nk -1 downto 0):=(others=>'0');


--begin

--		process(Clk)
--	variable   MULTIPLIER_OUT :STD_LOGIC_VECTOR(Ny + Nk -1  downto 0):=(others=>'0');
--	variable   SUBTRACTOR_OUT :STD_LOGIC_VECTOR(Ny-1 downto 0):=(others=>'0');
--	variable   cntavg	      : integer range 0 to 15 := 0;
--begin
--	if rising_edge(Clk) then
--		SUBTRACTOR_OUT := x - LAST_DC(Ny + Nk -1 downto Nk);
--		MULTIPLIER_OUT := SXT(SUBTRACTOR_OUT, Ny + Nk);
--		LAST_DC <= MULTIPLIER_OUT + LAST_DC;
--		if cntavg = 7 then
--			y <= x - LAST_DC(Ny + Nk -1 downto Nk);
			
--		else
--			cntavg := cntavg + 1;
--		end if;
--	end if;

--end process;
	
--end bhv;
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--___________________________________________________________________________________________________
--library	unisim;
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity DC_removal_v3 is
generic(
	Data_width :integer:= 24;
	Integ_mag	: integer:= 15);
port(
	Clk		: in std_logic;
	rst		: in std_logic;
	
	Data_val	: in std_logic;
	
	x	: in std_logic_vector (Data_width-1 downto 0 );
	y	: out std_logic_vector(Data_width - 1 downto 0);

	DC_out  		: out std_logic_vector (Data_width-1 downto 0 );
	sigma_dc_dn	: out std_logic_vector (Data_width-1 downto 0 );
	DataOut 		: out std_logic_vector (Data_width-1 downto 0 )
	);
end entity;

architecture Rtl of DC_removal_v3 is 
signal	Datain_t1_d1,
		Datain_t2_d1	: std_logic_vector (Data_width downto 0 );

signal sigma_16bit_d1,sigma_16bit_d2,sigma_16bit_d3,sigma_16bit_d4:std_logic_vector (15 downto 0 );		

signal data_in_val_d1,
		data_in_val_d2,
		data_in_val_d3,
		data_in_val_d4:std_logic;
	
signal  Integ_out_rnd	: signed (Data_width downto 0 );
signal	Datain_mul_gain	: signed (Data_width+Integ_mag downto 0 );
signal  Sighn_Datain_t1_d1: std_logic;
signal  Sighn_Integ_acc: std_logic;

signal 	dataout_tmp,
		dataout_tmp2: signed (Data_width downto 0 );
signal	dataout_tmp3: signed (Data_width-1 downto 0 );

signal DC_out_tmp,
		DC_out_tmp1,
		DC_out_tmp2	:signed (Data_width downto 0 );
signal	DC_out_tmp3	:signed (Data_width-1 downto 0 );
		
signal	Integ_acc_tmp,
		Integ_acc		: signed (Data_width+Integ_mag downto 0 );
begin

process(clk)
begin
	if(clk'event and clk='1') then
			Datain_t1_d1 <= x(x'left) & x;
	end if;
end process;
 

process(clk)
begin
	if(clk'event and clk='1') then
		if(Data_val='1') then

			Dataout_tmp <= signed(Datain_t1_d1)-Integ_out_rnd;
			DC_out_tmp <= Integ_out_rnd;
			
			Sighn_Datain_t1_d1 <= Datain_t1_d1(Datain_t1_d1'left);
			Sighn_Integ_acc <= Integ_acc(Integ_acc'left);
	
		end if;
	end if;
end process;

Datain_mul_gain	(Data_width+Integ_mag downto Data_width+1) <= (others => Dataout_tmp(Dataout_tmp'left));
Datain_mul_gain	(Data_width downto 0) <= signed(Dataout_tmp);
Integ_acc_tmp	<= Integ_acc + signed(Datain_mul_gain);
 
process(clk,rst)
begin
	if(rst='1') then
		Integ_acc <= (others=>'0');
	elsif(clk'event and clk='1') then
	    if(Data_val='1') then
		  Integ_acc <= Integ_acc_tmp;
	    end if;
	end if;
end process;

Integ_out_rnd <= Integ_acc(Data_width+Integ_mag downto Integ_mag);

process(clk)
begin
	if(clk'event and clk='1') then
        if(Data_val='1') then
			if(Sighn_Datain_t1_d1='1' and Sighn_Integ_acc='0' and Dataout_tmp(Dataout_tmp'left)='0') then
			--input is negetive, accumulate is positive, data_out is positive so overflow
				dataout_tmp2(Data_width-2 downto 0) <= (0=>'1',others=> '0');
				dataout_tmp2(Data_width downto Data_width-1) <= (others=>'1');
			elsif( Sighn_Datain_t1_d1='0' and Sighn_Integ_acc='1' and Dataout_tmp(Dataout_tmp'left)='1') then	
			--input is positive, accumulate is neg, data_out is neg so overflow
				dataout_tmp2(Data_width-2 downto 0) <= (others=> '1');
				dataout_tmp2(Data_width downto Data_width-1) <= (others=>'0');
			else
				dataout_tmp2 <= Dataout_tmp;
			end if;	
				
				dc_out_tmp2 <= DC_out_tmp;

				if(dataout_tmp2(Data_width)=dataout_tmp2(Data_width-1)) then
				--one high bit truncate
					dataout_tmp3 <= dataout_tmp2(Data_width-1 downto 0);
				else	
				
					dataout_tmp3 (Data_width-1) <= (dataout_tmp2(Data_width));
					dataout_tmp3(Data_width-2 downto 0) <= (others=>not(dataout_tmp2(Data_width)));
				end if;

				if(dc_out_tmp2(Data_width)=dc_out_tmp2(Data_width-1)) then
				--one high bit truncate
					dc_out_tmp3 <= DC_out_tmp2(Data_width-1 downto 0 );		
				else
					dc_out_tmp3(Data_width-1) <= dc_out_tmp2(Data_width);
					dc_out_tmp3(Data_width-2 downto 0) <= (others=>not(dc_out_tmp2(Data_width)));
				end if;	
				

--				test_out <= std_logic_vector(Integ_acc_tmp(Data_width+Integ_mag downto Data_width+Integ_mag -31));
				
		end if;
	end if;
end process;

y      <= std_logic_vector(dataout_tmp3);
DC_out <= std_logic_vector(dc_out_tmp3);


end rtl;