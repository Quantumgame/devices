library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Settings.LOGIC_CLOCK_FREQ;

package SampleProbChipBiasConfigRecords is
	type tSampleProbBiasConfigParamAddresses is record
		MasterBias_D                  : unsigned(7 downto 0);
		SelSpikeExtend_D              : unsigned(7 downto 0);
		SelHazardIV_D                 : unsigned(7 downto 0);
		SelCH_S                       : unsigned(7 downto 0);
		SelNS_S                       : unsigned(7 downto 0);
		Bias0_D                       : unsigned(7 downto 0);
		Bias1_D                       : unsigned(7 downto 0);
		Bias2_D                       : unsigned(7 downto 0);
		Bias3_D                       : unsigned(7 downto 0);
		Bias4_D                       : unsigned(7 downto 0);
		Bias5_D                       : unsigned(7 downto 0);
		Bias6_D                       : unsigned(7 downto 0);
		Bias7_D                       : unsigned(7 downto 0);
		Bias8_D                       : unsigned(7 downto 0);
		Bias9_D                       : unsigned(7 downto 0);
		Bias10_D                      : unsigned(7 downto 0);
		Bias11_D                      : unsigned(7 downto 0);
		Bias12_D                      : unsigned(7 downto 0);
		Bias13_D                      : unsigned(7 downto 0);
		Bias14_D                      : unsigned(7 downto 0);
		Bias15_D                      : unsigned(7 downto 0);
		Bias16_D                      : unsigned(7 downto 0);
		Bias17_D                      : unsigned(7 downto 0);
		Bias18_D                      : unsigned(7 downto 0);
		Bias19_D                      : unsigned(7 downto 0);
		Bias20_D                      : unsigned(7 downto 0);
		Bias21_D                      : unsigned(7 downto 0);
		Bias22_D                      : unsigned(7 downto 0);
		ClockPulseEnable_S            : unsigned(7 downto 0);
		ClockPulsePeriod_D            : unsigned(7 downto 0);
		UseLandscapeSamplingVerilog_S : unsigned(7 downto 0);
	end record tSampleProbBiasConfigParamAddresses;

	constant SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES : tSampleProbBiasConfigParamAddresses := (
		MasterBias_D                  => to_unsigned(0, 8),
		SelSpikeExtend_D              => to_unsigned(1, 8),
		SelHazardIV_D                 => to_unsigned(2, 8),
		SelCH_S                       => to_unsigned(3, 8),
		SelNS_S                       => to_unsigned(4, 8),
		Bias0_D                       => to_unsigned(5, 8),
		Bias1_D                       => to_unsigned(6, 8),
		Bias2_D                       => to_unsigned(7, 8),
		Bias3_D                       => to_unsigned(8, 8),
		Bias4_D                       => to_unsigned(9, 8),
		Bias5_D                       => to_unsigned(10, 8),
		Bias6_D                       => to_unsigned(11, 8),
		Bias7_D                       => to_unsigned(12, 8),
		Bias8_D                       => to_unsigned(13, 8),
		Bias9_D                       => to_unsigned(14, 8),
		Bias10_D                      => to_unsigned(15, 8),
		Bias11_D                      => to_unsigned(16, 8),
		Bias12_D                      => to_unsigned(17, 8),
		Bias13_D                      => to_unsigned(18, 8),
		Bias14_D                      => to_unsigned(19, 8),
		Bias15_D                      => to_unsigned(20, 8),
		Bias16_D                      => to_unsigned(21, 8),
		Bias17_D                      => to_unsigned(22, 8),
		Bias18_D                      => to_unsigned(23, 8),
		Bias19_D                      => to_unsigned(24, 8),
		Bias20_D                      => to_unsigned(25, 8),
		Bias21_D                      => to_unsigned(26, 8),
		Bias22_D                      => to_unsigned(27, 8),
		ClockPulseEnable_S            => to_unsigned(40, 8),
		ClockPulsePeriod_D            => to_unsigned(41, 8),
		UseLandscapeSamplingVerilog_S => to_unsigned(42, 8));

	constant MASTERBIAS_LENGTH : integer := 8;
	constant SPIKEEXT_LENGTH   : integer := 3;
	constant HAZARD_LENGTH     : integer := 8;
	constant BIAS_LENGTH       : integer := 24;
	constant BIAS_NUMBER       : integer := 23;

	-- Total length of actual register to send out.
	constant BIASGEN_REG_LENGTH : integer := MASTERBIAS_LENGTH + SPIKEEXT_LENGTH + HAZARD_LENGTH + 2 + (BIAS_LENGTH * BIAS_NUMBER);

	-- We also put the RNG clock enable/period signals here for convenience.
	constant CLOCK_PERIOD_LENGTH : integer := 20;

	type tSampleProbBiasConfig is record
		MasterBias_D                  : std_logic_vector(MASTERBIAS_LENGTH - 1 downto 0);
		SelSpikeExtend_D              : std_logic_vector(SPIKEEXT_LENGTH - 1 downto 0);
		SelHazardIV_D                 : std_logic_vector(HAZARD_LENGTH - 1 downto 0);
		SelCH_S                       : std_logic;
		SelNS_S                       : std_logic;
		Bias0_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias1_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias2_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias3_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias4_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias5_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias6_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias7_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias8_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias9_D                       : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias10_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias11_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias12_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias13_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias14_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias15_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias16_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias17_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias18_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias19_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias20_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias21_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		Bias22_D                      : std_logic_vector(BIAS_LENGTH - 1 downto 0);
		ClockPulseEnable_S            : std_logic;
		ClockPulsePeriod_D            : unsigned(CLOCK_PERIOD_LENGTH - 1 downto 0);
		UseLandscapeSamplingVerilog_S : std_logic;
	end record tSampleProbBiasConfig;

	constant tSampleProbBiasConfigDefault : tSampleProbBiasConfig := (
		MasterBias_D                  => (others => '0'),
		SelSpikeExtend_D              => (others => '0'),
		SelHazardIV_D                 => (others => '0'),
		SelCH_S                       => '0',
		SelNS_S                       => '0',
		Bias0_D                       => (others => '0'),
		Bias1_D                       => (others => '0'),
		Bias2_D                       => (others => '0'),
		Bias3_D                       => (others => '0'),
		Bias4_D                       => (others => '0'),
		Bias5_D                       => (others => '0'),
		Bias6_D                       => (others => '0'),
		Bias7_D                       => (others => '0'),
		Bias8_D                       => (others => '0'),
		Bias9_D                       => (others => '0'),
		Bias10_D                      => (others => '0'),
		Bias11_D                      => (others => '0'),
		Bias12_D                      => (others => '0'),
		Bias13_D                      => (others => '0'),
		Bias14_D                      => (others => '0'),
		Bias15_D                      => (others => '0'),
		Bias16_D                      => (others => '0'),
		Bias17_D                      => (others => '0'),
		Bias18_D                      => (others => '0'),
		Bias19_D                      => (others => '0'),
		Bias20_D                      => (others => '0'),
		Bias21_D                      => (others => '0'),
		Bias22_D                      => (others => '0'),
		ClockPulseEnable_S            => '1',
		ClockPulsePeriod_D            => to_unsigned(2 * LOGIC_CLOCK_FREQ, CLOCK_PERIOD_LENGTH),
		UseLandscapeSamplingVerilog_S => '0');

	type tSampleProbChipConfigParamAddresses is record
		Channel_D  : unsigned(7 downto 0);
		Address_D  : unsigned(7 downto 0);
		Data_D     : unsigned(7 downto 0);
		Set_S      : unsigned(7 downto 0);
		ClearAll_S : unsigned(7 downto 0);
	end record tSampleProbChipConfigParamAddresses;

	-- Start with addresses 128 here, so that the MSB (bit 7) is always high. This heavily simplifies
	-- the SPI configuration module, and clearly separates biases from chip diagnostic.
	constant SAMPLEPROB_CHIPCONFIG_PARAM_ADDRESSES : tSampleProbChipConfigParamAddresses := (
		Channel_D  => to_unsigned(128, 8),
		Address_D  => to_unsigned(129, 8),
		Data_D     => to_unsigned(130, 8),
		Set_S      => to_unsigned(131, 8),
		ClearAll_S => to_unsigned(132, 8));

	constant CHANNEL_LENGTH      : integer := 6;
	constant CHANNEL_NUMBER      : integer := 16;
	constant CHANNEL_NUMBER_SIZE : integer := 4;
	constant CHANNEL_STEPS       : integer := 1024;
	constant CHANNEL_STEPS_SIZE  : integer := 10;

	-- Total length of actual register to send out.
	constant INPUT_REG_LENGTH : integer := CHANNEL_LENGTH * CHANNEL_NUMBER;

	type tSampleProbChipConfig is record
		Channel_D  : std_logic_vector(CHANNEL_NUMBER_SIZE - 1 downto 0);
		Address_D  : unsigned(CHANNEL_STEPS_SIZE - 1 downto 0);
		Data_D     : std_logic_vector(CHANNEL_LENGTH - 1 downto 0);
		Set_S      : std_logic;
		ClearAll_S : std_logic;
	end record tSampleProbChipConfig;

	constant tSampleProbChipConfigDefault : tSampleProbChipConfig := (
		Channel_D  => (others => '0'),
		Address_D  => (others => '0'),
		Data_D     => (others => '0'),
		Set_S      => '0',
		ClearAll_S => '0');
end package SampleProbChipBiasConfigRecords;
