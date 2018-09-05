library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.ShiftRegisterModes.all;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;
use work.SampleProbChipBiasConfigRecords.all;

entity SampleProbStateMachine is
	port(
		Clock_CI             : in  std_logic;
		Reset_RI             : in  std_logic;

		-- Bias configuration outputs (to chip)
		ChipBiasSelect_SO    : out std_logic;
		ChipBiasClock_CBO    : out std_logic;
		ChipBiasBitIn_DO     : out std_logic;
		ChipBiasLatch_SBO    : out std_logic;

		-- Reset distribution after spike signals.
		DistributionReset_SI : in  std_logic_vector(CHANNEL_NUMBER - 1 downto 0);
		AERReset_SI          : in  std_logic;

		-- Next timestep for RNG.
		Timestep_SI          : in  std_logic;

		-- SM in use.
		BiasSMInUse_SO       : out std_logic;

		-- Configuration inputs
		BiasConfig_DI        : in  tSampleProbBiasConfig;
		ChipConfig_DI        : in  tSampleProbChipConfig;

		-- Debug
		Timestep_SO          : out std_logic);
end entity SampleProbStateMachine;

architecture Behavioral of SampleProbStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stAckAndLoadBias, stPrepareSendBias, stSendBias, stLatchBias, stAckAndLoadChip, stPrepareSendChip, stSendChip, stLatchChip, stDelay, stDelayChip, stWaitAckAndLoadChip);
	attribute syn_enum_encoding of tState : type is "onehot";

	signal State_DP, State_DN : tState;

	-- Bias clock frequency in MHz.
	constant BIAS_CLOCK_FREQ : real := 6.5; -- 1.6;

	-- How long the latch should be asserted, based on bias clock frequency.
	constant LATCH_LENGTH : integer := 1;

	-- Calculated values in cycles.
	constant BIAS_CLOCK_CYCLES : integer := integer(LOGIC_CLOCK_FREQ_REAL / BIAS_CLOCK_FREQ);
	constant LATCH_CYCLES      : integer := BIAS_CLOCK_CYCLES * LATCH_LENGTH;

	-- Calcualted length of cycles counter. Based on latch cycles, since biggest value.
	constant WAIT_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(LATCH_CYCLES))));

	-- Counts number of sent bits. Biggest value is 573 bits of bias SR, so 10 bits are enough.
	constant SENT_BITS_COUNTER_SIZE : integer := 10;

	-- Chip changes and acknowledges.
	signal ChipChangedInput_D        : std_logic_vector(INPUT_REG_LENGTH - 1 downto 0);
	signal ChipChanged_S, ChipSent_S : std_logic;

	-- Bias changes and acknowledges.
	signal BiasChangedInput_D        : std_logic_vector(BIASGEN_REG_LENGTH - 1 downto 0);
	signal BiasChanged_S, BiasSent_S : std_logic;

	-- Data shift registers for output.
	signal BiasSRMode_S                  : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal BiasSRInput_D, BiasSROutput_D : std_logic_vector(BIASGEN_REG_LENGTH - 1 downto 0);

	signal ChipSRMode_S                  : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal ChipSRInput_D, ChipSROutput_D : std_logic_vector(INPUT_REG_LENGTH - 1 downto 0);

	-- Counter for keeping track of output bits.
	signal SentBitsCounterClear_S, SentBitsCounterEnable_S : std_logic;
	signal SentBitsCounterData_D                           : unsigned(SENT_BITS_COUNTER_SIZE - 1 downto 0);

	-- Counter to introduce delays between operations, and generate the clock.
	signal WaitCyclesCounterClear_S, WaitCyclesCounterEnable_S : std_logic;
	signal WaitCyclesCounterData_D                             : unsigned(WAIT_CYCLES_COUNTER_SIZE - 1 downto 0);

	-- Timestep from RNG clock to advance to next step value.
	signal TimestepRisingEdge_S, Timestep_S : std_logic;

	-- Current channel data outputs.
	signal Channel0_D, Channel1_D, Channel2_D, Channel3_D     : std_logic_vector(CHANNEL_LENGTH - 1 downto 0);
	signal Channel4_D, Channel5_D, Channel6_D, Channel7_D     : std_logic_vector(CHANNEL_LENGTH - 1 downto 0);
	signal Channel8_D, Channel9_D, Channel10_D, Channel11_D   : std_logic_vector(CHANNEL_LENGTH - 1 downto 0);
	signal Channel12_D, Channel13_D, Channel14_D, Channel15_D : std_logic_vector(CHANNEL_LENGTH - 1 downto 0);

	signal Channel0Write_S, Channel1Write_S, Channel2Write_S, Channel3Write_S     : std_logic;
	signal Channel4Write_S, Channel5Write_S, Channel6Write_S, Channel7Write_S     : std_logic;
	signal Channel8Write_S, Channel9Write_S, Channel10Write_S, Channel11Write_S   : std_logic;
	signal Channel12Write_S, Channel13Write_S, Channel14Write_S, Channel15Write_S : std_logic;

	signal Channel0Address_D, Channel1Address_D, Channel2Address_D, Channel3Address_D     : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
	signal Channel4Address_D, Channel5Address_D, Channel6Address_D, Channel7Address_D     : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
	signal Channel8Address_D, Channel9Address_D, Channel10Address_D, Channel11Address_D   : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
	signal Channel12Address_D, Channel13Address_D, Channel14Address_D, Channel15Address_D : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);

	signal Channel0CurrentAddress_D, Channel1CurrentAddress_D, Channel2CurrentAddress_D, Channel3CurrentAddress_D     : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
	signal Channel4CurrentAddress_D, Channel5CurrentAddress_D, Channel6CurrentAddress_D, Channel7CurrentAddress_D     : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
	signal Channel8CurrentAddress_D, Channel9CurrentAddress_D, Channel10CurrentAddress_D, Channel11CurrentAddress_D   : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
	signal Channel12CurrentAddress_D, Channel13CurrentAddress_D, Channel14CurrentAddress_D, Channel15CurrentAddress_D : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);

	-- Register configuration inputs.
	signal BiasConfigReg_D : tSampleProbBiasConfig;
	signal ChipConfigReg_D : tSampleProbChipConfig;

	-- Register all outputs.
	signal ChipBiasSelectReg_S : std_logic;
	signal ChipBiasClockReg_CB : std_logic;
	signal ChipBiasBitInReg_D  : std_logic;
	signal ChipBiasLatchReg_SB : std_logic;
