library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Shared or independent lane targets. Each individual LOAD moves
-- at most eight taps; EN_VTC guards and settling follow UG571 VAR_LOAD mode.
entity adc_idelay_loader is
    generic (PER_LANE : boolean := false);
    port (clk, rst, vtc_request : in std_logic;
          target : in std_logic_vector(8 downto 0);
          counts : in std_logic_vector(71 downto 0);
          values : out std_logic_vector(71 downto 0);
          loads : out std_logic_vector(7 downto 0);
          en_vtc, ready : out std_logic;
          lane_targets : in std_logic_vector(71 downto 0) := (others => '0'));
end;
architecture rtl of adc_idelay_loader is
    type state_t is (vtc_on, freeze, inspect, prepare_load, pulse_load, settle, stable);
    signal state : state_t := vtc_on;
    signal timer : natural range 0 to 31 := 0;
    signal load_mask : std_logic_vector(7 downto 0) := (others => '0');
    signal applied, requested : std_logic_vector(71 downto 0) := (others => '0');
begin
    -- The same loader serves shared-eye training and per-lane deskew.
    targets : for lane in 0 to 7 generate
        requested(9*lane+8 downto 9*lane) <= lane_targets(9*lane+8 downto 9*lane) when PER_LANE else target;
    end generate;
    en_vtc <= '1' when state = vtc_on else '0';
    -- READY describes the requested VTC phase and all eight lane counts;
    -- the trainer waits for it before sampling the new candidate.
    ready <= '1' when (state = stable and requested = applied and vtc_request = '0')
                  or (state = vtc_on and timer = 31 and vtc_request = '1') else '0';
    -- Reset must restore VTC even if this channel's DCO is absent.
    process(clk, rst)
        variable current, wanted, next_count : integer;
        variable matched : boolean;
    begin
        if rst = '1' then
                loads <= (others => '0');
                state <= vtc_on; timer <= 0;
                values <= (others => '0'); load_mask <= (others => '0');
                applied <= (others => '0');
        elsif rising_edge(clk) then
                loads <= (others => '0');
                case state is
                    when vtc_on =>
                        if timer < 31 then timer <= timer+1;
                        elsif vtc_request = '0' then
                            timer <= 0; state <= freeze;
                        end if;
                    when freeze =>
                        -- Allow EN_VTC to settle low before issuing LOAD.
                        if timer = 15 then state <= inspect; timer <= 0;
                        else timer <= timer+1; end if;
                    when inspect =>
                        -- Read each lane's actual COUNTVALUEOUT. Even a shared
                        -- target does not imply that all current counts agree.
                        matched := true;
                        for lane in 0 to 7 loop
                            wanted := to_integer(unsigned(requested(9*lane+8 downto 9*lane)));
                            current := to_integer(unsigned(counts(9*lane+8 downto 9*lane)));
                            next_count := current; load_mask(lane) <= '0';
                            if current /= wanted then
                                -- UG571 limits one VAR_LOAD update to eight
                                -- taps; repeat inspect/load until target.
                                matched := false; load_mask(lane) <= '1';
                                if wanted > current then
                                    if wanted-current > 8 then next_count := current+8;
                                    else next_count := wanted; end if;
                                else
                                    if current-wanted > 8 then next_count := current-8;
                                    else next_count := wanted; end if;
                                end if;
                            end if;
                            values(9*lane+8 downto 9*lane) <= std_logic_vector(to_unsigned(next_count,9));
                        end loop;
                        if matched then applied <= requested; timer <= 0; state <= settle;
                        else state <= prepare_load; end if;
                    when prepare_load => state <= pulse_load;
                    when pulse_load => loads <= load_mask; timer <= 0; state <= settle;
                    when settle =>
                        if timer = 15 then state <= stable;
                        else timer <= timer+1; end if;
                    when stable =>
                        -- Resume VTC for the final verification and run mode;
                        -- otherwise accept the trainer's next tap request.
                        if vtc_request = '1' then
                            timer <= 0; state <= vtc_on;
                        elsif requested /= applied or load_mask /= x"00" then
                            state <= inspect;
                        end if;
                end case;
        end if;
    end process;
end;
