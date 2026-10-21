library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adc_training_pkg.all;

entity adc_pn9_trainer is
    -- A candidate is one pairing mode at one common IDELAY tap for this ADC.
    -- The default scan visits 0, 8, ... 504 for each of the six modes.
    generic (TAP_STEP : positive := 8; TAP_LAST : natural := 504;
             MIN_WINDOW_POINTS : positive := 4;
             ACQUIRE_WORDS : positive := 32; ACQUIRE_TIMEOUT : positive := 128;
             TEST_WORDS : positive := 1024; FINAL_WORDS : positive := 4096);
    port (clk, rst, enable, delay_ready : in std_logic;
          q1, q2 : in std_logic_vector(7 downto 0);
          manual_mode : in std_logic_vector(2 downto 0);
          manual_apply, manual_enable : in std_logic;
          tap_target : out std_logic_vector(8 downto 0);
          vtc_request : out std_logic;
          mode_out : out std_logic_vector(2 downto 0);
          data_out : out adc_word;
          done, failed : out std_logic);
end;

architecture rtl of adc_pn9_trainer is
    type state_t is (idle, wait_delay, warmup, acquire, verify, evaluate,
                     choose_best, wait_final_delay, wait_vtc, success, failure);
    signal state : state_t := idle;
    signal mode : std_logic_vector(2 downto 0) := "001";
    signal tap : natural range 0 to 511 := 0;
    signal prev1, prev2 : std_logic_vector(7 downto 0) := (others => '0');
    signal sample, expected : adc_word := (others => '0');
    signal timer : natural range 0 to 31 := 0;
    signal attempts : natural range 0 to ACQUIRE_TIMEOUT := 0;
    signal streak : natural range 0 to ACQUIRE_WORDS := 0;
    signal tested : natural range 0 to FINAL_WORDS+TEST_WORDS := 0;
    signal run_length, best_length : natural range 0 to 512 := 0;
    signal run_start, best_tap : natural range 0 to 511 := 0;
    signal best_mode : std_logic_vector(2 downto 0) := "001";
    signal point_pass, final_test : boolean := false;
