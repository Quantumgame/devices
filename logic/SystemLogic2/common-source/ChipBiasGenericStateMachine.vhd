library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.ShiftRegisterModes.all;
use work.Functions.BooleanToStdLogic;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;
use work.ChipBiasConfigRecords.all;

-- This is a minimal, generic bias and chip configuration state machine for
-- highly resource constrained applications. It pretty much just forwards
-- the already formatted biases coming from the host, reacting to any
-- write to its registers. Reading values is not possible.
-- Register 0 contains a bias, 8 bit address, 16 bit value. On write the
-- bias is sent to the device. Before writing the next bias, wait 480us.
-- Register 1 contains the lower 32 bits of the chip configuration chain,
-- while Register 2 contains the upper 24 bits. On write to Register 2,
-- the chip config chain is sent to the chip. Before writing the next
-- chain or bias, wait 690us.
entity ChipBiasGenericStateMachine is
	port(
		Clock_CI               : in  std_logic;
		Reset_RI               : in  std_logic;

		-- Bias configuration outputs (to chip)
		ChipBiasDiagSelect_SO  : out std_logic;
		ChipBiasAddrSelect_SBO : out std_logic;
		ChipBiasClock_CBO      : out std_logic;
		ChipBiasBitIn_DO       : out std_logic;
		ChipBiasLatch_SBO      : out std_logic;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI : in  unsigned(6 downto 0);
		ConfigParamAddress_DI  : in  unsigned(7 downto 0);
		ConfigParamInput_DI    : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI    : in  std_logic);
end entity ChipBiasGenericStateMachine;

architecture Behavioral of ChipBiasGenericStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stPrepareSendBiasAddress, stSendBiasAddress, stLatchBiasAddress, stPrepareSendBias, stSendBias, stLatchBias, stPrepareSendChip, stSendChip, stLatchChip, stEndChip, stDelay);
	attribute syn_enum_encoding of tState : type is "onehot";

	signal State_DP, State_DN : tState;

	-- Bias clock frequency in KHz.
	constant BIAS_CLOCK_FREQ : real := 100.0;

	-- How long the latch should be asserted, based on bias clock frequency.
	constant LATCH_LENGTH : integer := 10;

	-- Calculated values in cycles.
	constant BIAS_CLOCK_CYCLES : integer := integer((LOGIC_CLOCK_FREQ_REAL * 1000.0) / BIAS_CLOCK_FREQ);
	constant LATCH_CYCLES      : integer := BIAS_CLOCK_CYCLES * LATCH_LENGTH;

	-- Calcualted length of cycles counter. Based on latch cycles, since biggest value.
	constant WAIT_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(LATCH_CYCLES))));

	-- Counts number of sent bits. Biggest value is 56 bits of chip SR, so 6 bits are enough.
	constant SENT_BITS_COUNTER_SIZE : integer := 6;

	-- Data shift registers for output.
	signal BiasAddrSRMode_S   : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal BiasAddrSROutput_D : std_logic_vector(BIASADDR_REG_LENGTH - 1 downto 0);

	signal BiasSRMode_S   : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal BiasSROutput_D : std_logic_vector(BIAS_REG_LENGTH - 1 downto 0);

	signal ChipSRMode_S   : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal ChipSROutput_D : std_logic_vector(CHIP_REG_LENGTH_DEFAULT - 1 downto 0);

	-- Counter for keeping track of output bits.
	signal SentBitsCounterClear_S, SentBitsCounterEnable_S : std_logic;
	signal SentBitsCounterData_D                           : unsigned(SENT_BITS_COUNTER_SIZE - 1 downto 0);

	-- Counter to introduce delays between operations, and generate the clock.
	signal WaitCyclesCounterClear_S, WaitCyclesCounterEnable_S : std_logic;
	signal WaitCyclesCounterData_D                             : unsigned(WAIT_CYCLES_COUNTER_SIZE - 1 downto 0);

	-- Register configuration inputs.
	signal LatchConfigReg_S                           : std_logic;
	signal ChipBiasConfigReg_DP, ChipBiasConfigReg_DN : tChipBiasGenericConfig;

	signal ConfigWritten_S  : std_logic;
	signal BiasWritten_S    : std_logic;
	signal ChipBiasConfig_D : tChipBiasGenericConfig;

	-- Register all outputs.
	signal ChipBiasDiagSelectReg_S  : std_logic;
	signal ChipBiasAddrSelectReg_SB : std_logic;
	signal ChipBiasClockReg_CB      : std_logic;
	signal ChipBiasBitInReg_D       : std_logic;
	signal ChipBiasLatchReg_SB      : std_logic;
