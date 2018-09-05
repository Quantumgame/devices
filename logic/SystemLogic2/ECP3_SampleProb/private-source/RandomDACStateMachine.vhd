library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Functions.BooleanToStdLogic;
use work.ShiftRegisterModes.all;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;
use work.EventCodes.all;
use work.FIFORecords.all;
use work.DACConfigRecords.all;

entity RandomDACStateMachine is
	port(
		Clock_CI            : in  std_logic;
		Reset_RI            : in  std_logic;

		-- Fifo output (to Multiplexer)
		OutFifoControl_SI   : in  tFromFifoWriteSide;
		OutFifoControl_SO   : out tToFifoWriteSide;
		OutFifoData_DO      : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		-- DAC control I/O
		DACSelect_SBO       : out std_logic_vector(3 downto 0); -- Support up to 4 DACs.
		DACClock_CO         : out std_logic;
		DACDataOut_DO       : out std_logic;

		-- Tick for starting transaction sequence.
		TransactionClock_SI : in  std_logic;

		-- Configuration input
		DACConfig_DI        : in  tDACConfig);
end entity RandomDACStateMachine;

architecture Behavioral of RandomDACStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stStartTransaction, stWriteData, stStopTransaction, stStartTransactionDelay, stStopTransactionDelay, stSendData1, stSendData2);
	attribute syn_enum_encoding of tState : type is "onehot";

	signal State_DP, State_DN : tState;

	constant DAC_REG_LENGTH : integer := 24;

	-- SPI clock frequency in MHz.
	constant DAC_CLOCK_FREQ : real := 30.0;

	-- Calculated values in cycles.
	constant DAC_CLOCK_CYCLES : integer := integer(LOGIC_CLOCK_FREQ_REAL / DAC_CLOCK_FREQ);

	-- Calcualted length of cycles counter.
	constant WAIT_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(DAC_CLOCK_CYCLES))));

	-- Counts number of sent bits.
	constant SENT_BITS_COUNTER_SIZE : integer := integer(ceil(log2(real(DAC_REG_LENGTH))));

	-- Output data register (to DAC).
	signal DACDataOutSRMode_S                      : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal DACDataOutSRWrite_D, DACDataOutSRRead_D : std_logic_vector(DAC_REG_LENGTH - 1 downto 0);

	-- Counter for keeping track of output bits.
	signal SentBitsCounterClear_S, SentBitsCounterEnable_S : std_logic;
	signal SentBitsCounterData_D                           : unsigned(SENT_BITS_COUNTER_SIZE - 1 downto 0);

	-- Counter to introduce delays between operations, and generate the clock.
	signal WaitCyclesCounterClear_S, WaitCyclesCounterEnable_S : std_logic;
	signal WaitCyclesCounterData_D                             : unsigned(WAIT_CYCLES_COUNTER_SIZE - 1 downto 0);

	-- Register outputs. Keep DACSelectReg accessible internally.
	signal DACSelectReg_SP, DACSelectReg_SN : std_logic_vector(3 downto 0); -- Support up to 4 DACs.
	signal DACClockReg_C, DACDataOutReg_D   : std_logic;

	-- Support sending random data from LSFR to DAC, in response to RNG/32 clock tick.
	type tDACDataArray is array (0 to 15) of unsigned(DAC_DATA_LENGTH - 1 downto 0);

	signal DACData_DP, DACData_DN : tDACDataArray;
	signal DACChannel_D           : unsigned(DAC_CHANNEL_LENGTH - 1 downto 0);

	-- LFSR range is kept very big, so as to avoid predictable repetitions.
	constant LFSR_DATA_LENGTH : integer := 32;

	-- We then extract only part of that data and use it (13 bits, 1 less than DAC).
	constant LFSR_USE_LENGTH : integer := (DAC_DATA_LENGTH - 1);

	signal LFSR00Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR01Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR02Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR03Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR04Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR05Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR06Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR07Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR08Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR09Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR10Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR11Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR12Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR13Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR14Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);
	signal LFSR15Data_D : unsigned(LFSR_DATA_LENGTH - 1 downto 0);

	signal LFSR00DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR01DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR02DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR03DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR04DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR05DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR06DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR07DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR08DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR09DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR10DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR11DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR12DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR13DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR14DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	signal LFSR15DataSub_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);

	signal LFSR00NextValue_S : std_logic;
	signal LFSR01NextValue_S : std_logic;
	signal LFSR02NextValue_S : std_logic;
	signal LFSR03NextValue_S : std_logic;
	signal LFSR04NextValue_S : std_logic;
	signal LFSR05NextValue_S : std_logic;
	signal LFSR06NextValue_S : std_logic;
	signal LFSR07NextValue_S : std_logic;
	signal LFSR08NextValue_S : std_logic;
	signal LFSR09NextValue_S : std_logic;
	signal LFSR10NextValue_S : std_logic;
	signal LFSR11NextValue_S : std_logic;
	signal LFSR12NextValue_S : std_logic;
	signal LFSR13NextValue_S : std_logic;
	signal LFSR14NextValue_S : std_logic;
	signal LFSR15NextValue_S : std_logic;

	type tLFSRNextValueArray is array (0 to 15) of std_logic;
	signal LFSRNextValue_S : tLFSRNextValueArray;

	signal ChannelCounterEnable_S : std_logic;

	signal TransactionClockTickDetected_S : std_logic;
	signal DACStartTransaction_S          : std_logic;

	-- Register outputs to FIFO.
	signal OutFifoWriteReg_S : std_logic;
	signal OutFifoDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	constant EVENT_CODE_MISC_DATA10_PART1 : std_logic_vector(1 downto 0) := "00";
	constant EVENT_CODE_MISC_DATA10_PART2 : std_logic_vector(1 downto 0) := "01";

	-- Register configuration input to improve timing.
	signal DACConfigReg_D : tDACConfig;