begin
    assert TAP_LAST <= 511 and TAP_STEP <= 8 severity failure;
    tap_target <= std_logic_vector(to_unsigned(tap,9));
    mode_out <= mode;
    data_out <= sample;
    done <= '1' when state = success else '0';
    failed <= '1' when state = failure else '0';
    -- Return VTC before the final PN verification, keep it on in normal mode.
    vtc_request <= '1' when state = idle or state = wait_vtc or final_test
                           or state = failure else '0';
    process(clk, rst)
        variable good : boolean;
        variable length_now, start_now : natural;
    begin
        if rst = '1' then
                state <= idle; mode <= "001"; tap <= 0;
                run_length <= 0; best_length <= 0; run_start <= 0; best_tap <= 0;
                best_mode <= "001"; timer <= 0; streak <= 0; attempts <= 0;
                tested <= 0; final_test <= false; point_pass <= false;
                prev1 <= (others => '0'); prev2 <= (others => '0');
                sample <= (others => '0'); expected <= (others => '0');
        elsif rising_edge(clk) then
            -- Retain both IDDR bytes so assemble can try same-cycle and
            -- adjacent-cycle pairings without changing the input registers.
            prev1 <= q1; prev2 <= q2;
            sample <= assemble(q1,q2,prev1,prev2,mode);
            expected <= pn9_next(sample);
            -- Signal assignments use their previous values here: compare the
            -- registered sample with the prediction registered one cycle ago.
            -- 8000 is the offset-binary representation of the forbidden
            -- all-zero PN state. Reject DC/stuck inputs rather than false-lock.
            good := sample = expected and sample /= x"8000";
                case state is
                    when idle =>
                        if enable = '1' then state <= wait_delay; timer <= 0; end if;
                    when wait_delay =>
                        if delay_ready = '1' then timer <= 0; state <= warmup; end if;
                    when warmup =>
                        -- Discard samples after a tap or VTC transition.
                        if timer = 31 then
                            attempts <= 0; streak <= 0; state <= acquire;
                        else timer <= timer+1; end if;
                    when acquire =>
                        -- Find a contiguous PN9 sequence before the longer
                        -- verification; a single matching word is insufficient.
                        if good then
                            if streak = ACQUIRE_WORDS-1 then
                                tested <= 0; state <= verify;
                            else streak <= streak+1; end if;
                        else streak <= 0; end if;
                        if attempts = ACQUIRE_TIMEOUT-1 and not (good and streak = ACQUIRE_WORDS-1) then
                            point_pass <= false;
                            if final_test then state <= failure; else state <= evaluate; end if;
                        elsif attempts < ACQUIRE_TIMEOUT then attempts <= attempts+1; end if;
                    when verify =>
                        -- A candidate fails on its first sequence mismatch.
                        if not good then
                            point_pass <= false;
                            if final_test then state <= failure; else state <= evaluate; end if;
                        elsif (not final_test and tested = TEST_WORDS-1) or
                              (final_test and tested = FINAL_WORDS-1) then
                            point_pass <= true;
                            if final_test then state <= success; else state <= evaluate; end if;
                        else tested <= tested+1; end if;
                    when evaluate =>
                        -- Track the widest consecutive passing tap window.
                        -- Its midpoint is less sensitive to drift than an edge.
                        if point_pass then
                            length_now := run_length+1; start_now := run_start;
                            if run_length = 0 then start_now := tap; run_start <= tap; end if;
                            run_length <= length_now;
                            if length_now > best_length then
                                best_length <= length_now; best_mode <= mode;
                                best_tap <= start_now+((length_now-1)*TAP_STEP)/2;
                            end if;
                        else run_length <= 0; end if;
                        if tap+TAP_STEP > TAP_LAST then
                            -- Exhaust every tap before advancing the mode.
                            if mode = "110" then state <= choose_best;
                            else mode <= std_logic_vector(unsigned(mode)+1);
                                tap <= 0; run_length <= 0; state <= wait_delay;
                            end if;
                        else tap <= tap+TAP_STEP; state <= wait_delay; end if;
                    when choose_best =>
                        -- Reject isolated passing points and program the
                        -- selected midpoint before the final PN9 check.
                        if best_length < MIN_WINDOW_POINTS then state <= failure;
                        else mode <= best_mode; tap <= best_tap; state <= wait_final_delay; end if;
                    when wait_final_delay =>
                        if delay_ready = '1' then state <= wait_vtc; timer <= 0; end if;
                    when wait_vtc =>
                        -- Guard against the ready value from the old EN_VTC state.
                        if timer < 31 then timer <= timer+1;
                        elsif delay_ready = '1' then
                            final_test <= true; timer <= 0; state <= warmup;
                        end if;
                    when success =>
                        -- VIO override is opt-in and only acts on APPLY;
                        -- it changes pairing, not the trained IDELAY value.
                        if manual_enable = '1' and manual_apply = '1' then
                            if unsigned(manual_mode) >= 1 and unsigned(manual_mode) <= 6 then
                                mode <= manual_mode;
                            end if;
                        end if;
                    when failure => null; -- sticky until reset; never silently use a bad mode
                end case;
        end if;
    end process;
end;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adc_training_pkg.all;

-- Preserve the established common-tap scan. Only its failure invokes deskew.
-- Deskew first finds a reliable reference lane, then compares both bits of
-- every other lane with that reference PN sequence at independent delays.
entity adc_lane_pn9_trainer is
    generic (TAP_STEP : positive := 8; TAP_LAST : natural := 504;
             MIN_WINDOW_POINTS : positive := 4;
             ACQUIRE_WORDS : positive := 32; ACQUIRE_TIMEOUT : positive := 128;
             TEST_WORDS : positive := 1024; FINAL_WORDS : positive := 4096);
    port (clk, rst, enable, delay_ready : in std_logic;
          q1, q2 : in std_logic_vector(7 downto 0);
          manual_mode : in std_logic_vector(2 downto 0);
          manual_apply, manual_enable : in std_logic;
          tap_target : out std_logic_vector(8 downto 0);
          vtc_request : out std_logic;
          mode_out : out std_logic_vector(2 downto 0);
          data_out : out adc_word;
          done, failed : out std_logic;
          lane_targets : out std_logic_vector(71 downto 0);
          deskew_active : out std_logic;
          lane_fail : out std_logic_vector(7 downto 0));