begin
	biasSM : process(State_DP, BiasAddrSROutput_D, BiasSROutput_D, ChipSROutput_D, SentBitsCounterData_D, WaitCyclesCounterData_D, BiasWritten_S, ConfigWritten_S)
	begin
		-- Keep state by default.
		State_DN <= State_DP;

		-- Default state for bias config outputs.
		ChipBiasDiagSelectReg_S  <= '0';
		ChipBiasAddrSelectReg_SB <= '1';
		ChipBiasClockReg_CB      <= '1';
		ChipBiasBitInReg_D       <= '0';
		ChipBiasLatchReg_SB      <= '1';

		BiasAddrSRMode_S <= SHIFTREGISTER_MODE_DO_NOTHING;
		BiasSRMode_S     <= SHIFTREGISTER_MODE_DO_NOTHING;
		ChipSRMode_S     <= SHIFTREGISTER_MODE_DO_NOTHING;

		WaitCyclesCounterClear_S  <= '0';
		WaitCyclesCounterEnable_S <= '0';

		SentBitsCounterClear_S  <= '0';
		SentBitsCounterEnable_S <= '0';

		case State_DP is
			when stIdle =>
				if ConfigWritten_S = '1' then
					if BiasWritten_S = '1' then
						State_DN <= stPrepareSendBiasAddress;
					else
						State_DN <= stPrepareSendChip;
					end if;
				end if;

			when stPrepareSendBiasAddress =>
				-- Load shiftreg with current bias address.
				BiasAddrSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

				-- Load shiftreg with current bias config content.
				BiasSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

				-- Set flags as needed for bias address SR.
				ChipBiasAddrSelectReg_SB <= '0';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendBiasAddress;
				end if;

			when stSendBiasAddress =>
				-- Set flags as needed for bias address SR.
				ChipBiasAddrSelectReg_SB <= '0';

				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= BiasAddrSROutput_D(BIASADDR_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					BiasAddrSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(BIASADDR_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchBiasAddress;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchBiasAddress =>
				-- Set flags as needed for bias address SR.
				ChipBiasAddrSelectReg_SB <= '0';

				-- Latch new config.
				ChipBiasLatchReg_SB <= '0';

				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stPrepareSendBias;
				end if;

			when stPrepareSendBias =>
				-- Default flags are fine here for bias SR. We just delay.

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendBias;
				end if;

			when stSendBias =>
				-- Default flags are fine here for bias SR.

				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= BiasSROutput_D(BIAS_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					BiasSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(BIAS_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
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
				-- Default flags are fine here for bias SR.

				-- Latch new config.
				ChipBiasLatchReg_SB <= '0';

				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelay;
				end if;

			when stPrepareSendChip =>
				-- Load shiftreg with current chip config chain content.
				ChipSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

				-- Set flags as needed for chip diag SR.
				ChipBiasDiagSelectReg_S <= '1';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendChip;
				end if;

			when stSendChip =>
				-- Set flags as needed for chip diag SR.
				ChipBiasDiagSelectReg_S <= '1';

				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= ChipSROutput_D(CHIP_REG_LENGTH_DEFAULT - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					ChipSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(CHIP_REG_LENGTH_DEFAULT - 1, SENT_BITS_COUNTER_SIZE) then
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
				-- Set flags as needed for chip diag SR.
				ChipBiasDiagSelectReg_S <= '1';

				-- Latch new config.
				ChipBiasLatchReg_SB <= '0';

				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stEndChip;
				end if;

			when stEndChip =>
				-- Set flags as needed for chip diag SR.
				ChipBiasDiagSelectReg_S <= '1';

				-- Wait for one bias clock cycle, to ensure the latch signal is seen going back to OFF.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelay;
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
	end process biasSM;

	LatchConfigReg_S <= '1' when (ConfigModuleAddress_DI = CHIPBIASCONFIG_MODULE_ADDRESS and ConfigLatchInput_SI = '1') else '0';

	configIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, ChipBiasConfigReg_DP)
	begin
		ChipBiasConfigReg_DN <= ChipBiasConfigReg_DP;

		case ConfigParamAddress_DI is
			when CHIPBIAS_GENERIC_CONFIG_PARAM_ADDRESSES.Bias_D =>
				ChipBiasConfigReg_DN.Bias_D <= ConfigParamInput_DI(tChipBiasGenericConfig.Bias_D'range);

			when CHIPBIAS_GENERIC_CONFIG_PARAM_ADDRESSES.ChipLower_D =>
				ChipBiasConfigReg_DN.ChipLower_D <= ConfigParamInput_DI(tChipBiasGenericConfig.ChipLower_D'range);

			when CHIPBIAS_GENERIC_CONFIG_PARAM_ADDRESSES.ChipUpper_D =>
				ChipBiasConfigReg_DN.ChipUpper_D <= ConfigParamInput_DI(tChipBiasGenericConfig.ChipUpper_D'range);

			when others => null;
		end case;
	end process configIO;

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

	biasAddrSR : entity work.ShiftRegister
		generic map(
			SIZE => BIASADDR_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => BiasAddrSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChipBiasConfig_D.Bias_D(BIASADDR_REG_LENGTH + BIAS_REG_LENGTH - 1 downto BIAS_REG_LENGTH),
			ParallelRead_DO  => BiasAddrSROutput_D);

	biasSR : entity work.ShiftRegister
		generic map(
			SIZE => BIAS_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => BiasSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChipBiasConfig_D.Bias_D(BIAS_REG_LENGTH - 1 downto 0),
			ParallelRead_DO  => BiasSROutput_D);

	chipSR : entity work.ShiftRegister
		generic map(
			SIZE => CHIP_REG_LENGTH_DEFAULT)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => ChipSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChipBiasConfig_D.ChipUpper_D & ChipBiasConfig_D.ChipLower_D,
			ParallelRead_DO  => ChipSROutput_D);

	regUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			State_DP <= stIdle;

			ChipBiasConfigReg_DP <= tChipBiasGenericConfigDefault;
			ChipBiasConfig_D     <= tChipBiasGenericConfigDefault;

			ConfigWritten_S <= '0';
			BiasWritten_S   <= '0';

			ChipBiasDiagSelect_SO  <= '0';
			ChipBiasAddrSelect_SBO <= '1';
			ChipBiasClock_CBO      <= '1';
			ChipBiasBitIn_DO       <= '0';
			ChipBiasLatch_SBO      <= '1';
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;

			if LatchConfigReg_S = '1' then
				ChipBiasConfigReg_DP <= ChipBiasConfigReg_DN;
			end if;
			ChipBiasConfig_D <= ChipBiasConfigReg_DP;

			ConfigWritten_S <= LatchConfigReg_S and not BooleanToStdLogic(ConfigParamAddress_DI = CHIPBIAS_GENERIC_CONFIG_PARAM_ADDRESSES.ChipLower_D);
			BiasWritten_S   <= BooleanToStdLogic(ConfigParamAddress_DI = CHIPBIAS_GENERIC_CONFIG_PARAM_ADDRESSES.Bias_D);

			ChipBiasDiagSelect_SO  <= ChipBiasDiagSelectReg_S;
			ChipBiasAddrSelect_SBO <= ChipBiasAddrSelectReg_SB;
			ChipBiasClock_CBO      <= ChipBiasClockReg_CB;
			ChipBiasBitIn_DO       <= ChipBiasBitInReg_D;
			ChipBiasLatch_SBO      <= ChipBiasLatchReg_SB;
		end if;
	end process regUpdate;
end architecture Behavioral;
