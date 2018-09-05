library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.SampleProbChipBiasConfigRecords.all;

entity DistributionAddressGenerator is
	port(
		Clock_CI            : in  std_logic;
		Reset_RI            : in  std_logic;

		Timestep_SI         : in  std_logic;
		AddressReset_SI     : in  std_logic;
		RefractoryPeriod_DI : in  std_logic_vector(SPIKEEXT_LENGTH - 1 downto 0);

		Address_DO          : out unsigned(CHANNEL_STEPS_SIZE - 1 downto 0));
end entity DistributionAddressGenerator;

architecture Behavioral of DistributionAddressGenerator is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stCheckReset, stRefractoryTimeout);
	attribute syn_enum_encoding of tState : type is "onehot";

	signal State_DP, State_DN : tState;

	signal RefractoryPeriod_D                         : unsigned(5 downto 0);
	signal RefractoryCounter_DP, RefractoryCounter_DN : unsigned(5 downto 0);

	signal ResetAck_S, ResetAddress_S : std_logic;

	signal AddressZero_S, AddressIncrease_S : std_logic;
begin
	-- Decode refractory period into a useable number.
	-- Smaller by 1 because the current timestep we're in already counts!
	with RefractoryPeriod_DI select RefractoryPeriod_D <=
		to_unsigned(0, 6) when "000",
		to_unsigned(0, 6) when "001",
		to_unsigned(2, 6) when "010",
		to_unsigned(6, 6) when "011",
		to_unsigned(14, 6) when "100",
		to_unsigned(30, 6) when others;

	addressResetKeeper : entity work.BufferClear
		port map(Clock_CI        => Clock_CI,
			     Reset_RI        => Reset_RI,
			     Clear_SI        => ResetAck_S,
			     InputSignal_SI  => AddressReset_SI,
			     OutputSignal_SO => ResetAddress_S);

	addressGeneratorSM : process(State_DP, RefractoryPeriod_D, RefractoryCounter_DP, Timestep_SI, ResetAddress_S)
	begin
		-- Keep state by default.
		State_DN <= State_DP;

		-- Keep value by default.
		RefractoryCounter_DN <= RefractoryCounter_DP;

		ResetAck_S <= '0';

		AddressZero_S     <= '0';
		AddressIncrease_S <= '0';

		case State_DP is
			when stIdle =>
				-- Idle here until a new timestep happens, then check if a reset signal came in
				-- during the previous timestep.
				if Timestep_SI = '1' then
					State_DN <= stCheckReset;
				end if;
				
				-- Reset address as soon as possible, but defer book-keeping to when a
				-- timestep arrives.
				AddressZero_S <= ResetAddress_S;

			when stCheckReset =>
				-- If a reset signal was detected during the previous timestamp, we ACK it
				-- and set the address counter back to zero.
				if ResetAddress_S = '1' then
					ResetAck_S <= '1';

					AddressZero_S <= '1';

					State_DN <= stRefractoryTimeout;
				else
					-- No reset, and we're not in a refractory period timeout, so just increase
					-- the address and go back to idle.
					AddressIncrease_S <= '1';

					State_DN <= stIdle;
				end if;

			when stRefractoryTimeout =>
				-- Wait for enough timesteps to pass, as dictated by the refractory period.
				if RefractoryCounter_DP = RefractoryPeriod_D then
					-- Reset and return to idle when done.
					RefractoryCounter_DN <= (others => '0');

					State_DN <= stIdle;
				elsif Timestep_SI = '1' then
					-- Else wait on a new timestep to pass and increase count.
					RefractoryCounter_DN <= RefractoryCounter_DP + 1;
				end if;

			when others => null;
		end case;
	end process addressGeneratorSM;

	addressGeneratorRegUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			State_DP <= stIdle;

			RefractoryCounter_DP <= (others => '0');
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;

			RefractoryCounter_DP <= RefractoryCounter_DN;
		end if;
	end process addressGeneratorRegUpdate;

	currentAddressGenerator : entity work.ContinuousCounter
		generic map(
			SIZE              => CHANNEL_STEPS_SIZE,
			RESET_ON_OVERFLOW => true,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => AddressZero_S,
			Enable_SI    => AddressIncrease_S,
			DataLimit_DI => to_unsigned(CHANNEL_STEPS - 1, CHANNEL_STEPS_SIZE),
			Overflow_SO  => open,
			Data_DO      => Address_DO);
end architecture Behavioral;