end;
architecture rtl of adc_lane_pn9_trainer is
    type state_t is (common_scan, start_mode, wait_delay, warmup, acquire,
                     verify, evaluate, choose_lane, wait_final_delay,
                     wait_vtc, success, failure);
    signal state : state_t := common_scan;
    signal common_rst, common_vtc, common_done, common_failed : std_logic;
    signal common_tap : std_logic_vector(8 downto 0);
    signal common_mode : std_logic_vector(2 downto 0);
    signal common_data : adc_word;
    -- Eight 9-bit delays, packed as lane i = bits (9*i+8 downto 9*i).
    signal targets : std_logic_vector(71 downto 0) := (others => '0');
    signal mode : std_logic_vector(2 downto 0) := "001";
    signal anchor, lane : natural range 0 to 7 := 0;
    signal anchor_scan, final_test, point_pass : boolean := false;
    signal prev1, prev2 : std_logic_vector(7 downto 0) := (others => '0');
    signal sample, expected, reference_word : adc_word := (others => '0');
    signal history : std_logic_vector(7 downto 0) := (others => '0');
    signal timer : natural range 0 to 31 := 0;
    signal attempts : natural range 0 to ACQUIRE_TIMEOUT := 0;
    signal streak : natural range 0 to ACQUIRE_WORDS := 0;
    signal tested : natural range 0 to FINAL_WORDS+TEST_WORDS := 0;
    signal run_length, best_length : natural range 0 to 512 := 0;
    signal run_start, best_tap : natural range 0 to 511 := 0;
    signal failed_lanes : std_logic_vector(7 downto 0) := (others => '0');