begin
	dacLFSR00 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 1)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR00NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(1, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR00Data_D);

	dacLFSR01 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 2)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR01NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(2, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR01Data_D);

	dacLFSR02 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 3)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR02NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(3, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR02Data_D);

	dacLFSR03 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 4)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR03NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(4, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR03Data_D);

	dacLFSR04 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 5)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR04NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(5, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR04Data_D);

	dacLFSR05 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 6)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR05NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(6, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR05Data_D);

	dacLFSR06 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 7)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR06NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(7, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR06Data_D);

	dacLFSR07 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 8)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR07NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(8, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR07Data_D);

	dacLFSR08 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 9)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR08NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(9, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR08Data_D);

	dacLFSR09 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 10)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR09NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(10, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR09Data_D);

	dacLFSR10 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 11)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR10NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(11, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR10Data_D);

	dacLFSR11 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 12)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR11NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(12, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR11Data_D);

	dacLFSR12 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 13)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR12NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(13, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR12Data_D);

	dacLFSR13 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 14)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR13NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(14, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR13Data_D);

	dacLFSR14 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 15)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR14NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(15, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR14Data_D);

	dacLFSR15 : entity work.LFSR
		generic map(
			SIZE         => LFSR_DATA_LENGTH,
			INITIAL_SEED => 16)
		port map(
			Clock_CI                 => Clock_CI,
			Reset_RI                 => Reset_RI,
			NextValue_SI             => LFSR15NextValue_S,
			ReloadSeed_SI            => not DACConfigReg_D.RunRandomDAC_S,
			SeedValue_DI             => std_logic_vector(to_unsigned(16, LFSR_DATA_LENGTH)),
			unsigned(RandomValue_DO) => LFSR15Data_D);

	-- Subtract current LFSR value from VMax for a particular channel. This is the first operation on random data.
	LFSR00DataSub_D <= DACConfigReg_D.RandomDACVMaxChan00_D - resize(LFSR00Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR01DataSub_D <= DACConfigReg_D.RandomDACVMaxChan01_D - resize(LFSR01Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR02DataSub_D <= DACConfigReg_D.RandomDACVMaxChan02_D - resize(LFSR02Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR03DataSub_D <= DACConfigReg_D.RandomDACVMaxChan03_D - resize(LFSR03Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR04DataSub_D <= DACConfigReg_D.RandomDACVMaxChan04_D - resize(LFSR04Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR05DataSub_D <= DACConfigReg_D.RandomDACVMaxChan05_D - resize(LFSR05Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR06DataSub_D <= DACConfigReg_D.RandomDACVMaxChan06_D - resize(LFSR06Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR07DataSub_D <= DACConfigReg_D.RandomDACVMaxChan07_D - resize(LFSR07Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR08DataSub_D <= DACConfigReg_D.RandomDACVMaxChan08_D - resize(LFSR08Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR09DataSub_D <= DACConfigReg_D.RandomDACVMaxChan09_D - resize(LFSR09Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR10DataSub_D <= DACConfigReg_D.RandomDACVMaxChan10_D - resize(LFSR10Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR11DataSub_D <= DACConfigReg_D.RandomDACVMaxChan11_D - resize(LFSR11Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR12DataSub_D <= DACConfigReg_D.RandomDACVMaxChan12_D - resize(LFSR12Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR13DataSub_D <= DACConfigReg_D.RandomDACVMaxChan13_D - resize(LFSR13Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR14DataSub_D <= DACConfigReg_D.RandomDACVMaxChan14_D - resize(LFSR14Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);
	LFSR15DataSub_D <= DACConfigReg_D.RandomDACVMaxChan15_D - resize(LFSR15Data_D(LFSR_USE_LENGTH - 1 downto 0), DAC_DATA_LENGTH);

	DACData_DN(0)  <= DACConfigReg_D.RandomDACVMinChan00_D when (LFSR00DataSub_D < DACConfigReg_D.RandomDACVMinChan00_D) else LFSR00DataSub_D;
	DACData_DN(1)  <= DACConfigReg_D.RandomDACVMinChan01_D when (LFSR01DataSub_D < DACConfigReg_D.RandomDACVMinChan01_D) else LFSR01DataSub_D;
	DACData_DN(2)  <= DACConfigReg_D.RandomDACVMinChan02_D when (LFSR02DataSub_D < DACConfigReg_D.RandomDACVMinChan02_D) else LFSR02DataSub_D;
	DACData_DN(3)  <= DACConfigReg_D.RandomDACVMinChan03_D when (LFSR03DataSub_D < DACConfigReg_D.RandomDACVMinChan03_D) else LFSR03DataSub_D;
	DACData_DN(4)  <= DACConfigReg_D.RandomDACVMinChan04_D when (LFSR04DataSub_D < DACConfigReg_D.RandomDACVMinChan04_D) else LFSR04DataSub_D;
	DACData_DN(5)  <= DACConfigReg_D.RandomDACVMinChan05_D when (LFSR05DataSub_D < DACConfigReg_D.RandomDACVMinChan05_D) else LFSR05DataSub_D;
	DACData_DN(6)  <= DACConfigReg_D.RandomDACVMinChan06_D when (LFSR06DataSub_D < DACConfigReg_D.RandomDACVMinChan06_D) else LFSR06DataSub_D;
	DACData_DN(7)  <= DACConfigReg_D.RandomDACVMinChan07_D when (LFSR07DataSub_D < DACConfigReg_D.RandomDACVMinChan07_D) else LFSR07DataSub_D;
	DACData_DN(8)  <= DACConfigReg_D.RandomDACVMinChan08_D when (LFSR08DataSub_D < DACConfigReg_D.RandomDACVMinChan08_D) else LFSR08DataSub_D;
	DACData_DN(9)  <= DACConfigReg_D.RandomDACVMinChan09_D when (LFSR09DataSub_D < DACConfigReg_D.RandomDACVMinChan09_D) else LFSR09DataSub_D;
	DACData_DN(10) <= DACConfigReg_D.RandomDACVMinChan10_D when (LFSR10DataSub_D < DACConfigReg_D.RandomDACVMinChan10_D) else LFSR10DataSub_D;
	DACData_DN(11) <= DACConfigReg_D.RandomDACVMinChan11_D when (LFSR11DataSub_D < DACConfigReg_D.RandomDACVMinChan11_D) else LFSR11DataSub_D;
	DACData_DN(12) <= DACConfigReg_D.RandomDACVMinChan12_D when (LFSR12DataSub_D < DACConfigReg_D.RandomDACVMinChan12_D) else LFSR12DataSub_D;
	DACData_DN(13) <= DACConfigReg_D.RandomDACVMinChan13_D when (LFSR13DataSub_D < DACConfigReg_D.RandomDACVMinChan13_D) else LFSR13DataSub_D;
	DACData_DN(14) <= DACConfigReg_D.RandomDACVMinChan14_D when (LFSR14DataSub_D < DACConfigReg_D.RandomDACVMinChan14_D) else LFSR14DataSub_D;
	DACData_DN(15) <= DACConfigReg_D.RandomDACVMinChan15_D when (LFSR15DataSub_D < DACConfigReg_D.RandomDACVMinChan15_D) else LFSR15DataSub_D;

	-- Forward LFSR get next value signal to the right LFSR.
	-- All LFSRs get their values latched into DACData_DP when DACStartTransaction_S is asserted,
	-- and then start searching for a new value for the full deltaT that's coming.
	LFSRNextValue_S <= (others => DACStartTransaction_S);

	LFSR00NextValue_S <= LFSRNextValue_S(0) or BooleanToStdLogic(LFSR00DataSub_D < DACConfigReg_D.RandomDACVMinChan00_D);
	LFSR01NextValue_S <= LFSRNextValue_S(1) or BooleanToStdLogic(LFSR01DataSub_D < DACConfigReg_D.RandomDACVMinChan01_D);
	LFSR02NextValue_S <= LFSRNextValue_S(2) or BooleanToStdLogic(LFSR02DataSub_D < DACConfigReg_D.RandomDACVMinChan02_D);
	LFSR03NextValue_S <= LFSRNextValue_S(3) or BooleanToStdLogic(LFSR03DataSub_D < DACConfigReg_D.RandomDACVMinChan03_D);
	LFSR04NextValue_S <= LFSRNextValue_S(4) or BooleanToStdLogic(LFSR04DataSub_D < DACConfigReg_D.RandomDACVMinChan04_D);
	LFSR05NextValue_S <= LFSRNextValue_S(5) or BooleanToStdLogic(LFSR05DataSub_D < DACConfigReg_D.RandomDACVMinChan05_D);
	LFSR06NextValue_S <= LFSRNextValue_S(6) or BooleanToStdLogic(LFSR06DataSub_D < DACConfigReg_D.RandomDACVMinChan06_D);
	LFSR07NextValue_S <= LFSRNextValue_S(7) or BooleanToStdLogic(LFSR07DataSub_D < DACConfigReg_D.RandomDACVMinChan07_D);
	LFSR08NextValue_S <= LFSRNextValue_S(8) or BooleanToStdLogic(LFSR08DataSub_D < DACConfigReg_D.RandomDACVMinChan08_D);
	LFSR09NextValue_S <= LFSRNextValue_S(9) or BooleanToStdLogic(LFSR09DataSub_D < DACConfigReg_D.RandomDACVMinChan09_D);
	LFSR10NextValue_S <= LFSRNextValue_S(10) or BooleanToStdLogic(LFSR10DataSub_D < DACConfigReg_D.RandomDACVMinChan10_D);
	LFSR11NextValue_S <= LFSRNextValue_S(11) or BooleanToStdLogic(LFSR11DataSub_D < DACConfigReg_D.RandomDACVMinChan11_D);
	LFSR12NextValue_S <= LFSRNextValue_S(12) or BooleanToStdLogic(LFSR12DataSub_D < DACConfigReg_D.RandomDACVMinChan12_D);
	LFSR13NextValue_S <= LFSRNextValue_S(13) or BooleanToStdLogic(LFSR13DataSub_D < DACConfigReg_D.RandomDACVMinChan13_D);
	LFSR14NextValue_S <= LFSRNextValue_S(14) or BooleanToStdLogic(LFSR14DataSub_D < DACConfigReg_D.RandomDACVMinChan14_D);
	LFSR15NextValue_S <= LFSRNextValue_S(15) or BooleanToStdLogic(LFSR15DataSub_D < DACConfigReg_D.RandomDACVMinChan15_D);

	dacChannelCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => 4,
			RESET_ON_OVERFLOW => true,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not DACConfigReg_D.RunRandomDAC_S,
			Enable_SI    => ChannelCounterEnable_S,
			DataLimit_DI => (others => '1'),
			Overflow_SO  => open,
			Data_DO      => DACChannel_D);

	dacDetectTransactionClockTick : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => TransactionClock_SI,
			RisingEdgeDetected_SO  => TransactionClockTickDetected_S,
			FallingEdgeDetected_SO => open);

	-- Count up to 32 ticks.			
	dacTransactionClockTickCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => 5,
			RESET_ON_OVERFLOW => true,
			GENERATE_OVERFLOW => true)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not DACConfigReg_D.RunRandomDAC_S,
			Enable_SI    => TransactionClockTickDetected_S,
			DataLimit_DI => (others => '1'),
			Overflow_SO  => DACStartTransaction_S,
			Data_DO      => open);

	dacDataOutShiftRegister : entity work.ShiftRegister
		generic map(
			SIZE => DAC_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => DACDataOutSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => DACDataOutSRWrite_D,
			ParallelRead_DO  => DACDataOutSRRead_D);

	waitCyclesCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => WAIT_CYCLES_COUNTER_SIZE,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => WaitCyclesCounterClear_S,
			Enable_SI    => WaitCyclesCounterEnable_S,
			DataLimit_DI => (others => '1'),
			Overflow_SO  => open,
			Data_DO      => WaitCyclesCounterData_D);

	sentBitsCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => SENT_BITS_COUNTER_SIZE,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => SentBitsCounterClear_S,
			Enable_SI    => SentBitsCounterEnable_S,
			DataLimit_DI => (others => '1'),
			Overflow_SO  => open,
			Data_DO      => SentBitsCounterData_D);

	dacControl : process(State_DP, DACConfigReg_D, DACDataOutSRRead_D, DACSelectReg_SP, SentBitsCounterData_D, WaitCyclesCounterData_D, DACChannel_D, DACData_DP, DACStartTransaction_S, OutFifoControl_SI)
	begin
		-- Keep state by default.
		State_DN <= State_DP;

		DACSelectReg_SN <= DACSelectReg_SP;
		DACClockReg_C   <= '0';
		DACDataOutReg_D <= '0';

		WaitCyclesCounterClear_S  <= '0';
		WaitCyclesCounterEnable_S <= '0';

		SentBitsCounterClear_S  <= '0';
		SentBitsCounterEnable_S <= '0';

		DACDataOutSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		DACDataOutSRWrite_D <= (others => '0');

		ChannelCounterEnable_S <= '0';

		OutFifoDataReg_D  <= (others => '0');
		OutFifoWriteReg_S <= '0';

		case State_DP is
			when stIdle =>
				if DACConfigReg_D.Run_S = '1' and DACConfigReg_D.RunRandomDAC_S = '1' and DACStartTransaction_S = '1' then
					State_DN <= stSendData1;
				end if;

			when stSendData1 =>
				-- Load DAC data registers.
				DACDataOutSRWrite_D(19 downto 16)                   <= std_logic_vector(DACChannel_D);
				DACDataOutSRWrite_D(15 downto 14)                   <= "11"; -- 0x03 = Select input data registers.
				DACDataOutSRWrite_D(13 downto 14 - DAC_DATA_LENGTH) <= std_logic_vector(DACData_DP(to_integer(DACChannel_D)));

				DACDataOutSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

				-- Also send out first part of data via USB.
				-- This is best-effort only due to tight timing requirements.
				if DACConfigReg_D.RunRandomDACUSB_S = '1' then
					if OutFifoControl_SI.AlmostFull_S = '0' then
						OutFifoDataReg_D  <= EVENT_CODE_MISC_DATA10 & EVENT_CODE_MISC_DATA10_PART1 & "00" & std_logic_vector(DACChannel_D) & std_logic_vector(DACData_DP(to_integer(DACChannel_D))(DAC_DATA_LENGTH - 1 downto 10));
						OutFifoWriteReg_S <= '1';
					end if;

					-- Send second part of USB data.
					State_DN <= stSendData2;
				else
					-- Start next transaction.
					State_DN <= stStartTransaction;
				end if;

			when stSendData2 =>
				-- Now send out second part of data via USB.
				-- This is best-effort only due to tight timing requirements.
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataReg_D  <= EVENT_CODE_MISC_DATA10 & EVENT_CODE_MISC_DATA10_PART2 & std_logic_vector(DACData_DP(to_integer(DACChannel_D))(9 downto 0));
					OutFifoWriteReg_S <= '1';
				end if;

				-- Start next transaction.
				State_DN <= stStartTransaction;

			when stStartTransaction =>
				-- Advance channel counter for next time, next channel.
				ChannelCounterEnable_S <= '1';

				-- Select the correct DAC and enable it.
				-- This is always DAC3 here (so, zero-indexed, number 2).
				DACSelectReg_SN(2) <= '1';

				State_DN <= stStartTransactionDelay;

			when stStartTransactionDelay =>
				-- Delay by one cycle to ensure slave select is seen.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(DAC_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stWriteData;
				end if;

			when stWriteData =>
				-- Shift it out, slowly, over the SPI output ports.
				DACDataOutReg_D <= DACDataOutSRRead_D(DAC_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(DAC_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					DACDataOutSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(DAC_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stStopTransaction;
					end if;
				end if;

				-- Clock data. Default clock is LOW, so we pull it HIGH during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(DAC_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(DAC_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					DACClockReg_C <= '1';
				end if;

			when stStopTransaction =>
				DACSelectReg_SN <= (others => '0');

				State_DN <= stStopTransactionDelay;

			when stStopTransactionDelay =>
				-- Delay by one cycle to ensure data has arrived fine.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(DAC_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					if DACChannel_D = "0000" then
						State_DN <= stIdle;
					else
						State_DN <= stSendData1;
					end if;
				end if;

			when others =>
				null;
		end case;
	end process dacControl;

	registerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			State_DP <= stIdle;

			OutFifoControl_SO.Write_S <= '0';
			OutFifoData_DO            <= (others => '0');

			DACData_DP <= (others => (others => '0'));

			DACSelectReg_SP <= (others => '0');

			DACClock_CO   <= '0';
			DACDataOut_DO <= '0';

			DACConfigReg_D <= tDACConfigDefault;
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;

			OutFifoControl_SO.Write_S <= OutFifoWriteReg_S;
			OutFifoData_DO            <= OutFifoDataReg_D;

			-- Update LFSR values on each transaction start.
			if DACStartTransaction_S = '1' then
				DACData_DP <= DACData_DN;
			end if;

			DACSelectReg_SP <= DACSelectReg_SN;

			DACClock_CO   <= DACClockReg_C;
			DACDataOut_DO <= DACDataOutReg_D;

			DACConfigReg_D <= DACConfig_DI;
		end if;
	end process registerUpdate;

	DACSelect_SBO <= not DACSelectReg_SP;
end architecture Behavioral;
