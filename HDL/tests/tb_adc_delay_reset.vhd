library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity tb_adc_delay_reset is end;
architecture test of tb_adc_delay_reset is
    constant T : time := 3 ns;
    signal clk : std_logic := '0';
    signal running : boolean := false;
    signal rst : std_logic := '1';
    signal delay_reset, ctrl_reset : std_logic;
begin
    process
    begin
        wait for T/2;
        if running then clk <= not clk; else clk <= '0'; end if;
    end process;
    dut : entity work.adc_delay_reset_sequencer port map(clk,rst,delay_reset,ctrl_reset);
    process
        procedure check_sequence is
        begin
            for edge in 1 to 67 loop
                wait until rising_edge(clk); wait for 1 ps;
                if edge < 35 then assert delay_reset = '1' report "IDELAY reset released too early" severity failure;
                else assert delay_reset = '0' report "IDELAY reset failed to release" severity failure; end if;
                if edge < 67 then assert ctrl_reset = '1' report "IDELAYCTRL reset released too early" severity failure;
                else assert ctrl_reset = '0' report "IDELAYCTRL reset failed to release" severity failure; end if;
            end loop;
        end procedure;
    begin
        wait for 10 ns;
        assert delay_reset = '1' and ctrl_reset = '1' severity failure;
        rst <= '0'; wait for 20 ns;
        assert delay_reset = '1' and ctrl_reset = '1' report "Reset released without child clock" severity failure;
        running <= true; check_sequence;
        wait until falling_edge(clk); wait for 0.2 ns; rst <= '1'; wait for 0.1 ns;
        assert delay_reset = '1' and ctrl_reset = '1' report "Reset assertion waited for a clock" severity failure;
        wait for 10 ns; rst <= '0'; check_sequence;
        -- Stop after a successful run; lock loss must still assert both resets.
        running <= false; wait for 10 ns; rst <= '1'; wait for 0.1 ns;
        assert delay_reset = '1' and ctrl_reset = '1' report "Stopped-clock reset assertion failed" severity failure;
        rst <= '0'; wait for 10 ns;
        assert delay_reset = '1' and ctrl_reset = '1' report "Stopped-clock reset deasserted" severity failure;
        running <= true;
        for edge in 1 to 42 loop wait until rising_edge(clk); end loop;
        wait for 0.1 ns;
        assert delay_reset = '0' and ctrl_reset = '1' severity failure;
        -- A second fault during the release sequence restarts both waits.
        rst <= '1'; wait for 0.1 ns;
        assert delay_reset = '1' and ctrl_reset = '1' severity failure;
        wait for 6 ns; rst <= '0'; check_sequence;
        wait for 30 ns;
        assert delay_reset = '0' and ctrl_reset = '0' report "Healthy reset sequence restarted" severity failure;
        report "PASS: ADC local reset release, IDELAY ordering, asynchronous assertion, stopped clock, interrupted sequence";
        finish;
    end process;
end;