begin
    assert TAP_LAST <= 511 and TAP_STEP <= 8 severity failure;
    assert TEST_WORDS >= 511 report "Deskew must verify at least a complete PN9 period" severity failure;
    common_rst <= rst when state = common_scan else '1';
    common : entity work.adc_pn9_trainer
        generic map(TAP_STEP, TAP_LAST, MIN_WINDOW_POINTS, ACQUIRE_WORDS,
                    ACQUIRE_TIMEOUT, TEST_WORDS, FINAL_WORDS)
        port map(clk, common_rst, enable, delay_ready, q1, q2,
                 manual_mode, manual_apply, manual_enable, common_tap,
                 common_vtc, common_mode, common_data, common_done, common_failed);
    lanes_out : for i in 0 to 7 generate
        lane_targets(9*i+8 downto 9*i) <= common_tap when state = common_scan
                                                    else targets(9*i+8 downto 9*i);
    end generate;
    tap_target <= common_tap when state = common_scan else targets(9*lane+8 downto 9*lane);
    mode_out <= common_mode when state = common_scan else mode;
    data_out <= common_data when state = common_scan else sample;
    vtc_request <= common_vtc when state = common_scan else
                   '1' when state = wait_vtc or final_test or state = failure else '0';
    done <= common_done when state = common_scan else '1' when state = success else '0';
    failed <= '1' when state = failure else '0';
    deskew_active <= '0' when state = common_scan else '1';
    lane_fail <= failed_lanes;
    process(clk, rst)
        variable predicted : adc_word;
        variable good : boolean;
        variable tap, length_now, start_now, next_lane : natural;
        procedure advance_mode is
        begin
            final_test <= false;
            if mode = "110" then state <= failure;
            else mode <= std_logic_vector(unsigned(mode)+1); state <= start_mode;
            end if;
        end procedure;
    begin
        if rst = '1' then
            state <= common_scan; targets <= (others => '0'); mode <= "001";
            anchor <= 0; lane <= 0; anchor_scan <= false; final_test <= false;
            point_pass <= false; failed_lanes <= (others => '0');
            prev1 <= (others => '0'); prev2 <= (others => '0');
            sample <= (others => '0'); expected <= (others => '0');
            reference_word <= (others => '0'); history <= (others => '0');
            timer <= 0; attempts <= 0; streak <= 0; tested <= 0;
            run_length <= 0; best_length <= 0; run_start <= 0; best_tap <= 0;
        elsif rising_edge(clk) then
            predicted := pn9_next(reference_word);
            -- The fallback datapath is idle while the common scan is in use.
            if state /= common_scan then
                prev1 <= q1; prev2 <= q2;
                sample <= assemble(q1,q2,prev1,prev2,mode);
                if state /= success and state /= failure then
                    expected <= pn9_next(sample);
                    history <= history(6 downto 0) & sample(2*anchor);
                    reference_word <= predicted;
                    -- Seed from one lane; other lanes may not yet be trained.
                    if state = warmup then
                        reference_word <= pn9_seed(history & sample(2*anchor), anchor);
                    end if;
                end if;
            end if;
            if final_test then
                good := sample = expected and sample /= x"8000";
            else
                good := sample(2*lane+1 downto 2*lane) = predicted(2*lane+1 downto 2*lane)
                        and predicted /= x"8000";
            end if;
            tap := to_integer(unsigned(targets(9*lane+8 downto 9*lane)));
            case state is
                when common_scan =>
                    -- A failed shared eye may still have valid separate lane
                    -- eyes. Try deskew before reporting a channel failure.
                    if common_failed = '1' then state <= start_mode; end if;
                when start_mode =>
                    targets <= (others => '0'); anchor <= 0; lane <= 0;
                    anchor_scan <= true; final_test <= false;
                    failed_lanes <= (others => '0');
                    run_length <= 0; best_length <= 0; state <= wait_delay;
                when wait_delay =>
                    if delay_ready = '1' then timer <= 0; state <= warmup; end if;
                when warmup =>
                    if timer = 31 then
                        attempts <= 0; streak <= 0; state <= acquire;
                    else timer <= timer+1; end if;
                when acquire =>
                    if good then
                        if streak = ACQUIRE_WORDS-1 then tested <= 0; state <= verify;
                        else streak <= streak+1; end if;
                    else streak <= 0; end if;
                    if attempts = ACQUIRE_TIMEOUT-1 and not (good and streak = ACQUIRE_WORDS-1) then
                        point_pass <= false;
                        if final_test then advance_mode; else state <= evaluate; end if;
                    elsif attempts < ACQUIRE_TIMEOUT then attempts <= attempts+1; end if;
                when verify =>
                    if not good then
                        point_pass <= false;
                        if final_test then advance_mode; else state <= evaluate; end if;
                    elsif (not final_test and tested = TEST_WORDS-1) or
                          (final_test and tested = FINAL_WORDS-1) then
                        point_pass <= true;
                        if final_test then state <= success; else state <= evaluate; end if;
                    else tested <= tested+1; end if;
                when evaluate =>
                    if point_pass then
                        length_now := run_length+1; start_now := run_start;
                        if run_length = 0 then start_now := tap; run_start <= tap; end if;
                        run_length <= length_now;
                        if length_now > best_length then
                            best_length <= length_now;
                            best_tap <= start_now+((length_now-1)*TAP_STEP)/2;
                        end if;
                    else run_length <= 0; end if;
                    if tap+TAP_STEP > TAP_LAST then state <= choose_lane;
                    else
                        targets(9*lane+8 downto 9*lane) <= std_logic_vector(to_unsigned(tap+TAP_STEP,9));
                        state <= wait_delay;
                    end if;
                when choose_lane =>
                    -- Fix this lane at its eye center, then scan the next one.
                    -- The final full-word test checks that all lanes agree.
                    run_length <= 0; best_length <= 0;
                    if best_length < MIN_WINDOW_POINTS then
                        failed_lanes(lane) <= '1';
                        if anchor_scan and anchor < 7 then
                            -- A disconnected first lane must not prevent trying
                            -- the other lanes as references (but it still must
                            -- pass its own scan before the ADC can be accepted).
                            targets <= (others => '0'); anchor <= anchor+1; lane <= anchor+1;
                            state <= wait_delay;
                        else advance_mode; end if;
                    else
                        targets(9*lane+8 downto 9*lane) <= std_logic_vector(to_unsigned(best_tap,9));
                        failed_lanes(lane) <= '0';
                        if anchor_scan then
                            anchor_scan <= false;
                            if anchor = 0 then next_lane := 1; else next_lane := 0; end if;
                        else
                            next_lane := lane+1;
                            if next_lane = anchor then next_lane := next_lane+1; end if;
                        end if;
                        if next_lane = 8 then state <= wait_final_delay;
                        else
                            lane <= next_lane;
                            targets(9*next_lane+8 downto 9*next_lane) <= (others => '0');
                            state <= wait_delay;
                        end if;
                    end if;
                when wait_final_delay =>
                    if delay_ready = '1' then state <= wait_vtc; timer <= 0; end if;
                when wait_vtc =>
                    if timer < 31 then timer <= timer+1;
                    elsif delay_ready = '1' then
                        final_test <= true; timer <= 0; state <= warmup;
                    end if;
                when success =>
                    if manual_enable = '1' and manual_apply = '1' then
                        if unsigned(manual_mode) >= 1 and unsigned(manual_mode) <= 6 then mode <= manual_mode; end if;
                    end if;
                when failure => null;
            end case;
        end if;
    end process;
end;
