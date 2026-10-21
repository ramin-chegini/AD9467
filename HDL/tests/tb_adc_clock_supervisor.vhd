library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_adc_clock_supervisor is end entity;
architecture test of tb_adc_clock_supervisor is
    constant T : time := 10 ns;
    signal clk : std_logic := '0';
    signal reset_n, locked, ready : std_logic := '0';
    signal mmcm_reset, locked_out, ready_out : std_logic;
    signal status : std_logic_vector(15 downto 0);
begin
    clk <= not clk after T/2;
    dut : entity work.adc_clock_supervisor
        generic map (RESET_CYCLES => 8, TIMEOUT_CYCLES => 40)
        port map (clk => clk, reset_n => reset_n, locked_async => locked,
                  ready_async => ready, mmcm_reset => mmcm_reset,
                  locked_sync_out => locked_out, ready_sync_out => ready_out,
                  debug_status => status);

    -- Check every recovery pulse, including while child clocks are stopped.
    process
    begin
        wait on mmcm_reset;
        if reset_n = '1' then
            assert clk = '1' and clk'last_event = 0 ns
                report "MMCM reset changed away from a parent clock edge" severity failure;
        end if;
    end process;
    process
        variable began : time;
    begin
        wait until falling_edge(reset_n) or rising_edge(mmcm_reset);
        began := now;
        wait until falling_edge(mmcm_reset);
        assert now-began >= 8*T report "MMCM reset too short" severity failure;
    end process;

    process
        procedure await_reset is
        begin
            wait until mmcm_reset = '1' for 2 us;
            assert mmcm_reset = '1' report "Recovery reset missing" severity failure;
            locked <= '0'; ready <= '0';
            wait until mmcm_reset = '0' for 2 us;
            assert mmcm_reset = '0' report "Recovery reset never released" severity failure;
        end procedure;
        procedure become_healthy is
        begin
            wait until falling_edge(clk);
            locked <= '1';
            wait for 6*T;
            ready <= '1';
            wait for 6*T;
            assert status(7 downto 6) = "11" and locked_out = '1' and ready_out = '1'
                report "Healthy clocks not recognized" severity failure;
        end procedure;
    begin
        wait for 3*T;
        assert mmcm_reset = '1' report "Startup must reset MMCM" severity failure;
        reset_n <= '1';
        wait until mmcm_reset = '0';
        -- An MMCM that never locks must be retried from the parent clock.
        await_reset;
        assert unsigned(status(15 downto 8)) = 1 report "Lock timeout not counted" severity failure;
        become_healthy;
        wait for 100*T;
        assert mmcm_reset = '0' and unsigned(status(15 downto 8)) = 1
            report "Healthy clocks were reset" severity failure;

        -- A short ready disturbance must not cause a reset loop.
        ready <= '0'; wait for 5*T; ready <= '1'; wait for 10*T;
        assert mmcm_reset = '0' and unsigned(status(15 downto 8)) = 1
            report "Transient ready loss retriggered reset" severity failure;

        -- Persistent IDELAY failure after RUN must restart calibration.
        ready <= '0';
        await_reset;
        assert unsigned(status(15 downto 8)) = 2 report "Ready loss not counted" severity failure;
        -- Locked but IDELAY never ready at startup is also retried.
        locked <= '1';
        await_reset;
        assert unsigned(status(15 downto 8)) = 3 report "Initial ready timeout not counted" severity failure;
        become_healthy;

        -- Simulate stopped MMCM outputs: no local output clock is supplied
        -- to this supervisor, and recovery must still complete.
        locked <= '0'; ready <= '0';
        await_reset;
        assert unsigned(status(15 downto 8)) = 4 report "Lost lock not counted" severity failure;
        become_healthy;
        reset_n <= '0'; wait for 1 ns;
        assert mmcm_reset = '1' and locked_out = '0' and ready_out = '0'
            report "External reset was not asynchronous" severity failure;
        assert unsigned(status(15 downto 8)) = 0 report "External reset did not clear diagnostics" severity failure;
        report "PASS: ADC clock lock/IDELAY timeout and stopped-clock recovery" severity note;
        stop;
        wait;
    end process;

    process
    begin
        wait for 20 us;
        assert false report "Clock supervisor test timed out" severity failure;
    end process;
end architecture;
