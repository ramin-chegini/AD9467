library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package adc_training_pkg is
    subtype adc_word is std_logic_vector(15 downto 0);
    -- AD9467 offset-binary PN9: x^9+x^5+1, MSB first, formatter flips bit 15.
    -- Datasheet Table 9: FFFF -> 87BE -> AE64 -> 929D.
    function pn9_next(w : adc_word) return adc_word;
    -- Recover the current PN word from nine successive even-bit observations
    -- on one physical DDR lane (oldest observation is bit 8).
    function pn9_seed(observations : std_logic_vector(8 downto 0);
                      lane : natural) return adc_word;
    function assemble(q1, q2, prev1, prev2 : std_logic_vector(7 downto 0);
                      mode : std_logic_vector(2 downto 0)) return adc_word;
end package;

package body adc_training_pkg is
    function pn9_next(w : adc_word) return adc_word is
        -- Keep the last nine PN bits and shift out the next 16 bits.
        -- Only bit 15 is affected by output formatting, so these nine bits
        -- can seed the next prediction without undoing the formatter first.
        variable history : std_logic_vector(8 downto 0) := w(8 downto 0);
        variable result : adc_word;
        variable feedback : std_logic;
    begin
        for i in 15 downto 0 loop
            feedback := history(8) xor history(4);
            result(i) := feedback;
            history := history(7 downto 0) & feedback;
        end loop;
        result(15) := not result(15);
        return result;
    end;

    type matrix_t is array(0 to 8) of std_logic_vector(17 downto 0);
    type masks_t is array(0 to 15) of std_logic_vector(8 downto 0);
    type seeds_t is array(0 to 7) of masks_t;
    function make_seeds return seeds_t is
        variable table : seeds_t;
        variable matrix : matrix_t;
        variable swap : std_logic_vector(17 downto 0);
        variable word : adc_word;
        variable pivot : natural;
    begin
        for lane in 0 to 7 loop
            matrix := (others => (others => '0'));
            for row in 0 to 8 loop
                matrix(row)(9+row) := '1';
                for col in 0 to 8 loop
                    word := (others => '0'); word(col) := '1';
                    for step in 0 to row loop word := pn9_next(word); end loop;
                    matrix(row)(col) := word(2*lane);
                end loop;
            end loop;
            -- Constant GF(2) elimination; no run-time divider or search.
            for col in 0 to 8 loop
                pivot := col;
                while pivot < 8 and matrix(pivot)(col) /= '1' loop pivot := pivot+1; end loop;
                assert matrix(pivot)(col) = '1' report "PN9 observation matrix is singular" severity failure;
                swap := matrix(col); matrix(col) := matrix(pivot); matrix(pivot) := swap;
                for row in 0 to 8 loop
                    if row /= col and matrix(row)(col) = '1' then
                        matrix(row) := matrix(row) xor matrix(col);
                    end if;
                end loop;
            end loop;
            for obs in 0 to 8 loop
                word := (others => '0');
                for col in 0 to 8 loop word(col) := matrix(col)(9+obs); end loop;
                for step in 1 to 9 loop word := pn9_next(word); end loop;
                word(15) := not word(15); -- Store linear part; formatter is affine.
                for bitno in 0 to 15 loop table(lane)(bitno)(8-obs) := word(bitno); end loop;
            end loop;
        end loop;
        return table;
    end;
    -- Build the masks at elaboration. Hardware uses fixed XOR/AND networks.
    constant SEED_MASKS : seeds_t := make_seeds;
    function pn9_seed(observations : std_logic_vector(8 downto 0);
                      lane : natural) return adc_word is
        variable word : adc_word := (others => '0');
    begin
        for bitno in 0 to 15 loop
            for obs in 0 to 8 loop
                word(bitno) := word(bitno) xor (observations(obs) and SEED_MASKS(lane)(bitno)(obs));
            end loop;
        end loop;
        word(15) := not word(15);
        return word;
    end;

    function assemble(q1, q2, prev1, prev2 : std_logic_vector(7 downto 0);
                      mode : std_logic_vector(2 downto 0)) return adc_word is
        variable high_bits, low_bits : std_logic_vector(7 downto 0);
        variable result : adc_word;
    begin
        -- The mode number selects bit order on each lane and which half, if any,
        -- comes from the previous DCO cycle. Q1/Q2 are IDDRE1 outputs.
        case mode is
            when "010" => high_bits := q2;    low_bits := q1;    -- mode 2
            when "011" => high_bits := q1;    low_bits := prev2; -- mode 3
            when "100" => high_bits := prev2; low_bits := q1;    -- mode 4
            when "101" => high_bits := prev1; low_bits := q2;    -- mode 5
            when "110" => high_bits := q2;    low_bits := prev1; -- mode 6
            when others => high_bits := q1;   low_bits := q2;    -- mode 1
        end case;
        for i in 0 to 7 loop
            result(2*i+1) := high_bits(i);
            result(2*i) := low_bits(i);
        end loop;
        return result;
    end;
end package body;
