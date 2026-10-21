library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_ad9467_startup is end;
architecture test of tb_ad9467_startup is
    signal clk : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal ready : std_logic := '1';
    signal trained, failed : std_logic_vector(3 downto 0) := "0000";
    signal sck, csn, sdio, train_enable, run_ready, fault : std_logic;
    type cmds_t is array(natural range <>) of std_logic_vector(23 downto 0);
    constant wanted : cmds_t := (x"000018",x"000800",x"003622",x"000F00",x"001000",
        x"001408",x"001500",x"001600",x"00180A",x"002C00",x"000D06",x"010720",x"00FF01",
        x"000D00",x"001409",x"00FF01");
    signal command_count : natural := 0;
begin
    clk <= not clk after 25 ns;
    dut : entity work.ad9467_startup
        generic map(POWER_WAIT_CYCLES=>16, TRAIN_TIMEOUT_CYCLES=>3000, FLUSH_CYCLES=>32, SPI_HALF_PERIOD=>2)
        port map(clk,reset_n,ready,trained,failed,sck,csn,sdio,train_enable,run_ready,fault);
    process(sck,csn,reset_n)
        variable shift : std_logic_vector(23 downto 0) := (others=>'0');
        variable bits : natural := 0;
    begin
        if reset_n='0' then command_count<=0; bits:=0;
        elsif rising_edge(sck) then
            assert csn='0' severity failure;
            shift:=shift(22 downto 0)&sdio; bits:=bits+1;
        elsif rising_edge(csn) and bits>0 then
            assert bits=24 report "SPI frame length" severity failure;
            assert command_count < wanted'length severity failure;
            assert shift=wanted(command_count) report "Wrong SPI command " & integer'image(command_count) severity failure;
            if command_count>=13 then assert trained="1111" report "Normal mode too early" severity failure; end if;
            command_count<=command_count+1; bits:=0;
        end if;
    end process;
    process
    begin
        wait for 200 ns; reset_n<='1';
        wait until train_enable='1' for 1 ms;
        assert train_enable='1' and command_count=13 and run_ready='0' severity failure;
        trained<="0111"; wait for 1 us;
        assert run_ready='0' and command_count=13 severity failure;
        trained<="1111";
        wait until run_ready='1' for 1 ms;
        assert run_ready='1' and fault='0' and command_count=16 severity failure;
        ready<='0'; wait for 1 us;
        assert run_ready='0' and fault='1' severity failure;
        -- Missing DCO modeled as no response: independent watchdog must expire.
        reset_n<='0'; trained<="0000"; ready<='1'; wait for 200 ns; reset_n<='1';
        wait until fault='1' for 1 ms;
        assert fault='1' and run_ready='0' and command_count=13 report "No-clock watchdog failed" severity failure;
        -- Explicit failure from any one of the four channels blocks RUN.
        reset_n<='0'; wait for 200 ns; reset_n<='1';
        wait until train_enable='1'; failed<="0100"; wait for 1 us;
        assert fault='1' and run_ready='0' severity failure;
        report "PASS: SPI frames, PN9/normal sequence, all-channel barrier, watchdog, fault/reset";
        finish;
    end process;
end;
