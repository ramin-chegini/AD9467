library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.adc_training_pkg.all;
entity tb_adc_lane_training is end;
architecture test of tb_adc_lane_training is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    -- 0 disjoint eyes; 1 common eye; 2 absent lane; 3 forbidden PN state;
    -- 4 corruption after VTC; 5 narrow eye; 6 one-lane word-phase error.
    signal fault : natural range 0 to 6 := 0;
    signal done, failed, deskew : std_logic_vector(5 downto 0);
    signal apply : std_logic := '0';
    type modes_t is array(0 to 5) of std_logic_vector(2 downto 0);
    type targets_t is array(0 to 5) of std_logic_vector(71 downto 0);
    signal modes : modes_t;
    signal targets : targets_t;
begin
    clk <= not clk after 2.5 ns;
    cases : for test_mode in 1 to 6 generate
        signal q1, q2 : std_logic_vector(7 downto 0) := (others => '0');
        signal counts, values : std_logic_vector(71 downto 0) := (others => '0');
        signal loads, bad_lanes : std_logic_vector(7 downto 0);
        signal vtc, request, ready : std_logic;
        signal tap : std_logic_vector(8 downto 0);
        signal data : adc_word;
    begin
        dut : entity work.adc_lane_pn9_trainer
            generic map(TAP_LAST => 80, MIN_WINDOW_POINTS => 4,
                        ACQUIRE_WORDS => 8, ACQUIRE_TIMEOUT => 32,
                        TEST_WORDS => 520, FINAL_WORDS => 1024)
            port map(clk,rst,'1',ready,q1,q2,"010",apply,'1',tap,request,
                     modes(test_mode-1),data,done(test_mode-1),failed(test_mode-1),
                     targets(test_mode-1),deskew(test_mode-1),bad_lanes);
        loader : entity work.adc_idelay_loader
            generic map(PER_LANE => true)
            port map(clk,rst,request,tap,counts,values,loads,vtc,ready,targets(test_mode-1));
        process(clk)
            variable gap : integer;
            variable off_cycles : natural := 0;
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    for lane in 0 to 7 loop
                        counts(9*lane+8 downto 9*lane) <= std_logic_vector(to_unsigned(9+lane,9));
                    end loop;
                    off_cycles := 0;
                else
                    if vtc = '0' then off_cycles := off_cycles+1; else off_cycles := 0; end if;
                    for lane in 0 to 7 loop
                        if loads(lane) = '1' then
                            assert off_cycles >= 10 report "Deskew LOAD before VTC guard" severity failure;
                            gap := to_integer(unsigned(values(9*lane+8 downto 9*lane)))-to_integer(unsigned(counts(9*lane+8 downto 9*lane)));
                            assert abs(gap) <= 8 report "Deskew IDELAY step exceeds eight" severity failure;
                            counts(9*lane+8 downto 9*lane) <= values(9*lane+8 downto 9*lane);
                        end if;
                    end loop;
                end if;
            end if;
        end process;
        -- Independent serial generator: never use the DUT predictor here.
        process
            variable lfsr : std_logic_vector(8 downto 0) := (others => '1');
            variable word : adc_word;
            variable odd_bits, even_bits, old_odd, old_even, first, second,
                     last_first, last_second : std_logic_vector(7 downto 0) := (others => '0');
            variable feedback : std_logic;
            variable count, lower, upper : natural;
        begin
            wait until falling_edge(clk);
            for bitno in 15 downto 0 loop
                feedback := lfsr(8) xor lfsr(4); word(bitno) := feedback;
                lfsr := lfsr(7 downto 0) & feedback;
            end loop;
            word(15) := not word(15);
            if fault = 3 then word := x"8000"; end if;
            for lane in 0 to 7 loop
                odd_bits(lane) := word(2*lane+1); even_bits(lane) := word(2*lane);
            end loop;
            case test_mode is
                when 1 => first := odd_bits; second := even_bits;
                when 2 => first := even_bits; second := odd_bits;
                when 3 => first := old_odd; second := even_bits;
                when 4 => first := old_even; second := odd_bits;
                when 5 => first := odd_bits; second := old_even;
                when 6 => first := even_bits; second := old_odd;
                when others => null;
            end case;
            old_odd := odd_bits; old_even := even_bits;
            if fault = 6 then
                q1(7) <= last_first(7); q2(7) <= last_second(7);
            end if;
            for lane in 0 to 7 loop
                count := to_integer(unsigned(counts(9*lane+8 downto 9*lane)));
                if fault = 1 then lower := 16; upper := 48;
                else lower := 8+16*(lane mod 3); upper := lower+24; end if;
                if fault = 5 and lane = 4 then upper := lower+8; end if;
                if count < lower or count > upper or (fault = 2 and lane = 0)
                    or (fault = 4 and vtc = '1' and lane = 5) then
                    q1(lane) <= '0'; q2(lane) <= '0';
                elsif not (fault = 6 and lane = 7) then
                    q1(lane) <= first(lane); q2(lane) <= second(lane);
                end if;
            end loop;
            last_first := first; last_second := second;
        end process;
    end generate;
    -- Independently verify seed reconstruction across multiple PN periods.
    process
        type histories_t is array(0 to 7) of std_logic_vector(8 downto 0);
        variable observations : histories_t := (others => (others => '0'));
        variable lfsr : std_logic_vector(8 downto 0) := (others => '1');
        variable word : adc_word;
        variable feedback : std_logic;
    begin
        for cycle in 1 to 1100 loop
            for bitno in 15 downto 0 loop
                feedback := lfsr(8) xor lfsr(4); word(bitno) := feedback;
                lfsr := lfsr(7 downto 0) & feedback;
            end loop;
            word(15) := not word(15);
            for lane in 0 to 7 loop
                observations(lane) := observations(lane)(7 downto 0) & word(2*lane);
                if cycle >= 9 then
                    assert pn9_seed(observations(lane),lane) = word report "PN9 seed recovery failed" severity failure;
                end if;
            end loop;
        end loop;
        wait;
    end process;
    process
    begin
        wait for 100 ns; rst <= '0';
        wait until done = "111111" or failed /= "000000" for 3 ms;
        assert done = "111111" and failed = "000000" report "Disjoint-eye deskew failed" severity failure;
        assert deskew = "111111" report "Deskew fallback was not exercised" severity failure;
        for i in 0 to 5 loop
            assert to_integer(unsigned(modes(i))) = i+1 report "Deskew selected wrong DDR mode" severity failure;
            for lane in 0 to 7 loop
                assert unsigned(targets(i)(9*lane+8 downto 9*lane)) = 20+16*(lane mod 3)
                    report "Deskew lane was not centered" severity failure;
            end loop;
        end loop;
        apply <= '1'; wait for 5 ns; apply <= '0'; wait for 10 ns;
        for i in 0 to 5 loop assert modes(i) = "010" report "Deskew APPLY failed" severity failure; end loop;
        fault <= 1; rst <= '1'; wait for 100 ns; rst <= '0';
        wait until done = "111111" or failed /= "000000" for 3 ms;
        assert done = "111111" and deskew = "000000" report "Common-tap path changed" severity failure;
        for i in 0 to 5 loop
            for lane in 0 to 7 loop assert unsigned(targets(i)(9*lane+8 downto 9*lane)) = 32 severity failure; end loop;
        end loop;
        for bad_case in 2 to 6 loop
            fault <= bad_case; rst <= '1'; wait for 100 ns; rst <= '0';
            wait until failed = "111111" or done /= "000000" for 3 ms;
            assert failed = "111111" and done = "000000"
                report "Deskew falsely accepted faulty case " & integer'image(bad_case) severity failure;
        end loop;
        report "PASS: PN seed, six DDR modes, independent eyes, shared-eye path, lane loss, forbidden PN, VTC corruption, narrow eye, word-phase error";
        finish;
    end process;
end;
