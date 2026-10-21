library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- One write-only SPI sequencer broadcasts identical settings to all four ADCs.
-- PN9 validates the received stream; no SPI readback is claimed.
entity ad9467_startup is
    generic (POWER_WAIT_CYCLES : positive := 2000000; -- 100 ms at 20 MHz
             TRAIN_TIMEOUT_CYCLES : positive := 10000000; -- 500 ms at 20 MHz
             FLUSH_CYCLES : positive := 2048;
             SPI_HALF_PERIOD : positive := 4);
    port (clk, reset_n, clocks_ready : in std_logic;
          trained_async, failed_async : in std_logic_vector(3 downto 0);
          spi_clk, spi_csn, spi_data : out std_logic;
          train_enable, run_ready, startup_failed : out std_logic);
end;
architecture rtl of ad9467_startup is
    type commands_t is array(natural range <>) of std_logic_vector(23 downto 0);
    -- Preserve board analog setup. Explicitly select offset binary during PN9;
    -- restore the previous twos-complement working format before RUN.
    -- Each 24-bit frame is a 16-bit write instruction followed by 8 data bits.
    -- 001408 selects offset binary; 000D06 enables PN9; 00FF01 applies writes.
    constant CONFIG : commands_t := (
        x"000018", x"000800", x"003622", x"000F00", x"001000",
        x"001408", x"001500", x"001600", x"00180A", x"002C00",
        x"000D06", x"010720", x"00FF01");
    -- Leave test mode, select twos complement, then apply the new settings.
    constant NORMAL : commands_t := (x"000D00", x"001409", x"00FF01");
    -- The four receivers train independently in their DCO domains. This
    -- controller crosses only their sticky status into the control domain.
    type state_t is (power_wait, config_send, config_wait, training,
                     normal_send, normal_wait, flush, running, fault);
    signal state : state_t := power_wait;
    signal index : natural range 0 to CONFIG'high := 0;
    signal wait_count : natural range 0 to POWER_WAIT_CYCLES := 0;
    signal timeout_count : natural range 0 to TRAIN_TIMEOUT_CYCLES := 0;
    signal flush_count : natural range 0 to FLUSH_CYCLES := 0;
    signal trained_meta, trained_sync, failed_meta, failed_sync : std_logic_vector(3 downto 0) := (others => '0');
    signal ready_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal reset_sync : std_logic_vector(2 downto 0) := (others => '0');
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of trained_meta, trained_sync, failed_meta, failed_sync, ready_sync, reset_sync : signal is "TRUE";
    signal spi_start, spi_done, spi_busy : std_logic := '0';
    signal command, shift : std_logic_vector(23 downto 0) := (others => '0');
    signal sck : std_logic := '0';
    -- SCLK = clk / (2 * SPI_HALF_PERIOD): 2.5 MHz with the default 20 MHz clk.
    signal divider : natural range 0 to SPI_HALF_PERIOD-1 := 0;
    signal bit_index : natural range 0 to 23 := 23;
begin
    spi_clk <= sck;
    run_ready <= '1' when state = running and reset_sync(2) = '1' and clocks_ready = '1' else '0';
    train_enable <= '1' when state = training or state = normal_send or state = normal_wait
                         or state = flush or state = running else '0';
    startup_failed <= '1' when state = fault else '0';
    process(clk, reset_n)
    begin
        if reset_n = '0' then reset_sync <= (others => '0');
        elsif rising_edge(clk) then reset_sync <= reset_sync(1 downto 0) & '1'; end if;
    end process;
    process(clk)
    begin
        if rising_edge(clk) then
            trained_meta <= trained_async; trained_sync <= trained_meta;
            failed_meta <= failed_async; failed_sync <= failed_meta;
            ready_sync <= ready_sync(0) & clocks_ready;
            spi_start <= '0';
            if reset_sync(2) = '0' then
                state <= power_wait; index <= 0; wait_count <= 0;
                timeout_count <= 0; flush_count <= 0;
            else
                case state is
                    when power_wait =>
                        -- Start the 100 ms delay only after clock lock is stable.
                        if ready_sync(1) = '0' then wait_count <= 0;
                        elsif wait_count = POWER_WAIT_CYCLES-1 then state <= config_send;
                        else wait_count <= wait_count+1; end if;
                    when config_send =>
                        command <= CONFIG(index); spi_start <= '1'; state <= config_wait;
                    when config_wait =>
                        if spi_done = '1' then
                            if index = CONFIG'high then state <= training; timeout_count <= 0;
                            else index <= index+1; state <= config_send; end if;
                        end if;
                    when training =>
                        -- Keep all ADCs in PN9 mode until every receiver has
                        -- passed; a failed lane or watchdog expiry blocks RUN.
                        if failed_sync /= "0000" or timeout_count = TRAIN_TIMEOUT_CYCLES-1 then state <= fault;
                        elsif trained_sync = "1111" then index <= 0; state <= normal_send;
                        else timeout_count <= timeout_count+1; end if;
                    when normal_send =>
                        command <= NORMAL(index); spi_start <= '1'; state <= normal_wait;
                    when normal_wait =>
                        if spi_done = '1' then
                            if index = NORMAL'high then state <= flush; flush_count <= 0;
                            else index <= index+1; state <= normal_send; end if;
                        end if;
                    when flush =>
                        -- Hold the downstream FIFOs closed while PN9 and the
                        -- format transition drain from the receive pipeline.
                        if flush_count = FLUSH_CYCLES-1 then state <= running;
                        else flush_count <= flush_count+1; end if;
                    when running =>
                        if ready_sync(1) = '0' then state <= fault; end if;
                    when fault => null;
                end case;
                if state /= power_wait and ready_sync(1) = '0' then state <= fault; end if;
            end if;
        end if;
    end process;
    -- Mode-0 SPI. Change data on falling SCLK, ADC samples on rising SCLK.
    process(clk)
    begin
        if rising_edge(clk) then
            spi_done <= '0';
            if reset_sync(2) = '0' then
                sck <= '0'; spi_csn <= '1'; spi_data <= '0'; spi_busy <= '0';
                divider <= 0; bit_index <= 23;
            elsif spi_busy = '0' then
                if spi_start = '1' then
                    shift <= command; bit_index <= 23; spi_data <= command(23);
                    spi_csn <= '0'; sck <= '0'; divider <= 0; spi_busy <= '1';
                end if;
            elsif divider = SPI_HALF_PERIOD-1 then
                divider <= 0;
                if sck = '0' then sck <= '1';
                else
                    sck <= '0';
                    if bit_index = 0 then
                        spi_csn <= '1'; spi_busy <= '0'; spi_done <= '1';
                    else
                        shift <= shift(22 downto 0) & '0';
                        spi_data <= shift(22); bit_index <= bit_index-1;
                    end if;
                end if;
            else divider <= divider+1; end if;
        end if;
    end process;
end;