begin
	sendConfig : process(State_DP, BiasConfigReg_D, BiasSROutput_D, ChipSROutput_D, ChipChanged_S, SentBitsCounterData_D, WaitCyclesCounterData_D, BiasChanged_S, Channel0_D, Channel10_D, Channel11_D, Channel12_D, Channel13_D, Channel14_D, Channel15_D, Channel1_D, Channel2_D, Channel3_D, Channel4_D, Channel5_D, Channel6_D, Channel7_D, Channel8_D, Channel9_D, Timestep_S)
	begin
		-- Keep state by default.
		State_DN <= State_DP;

		-- Default state for bias config outputs.
		ChipBiasSelectReg_S <= '1';     -- Select INPUT data by default.
		ChipBiasClockReg_CB <= '1';
		ChipBiasBitInReg_D  <= '0';
		ChipBiasLatchReg_SB <= '1';

		BiasSent_S <= '0';
		ChipSent_S <= '0';

		BiasSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		BiasSRInput_D <= (others => '0');

		ChipSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		ChipSRInput_D <= (others => '0');

		WaitCyclesCounterClear_S  <= '0';
		WaitCyclesCounterEnable_S <= '0';

		SentBitsCounterClear_S  <= '0';
		SentBitsCounterEnable_S <= '0';

		-- Bias state machine is in use by default in all its states, but not when Idle.
		BiasSMInUse_SO <= '1';

		case State_DP is
			when stIdle =>
				-- Not in use when Idle.
				BiasSMInUse_SO <= '0';

				if BiasChanged_S = '1' then
					State_DN <= stAckAndLoadBias;
				end if;

				if ChipChanged_S = '1' and BiasConfigReg_D.UseLandscapeSamplingVerilog_S = '0' then
					State_DN <= stWaitAckAndLoadChip;
				end if;

			when stAckAndLoadBias =>
				-- Acknowledge all bias config changes, since we're getting the up-to-date
				-- content of all of them anyway, so we can just ACk them all.
				BiasSent_S <= '1';

				-- Load shiftreg with current bias config content.
				BiasSRInput_D <= BiasConfigReg_D.Bias22_D & BiasConfigReg_D.Bias21_D & BiasConfigReg_D.Bias20_D & BiasConfigReg_D.Bias19_D & BiasConfigReg_D.Bias18_D & BiasConfigReg_D.Bias17_D & BiasConfigReg_D.Bias16_D & BiasConfigReg_D.Bias15_D & BiasConfigReg_D.Bias14_D & BiasConfigReg_D.Bias13_D &
				 BiasConfigReg_D.Bias12_D & BiasConfigReg_D.Bias11_D & BiasConfigReg_D.Bias10_D & BiasConfigReg_D.Bias9_D & BiasConfigReg_D.Bias8_D & BiasConfigReg_D.Bias7_D & BiasConfigReg_D.Bias6_D & BiasConfigReg_D.Bias5_D & BiasConfigReg_D.Bias4_D & BiasConfigReg_D.Bias3_D & BiasConfigReg_D.Bias2_D &
				 BiasConfigReg_D.Bias1_D & BiasConfigReg_D.Bias0_D & BiasConfigReg_D.SelNS_S & BiasConfigReg_D.SelCH_S & BiasConfigReg_D.SelHazardIV_D & BiasConfigReg_D.SelSpikeExtend_D & BiasConfigReg_D.MasterBias_D;

				BiasSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

				State_DN <= stPrepareSendBias;

			when stPrepareSendBias =>
				-- Set flags as needed for chip bias SR.
				ChipBiasSelectReg_S <= '0';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendBias;
				end if;

			when stSendBias =>
				-- Set flags as needed for chip bias SR.
				ChipBiasSelectReg_S <= '0';

				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= BiasSROutput_D(BIASGEN_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					BiasSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(BIASGEN_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchBias;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchBias =>
				-- Set flags as needed for chip bias SR.
				ChipBiasSelectReg_S <= '0';

				-- Latch new config.
				ChipBiasLatchReg_SB <= '0';

				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelay;
				end if;

			when stWaitAckAndLoadChip =>
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(4, WAIT_CYCLES_COUNTER_SIZE) then
					State_DN <= stAckAndLoadChip;
				end if;

			when stAckAndLoadChip =>
				-- Acknowledge all chip config changes, since we're getting the up-to-date
				-- content of all of them anyway, so we can just ACk them all.
				ChipSent_S <= '1';

				-- Load shiftreg with current chip config content.
				ChipSRInput_D <= Channel0_D & Channel1_D & Channel2_D & Channel3_D & Channel4_D & Channel5_D & Channel6_D & Channel7_D & Channel8_D & Channel9_D & Channel10_D & Channel11_D & Channel12_D & Channel13_D & Channel14_D & Channel15_D;

				ChipSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

				State_DN <= stPrepareSendChip;

			when stPrepareSendChip =>
				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendChip;
				end if;

			when stSendChip =>
				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= ChipSROutput_D(INPUT_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					ChipSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(INPUT_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchChip;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchChip =>
				-- Latch new config.
				ChipBiasLatchReg_SB <= '0';

				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelayChip;
				end if;

			when stDelayChip =>
				-- Default flags are fine here for delay.

				-- Wait until next timestep comes in.
				if Timestep_S = '1' then
					State_DN <= stIdle;
				end if;

			when stDelay =>
				-- Default flags are fine here for delay.

				-- Delay by one cycle to ensure no back-to-back updates can happen.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stIdle;
				end if;

			when others => null;
		end case;
	end process sendConfig;

	regUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			State_DP <= stIdle;

			BiasConfigReg_D <= tSampleProbBiasConfigDefault;
			ChipConfigReg_D <= tSampleProbChipConfigDefault;

			ChipBiasSelect_SO <= '0';
			ChipBiasClock_CBO <= '1';
			ChipBiasBitIn_DO  <= '0';
			ChipBiasLatch_SBO <= '1';
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;

			BiasConfigReg_D <= BiasConfig_DI;
			ChipConfigReg_D <= ChipConfig_DI;

			ChipBiasSelect_SO <= ChipBiasSelectReg_S;
			ChipBiasClock_CBO <= ChipBiasClockReg_CB;
			ChipBiasBitIn_DO  <= ChipBiasBitInReg_D;
			ChipBiasLatch_SBO <= ChipBiasLatchReg_SB;
		end if;
	end process regUpdate;

	waitCyclesCounter : entity work.Counter
		generic map(
			SIZE => WAIT_CYCLES_COUNTER_SIZE)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Clear_SI  => WaitCyclesCounterClear_S,
			Enable_SI => WaitCyclesCounterEnable_S,
			Data_DO   => WaitCyclesCounterData_D);

	sentBitsCounter : entity work.Counter
		generic map(
			SIZE => SENT_BITS_COUNTER_SIZE)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Clear_SI  => SentBitsCounterClear_S,
			Enable_SI => SentBitsCounterEnable_S,
			Data_DO   => SentBitsCounterData_D);

	biasSR : entity work.ShiftRegister
		generic map(
			SIZE => BIASGEN_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => BiasSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => BiasSRInput_D,
			ParallelRead_DO  => BiasSROutput_D);

	chipSR : entity work.ShiftRegister
		generic map(
			SIZE => INPUT_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => ChipSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChipSRInput_D,
			ParallelRead_DO  => ChipSROutput_D);

	-- Put all bias register configuration parameters together, and then detect changes
	-- on the whole lot of them. This is easier to handle and slightly more efficient.
	BiasChangedInput_D <= BiasConfigReg_D.Bias22_D & BiasConfigReg_D.Bias21_D & BiasConfigReg_D.Bias20_D & BiasConfigReg_D.Bias19_D & BiasConfigReg_D.Bias18_D & BiasConfigReg_D.Bias17_D & BiasConfigReg_D.Bias16_D & BiasConfigReg_D.Bias15_D & BiasConfigReg_D.Bias14_D & BiasConfigReg_D.Bias13_D &
	 BiasConfigReg_D.Bias12_D & BiasConfigReg_D.Bias11_D & BiasConfigReg_D.Bias10_D & BiasConfigReg_D.Bias9_D & BiasConfigReg_D.Bias8_D & BiasConfigReg_D.Bias7_D & BiasConfigReg_D.Bias6_D & BiasConfigReg_D.Bias5_D & BiasConfigReg_D.Bias4_D & BiasConfigReg_D.Bias3_D & BiasConfigReg_D.Bias2_D &
	 BiasConfigReg_D.Bias1_D & BiasConfigReg_D.Bias0_D & BiasConfigReg_D.SelNS_S & BiasConfigReg_D.SelCH_S & BiasConfigReg_D.SelHazardIV_D & BiasConfigReg_D.SelSpikeExtend_D & BiasConfigReg_D.MasterBias_D;

	detectBiasChange : entity work.ChangeDetector
		generic map(
			SIZE => BIASGEN_REG_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasChangedInput_D,
			ChangeDetected_SO     => BiasChanged_S,
			ChangeAcknowledged_SI => BiasSent_S);

	-- Put all chip register configuration parameters together, and then detect changes
	-- on the whole lot of them. This is easier to handle and slightly more efficient.
	-- Put all chip register configuration parameters together, and then detect changes
	-- on the whole lot of them. This is easier to handle and slightly more efficient.
	ChipChangedInput_D <= Channel0_D & Channel1_D & Channel2_D & Channel3_D & Channel4_D & Channel5_D & Channel6_D & Channel7_D & Channel8_D & Channel9_D & Channel10_D & Channel11_D & Channel12_D & Channel13_D & Channel14_D & Channel15_D;

	detectChipChange : entity work.ChangeDetector
		generic map(
			SIZE => INPUT_REG_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => ChipChangedInput_D,
			ChangeDetected_SO     => ChipChanged_S,
			ChangeAcknowledged_SI => ChipSent_S);

	-- Detect rising edges on the RNG clock as new timesteps.
	rngTimestepDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => Timestep_SI,
			RisingEdgeDetected_SO  => TimestepRisingEdge_S,
			FallingEdgeDetected_SO => open);

	-- Compensate for the on-chip divider on the RNG clock by only emanating a new time-step
	-- every Nth RNG clock rising edge, instead of on every rising edge.
	rngTimestepDivider : entity work.ContinuousCounter
		generic map(
			SIZE              => 6,
			SHORT_OVERFLOW    => true,
			OVERFLOW_AT_ZERO  => true)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not BiasConfigReg_D.ClockPulseEnable_S or AERReset_SI,
			Enable_SI    => TimestepRisingEdge_S,
			DataLimit_DI => to_unsigned(31, 6),
			Overflow_SO  => Timestep_S,
			Data_DO      => open);

	channel0Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel0Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel0Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel0_D);

	Channel0Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0000") else '0';
	Channel0Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0000") else Channel0CurrentAddress_D;

	channel0CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(0),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel0CurrentAddress_D);

	channel1Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel1Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel1Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel1_D);

	Channel1Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0001") else '0';
	Channel1Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0001") else Channel1CurrentAddress_D;

	channel1CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(1),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel1CurrentAddress_D);

	channel2Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel2Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel2Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel2_D);

	Channel2Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0010") else '0';
	Channel2Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0010") else Channel2CurrentAddress_D;

	channel2CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(2),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel2CurrentAddress_D);

	channel3Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel3Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel3Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel3_D);

	Channel3Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0011") else '0';
	Channel3Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0011") else Channel3CurrentAddress_D;

	channel3CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(3),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel3CurrentAddress_D);

	channel4Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel4Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel4Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel4_D);

	Channel4Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0100") else '0';
	Channel4Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0100") else Channel4CurrentAddress_D;

	channel4CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(4),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel4CurrentAddress_D);

	channel5Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel5Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel5Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel5_D);

	Channel5Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0101") else '0';
	Channel5Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0101") else Channel5CurrentAddress_D;

	channel5CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(5),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel5CurrentAddress_D);

	channel6Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel6Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel6Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel6_D);

	Channel6Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0110") else '0';
	Channel6Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0110") else Channel6CurrentAddress_D;

	channel6CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(6),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel6CurrentAddress_D);

	channel7Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel7Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel7Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel7_D);

	Channel7Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0111") else '0';
	Channel7Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "0111") else Channel7CurrentAddress_D;

	channel7CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(7),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel7CurrentAddress_D);

	channel8Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel8Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel8Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel8_D);

	Channel8Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1000") else '0';
	Channel8Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1000") else Channel8CurrentAddress_D;

	channel8CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(8),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel8CurrentAddress_D);

	channel9Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel9Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel9Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel9_D);

	Channel9Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1001") else '0';
	Channel9Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1001") else Channel9CurrentAddress_D;

	channel9CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(9),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel9CurrentAddress_D);

	channel10Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel10Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel10Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel10_D);

	Channel10Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1010") else '0';
	Channel10Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1010") else Channel10CurrentAddress_D;

	channel10CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(10),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel10CurrentAddress_D);

	channel11Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel11Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel11Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel11_D);

	Channel11Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1011") else '0';
	Channel11Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1011") else Channel11CurrentAddress_D;

	channel11CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(11),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel11CurrentAddress_D);

	channel12Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel12Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel12Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel12_D);

	Channel12Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1100") else '0';
	Channel12Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1100") else Channel12CurrentAddress_D;

	channel12CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(12),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel12CurrentAddress_D);

	channel13Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel13Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel13Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel13_D);

	Channel13Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1101") else '0';
	Channel13Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1101") else Channel13CurrentAddress_D;

	channel13CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(13),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel13CurrentAddress_D);

	channel14Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel14Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel14Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel14_D);

	Channel14Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1110") else '0';
	Channel14Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1110") else Channel14CurrentAddress_D;

	channel14CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(14),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel14CurrentAddress_D);

	channel15Map : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHANNEL_STEPS,
			ADDRESS_WIDTH => CHANNEL_STEPS_SIZE,
			DATA_WIDTH    => CHANNEL_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI or ChipConfigReg_D.ClearAll_S,
			Address_DI     => Channel15Address_D,
			Enable_SI      => '1',
			WriteEnable_SI => Channel15Write_S,
			Data_DI        => ChipConfigReg_D.Data_D,
			Data_DO        => Channel15_D);

	Channel15Write_S   <= '1' when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1111") else '0';
	Channel15Address_D <= ChipConfigReg_D.Address_D when (ChipConfigReg_D.Set_S = '1' and ChipConfigReg_D.Channel_D = "1111") else Channel15CurrentAddress_D;

	channel15CurrentAddressGenerator : entity work.DistributionAddressGenerator
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Timestep_SI         => Timestep_S,
			AddressReset_SI     => DistributionReset_SI(15),
			RefractoryPeriod_DI => BiasConfigReg_D.SelSpikeExtend_D,
			Address_DO          => Channel15CurrentAddress_D);

	-- Debug
	Timestep_SO <= Timestep_S;
end architecture Behavioral;
