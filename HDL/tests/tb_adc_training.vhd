library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.adc_training_pkg.all;
entity tb_adc_training is end;
architecture test of tb_adc_training is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    -- 0: valid eye, 1: zero input, 2: forbidden PN state, 3: bad after VTC.
    signal corrupt : natural range 0 to 3 := 0;
    signal manual_apply : std_logic := '0';
    signal manual_mode : std_logic_vector(2 downto 0) := "010";
    signal done, failed : std_logic_vector(5 downto 0);
    type modes_t is array(0 to 5) of std_logic_vector(2 downto 0);
    type taps_t is array(0 to 5) of std_logic_vector(8 downto 0);
    signal modes : modes_t;
    signal taps : taps_t;
begin
    clk <= not clk after 2.5 ns;
    cases : for test_mode in 1 to 6 generate
        signal q1, q2 : std_logic_vector(7 downto 0) := (others => '0');
        signal counts, values : std_logic_vector(71 downto 0) := (others => '0');
        signal loads : std_logic_vector(7 downto 0);
        signal vtc, vtc_request, ready : std_logic;
        signal data : adc_word;
    begin
        dut : entity work.adc_pn9_trainer
            generic map(TAP_LAST => 64, MIN_WINDOW_POINTS => 3,
                        ACQUIRE_WORDS => 8, ACQUIRE_TIMEOUT => 32,
                        TEST_WORDS => 520, FINAL_WORDS => 1024)
            port map(clk,rst,'1',ready,q1,q2,manual_mode,manual_apply,'1',
                     taps(test_mode-1),vtc_request,modes(test_mode-1),data,
                     done(test_mode-1),failed(test_mode-1));
        loader : entity work.adc_idelay_loader
            port map(clk,rst,vtc_request,taps(test_mode-1),counts,values,loads,vtc,ready);
        -- Tap actuator model: independently check step size and VTC guard.
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
                            assert off_cycles >= 10 report "LOAD before VTC guard" severity failure;
                            gap := to_integer(unsigned(values(9*lane+8 downto 9*lane)))-to_integer(unsigned(counts(9*lane+8 downto 9*lane)));
                            assert abs(gap) <= 8 report "IDELAY jump exceeds eight taps" severity failure;
                            counts(9*lane+8 downto 9*lane) <= values(9*lane+8 downto 9*lane);
                        end if;
                    end loop;
                end if;
            end if;
        end process;
        -- Independent serial LFSR stimulus, split into physical DDR half words.
        process
            variable lfsr : std_logic_vector(8 downto 0) := (others => '1');
            variable word : adc_word;
            variable odd_bits, even_bits, old_odd, old_even, first, second : std_logic_vector(7 downto 0) := (others => '0');
            variable feedback : std_logic;
            variable count : natural;
        begin
            wait until falling_edge(clk);
            for bitno in 15 downto 0 loop
                feedback := lfsr(8) xor lfsr(4);
                word(bitno) := feedback;
                lfsr := lfsr(7 downto 0) & feedback;
            end loop;
            word(15) := not word(15);
            if corrupt = 2 then word := x"8000"; end if;
            for bitno in 0 to 7 loop
                odd_bits(bitno) := word(2*bitno+1); even_bits(bitno) := word(2*bitno);
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
            count := to_integer(unsigned(counts(8 downto 0)));
            if count < 16 or count > 48 or corrupt = 1 or (corrupt = 3 and vtc = '1') then
                first := (others => '0'); second := (others => '0');
            end if;
            q1 <= first; q2 <= second;
        end process;
    end generate;
    process
    begin
        assert pn9_next(x"FFFF") = x"87BE" severity failure;
        assert pn9_next(x"87BE") = x"AE64" severity failure;
        assert pn9_next(x"AE64") = x"929D" severity failure;
        wait for 100 ns; rst <= '0';
        wait until done = "111111" for 2 ms;
        assert done = "111111" report "Training timeout" severity failure;
        assert failed = "000000" severity failure;
        for i in 0 to 5 loop
            assert to_integer(unsigned(modes(i))) = i+1 report "Wrong mode for case " & integer'image(i+1) severity failure;
            assert unsigned(taps(i)) = 32 report "Not centered in passing eye" severity failure;
        end loop;
        -- Changing only requested mode must not change active selection.
        wait for 50 ns;
        assert modes(0) = "001" severity failure;
        manual_apply <= '1'; wait for 5 ns; manual_apply <= '0'; wait for 10 ns;
        for i in 0 to 5 loop assert modes(i) = "010" severity failure; end loop;
        -- Reset/retrain with a bad or disconnected stream must fail closed.
        corrupt <= 1; rst <= '1'; wait for 100 ns; rst <= '0';
        wait until failed = "111111" for 2 ms;
        assert failed = "111111" and done = "000000" report "Bad data falsely accepted" severity failure;
        corrupt <= 2; rst <= '1'; wait for 100 ns; rst <= '0';
        wait until failed = "111111" for 2 ms;
        assert failed = "111111" and done = "000000" report "Forbidden PN state falsely accepted" severity failure;
        corrupt <= 3; rst <= '1'; wait for 100 ns; rst <= '0';
        wait until failed = "111111" for 2 ms;
        assert failed = "111111" and done = "000000" report "Final VTC check failed to reject bad data" severity failure;
        for i in 0 to 5 loop
            assert unsigned(taps(i)) = 32 report "Final test did not use the chosen eye center" severity failure;
        end loop;
        report "PASS: six modes, eye center, IDELAY steps, APPLY, reset, bad/stuck PN, final VTC check";
        finish;
    end process;
end;
