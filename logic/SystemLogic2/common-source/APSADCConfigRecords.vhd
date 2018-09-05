library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Functions.SelectInteger;
use work.Settings.CHIP_APS_SIZE_COLUMNS;
use work.Settings.CHIP_APS_SIZE_ROWS;
use work.Settings.CHIP_APS_STREAM_START;
use work.Settings.CHIP_APS_AXES_INVERT;
use work.Settings.CHIP_APS_HAS_GLOBAL_SHUTTER;
use work.Settings.CHIP_APS_HAS_INTEGRATED_ADC;
use work.Settings.ADC_CLOCK_FREQ;
use work.Settings.ADC_CLOCK_FREQ_REAL;

package APSADCConfigRecords is
	constant APSADCCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(2, 7);

	type tAPSADCConfigParamAddresses is record
		SizeColumns_D         : unsigned(7 downto 0);
		SizeRows_D            : unsigned(7 downto 0);
		OrientationInfo_D     : unsigned(7 downto 0);
		ColorFilter_D         : unsigned(7 downto 0);
		Run_S                 : unsigned(7 downto 0);
		ResetRead_S           : unsigned(7 downto 0);
		WaitOnTransferStall_S : unsigned(7 downto 0);
		HasGlobalShutter_S    : unsigned(7 downto 0);
		GlobalShutter_S       : unsigned(7 downto 0);
		StartColumn0_D        : unsigned(7 downto 0);
		StartRow0_D           : unsigned(7 downto 0);
		EndColumn0_D          : unsigned(7 downto 0);
		EndRow0_D             : unsigned(7 downto 0);
		Exposure_D            : unsigned(7 downto 0);
		FrameDelay_D          : unsigned(7 downto 0);
		ResetSettle_D         : unsigned(7 downto 0);
		ColumnSettle_D        : unsigned(7 downto 0);
		RowSettle_D           : unsigned(7 downto 0);
		NullSettle_D          : unsigned(7 downto 0);
		HasQuadROI_S          : unsigned(7 downto 0);
		StartColumn1_D        : unsigned(7 downto 0);
		StartRow1_D           : unsigned(7 downto 0);
		EndColumn1_D          : unsigned(7 downto 0);
		EndRow1_D             : unsigned(7 downto 0);
		StartColumn2_D        : unsigned(7 downto 0);
		StartRow2_D           : unsigned(7 downto 0);
		EndColumn2_D          : unsigned(7 downto 0);
		EndRow2_D             : unsigned(7 downto 0);
		StartColumn3_D        : unsigned(7 downto 0);
		StartRow3_D           : unsigned(7 downto 0);
		EndColumn3_D          : unsigned(7 downto 0);
		EndRow3_D             : unsigned(7 downto 0);
		HasInternalADC_S      : unsigned(7 downto 0);
		SampleEnable_S        : unsigned(7 downto 0);
		SampleSettle_D        : unsigned(7 downto 0);
		RampReset_D           : unsigned(7 downto 0);
		RampShortReset_S      : unsigned(7 downto 0);
		ADCTestMode_S         : unsigned(7 downto 0);
		ROI0Enabled_S         : unsigned(7 downto 0);
		ROI1Enabled_S         : unsigned(7 downto 0);
		ROI2Enabled_S         : unsigned(7 downto 0);
		ROI3Enabled_S         : unsigned(7 downto 0);
	end record tAPSADCConfigParamAddresses;

	constant APSADCCONFIG_PARAM_ADDRESSES : tAPSADCConfigParamAddresses := (
		SizeColumns_D         => to_unsigned(0, 8),
		SizeRows_D            => to_unsigned(1, 8),
		OrientationInfo_D     => to_unsigned(2, 8),
		ColorFilter_D         => to_unsigned(3, 8),
		Run_S                 => to_unsigned(4, 8),
		ResetRead_S           => to_unsigned(5, 8),
		WaitOnTransferStall_S => to_unsigned(6, 8),
		HasGlobalShutter_S    => to_unsigned(7, 8),
		GlobalShutter_S       => to_unsigned(8, 8),
		StartColumn0_D        => to_unsigned(9, 8),
		StartRow0_D           => to_unsigned(10, 8),
		EndColumn0_D          => to_unsigned(11, 8),
		EndRow0_D             => to_unsigned(12, 8),
		Exposure_D            => to_unsigned(13, 8),
		FrameDelay_D          => to_unsigned(14, 8),
		ResetSettle_D         => to_unsigned(15, 8),
		ColumnSettle_D        => to_unsigned(16, 8),
		RowSettle_D           => to_unsigned(17, 8),
		NullSettle_D          => to_unsigned(18, 8),
		HasQuadROI_S          => to_unsigned(19, 8),
		StartColumn1_D        => to_unsigned(20, 8),
		StartRow1_D           => to_unsigned(21, 8),
		EndColumn1_D          => to_unsigned(22, 8),
		EndRow1_D             => to_unsigned(23, 8),
		StartColumn2_D        => to_unsigned(24, 8),
		StartRow2_D           => to_unsigned(25, 8),
		EndColumn2_D          => to_unsigned(26, 8),
		EndRow2_D             => to_unsigned(27, 8),
		StartColumn3_D        => to_unsigned(28, 8),
		StartRow3_D           => to_unsigned(29, 8),
		EndColumn3_D          => to_unsigned(30, 8),
		EndRow3_D             => to_unsigned(31, 8),
		HasInternalADC_S      => to_unsigned(33, 8),
		SampleEnable_S        => to_unsigned(35, 8),
		SampleSettle_D        => to_unsigned(36, 8),
		RampReset_D           => to_unsigned(37, 8),
		RampShortReset_S      => to_unsigned(38, 8),
		ADCTestMode_S         => to_unsigned(39, 8),
		ROI0Enabled_S         => to_unsigned(40, 8),
		ROI1Enabled_S         => to_unsigned(41, 8),
		ROI2Enabled_S         => to_unsigned(42, 8),
		ROI3Enabled_S         => to_unsigned(43, 8));

	constant APS_CLOCK_FREQ_SIZE : integer := integer(ceil(log2(real(ADC_CLOCK_FREQ_REAL + 1.0))));

	constant APS_EXPOSURE_SIZE      : integer := 20 + APS_CLOCK_FREQ_SIZE; -- Up to about one second.
	constant APS_FRAMEDELAY_SIZE    : integer := 20 + APS_CLOCK_FREQ_SIZE; -- Up to about one second.
	constant APS_RESETTIME_SIZE     : integer := 1 + APS_CLOCK_FREQ_SIZE; -- Up to about two microseconds.
	constant APS_COLSETTLETIME_SIZE : integer := 1 + APS_CLOCK_FREQ_SIZE; -- Up to about two microseconds.
	constant APS_ROWSETTLETIME_SIZE : integer := 1 + APS_CLOCK_FREQ_SIZE; -- Up to about two microseconds.
	constant APS_NULLTIME_SIZE      : integer := 0 + APS_CLOCK_FREQ_SIZE; -- Up to about one microsecond.

	-- On-chip ADC specific timings.
	constant APS_SAMPLESETTLETIME_SIZE : integer := 3 + APS_CLOCK_FREQ_SIZE; -- Up to about eight microseconds.
	constant APS_RAMPRESETTIME_SIZE    : integer := 2 + APS_CLOCK_FREQ_SIZE; -- Up to about four microseconds.

	-- Col/Row size as seen by user input depends on AXES_INVERT.
	constant APS_USER_LENGTH_COLUMNS : integer := SelectInteger(CHIP_APS_AXES_INVERT = '0', CHIP_APS_SIZE_COLUMNS'length, CHIP_APS_SIZE_ROWS'length);
	constant APS_USER_LENGTH_ROWS    : integer := SelectInteger(CHIP_APS_AXES_INVERT = '0', CHIP_APS_SIZE_ROWS'length, CHIP_APS_SIZE_COLUMNS'length);
	constant APS_USER_VALUE_COLUMNS  : integer := SelectInteger(CHIP_APS_AXES_INVERT = '0', to_integer(CHIP_APS_SIZE_COLUMNS), to_integer(CHIP_APS_SIZE_ROWS));
	constant APS_USER_VALUE_ROWS     : integer := SelectInteger(CHIP_APS_AXES_INVERT = '0', to_integer(CHIP_APS_SIZE_ROWS), to_integer(CHIP_APS_SIZE_COLUMNS));

	type tAPSADCConfig is record
		SizeColumns_D         : unsigned(CHIP_APS_SIZE_COLUMNS'range);
		SizeRows_D            : unsigned(CHIP_APS_SIZE_ROWS'range);
		OrientationInfo_D     : std_logic_vector(2 downto 0);
		ColorFilter_D         : std_logic_vector(3 downto 0);
		Run_S                 : std_logic;
		ResetRead_S           : std_logic; -- Wether to do the reset read or not.
		WaitOnTransferStall_S : std_logic; -- Wether to wait when the FIFO is full or not.
		HasGlobalShutter_S    : std_logic;
		GlobalShutter_S       : std_logic; -- Enable global shutter instead of rolling shutter.
		StartColumn0_D        : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		StartRow0_D           : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		EndColumn0_D          : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		EndRow0_D             : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		Exposure_D            : unsigned(APS_EXPOSURE_SIZE - 1 downto 0); -- in cycles at ADC frequency
		FrameDelay_D          : unsigned(APS_FRAMEDELAY_SIZE - 1 downto 0); -- in cycles at ADC frequency
		ResetSettle_D         : unsigned(APS_RESETTIME_SIZE - 1 downto 0); -- in cycles at ADC frequency
		ColumnSettle_D        : unsigned(APS_COLSETTLETIME_SIZE - 1 downto 0); -- in cycles at ADC frequency
		RowSettle_D           : unsigned(APS_ROWSETTLETIME_SIZE - 1 downto 0); -- in cycles at ADC frequency
		NullSettle_D          : unsigned(APS_NULLTIME_SIZE - 1 downto 0); -- in cycles at ADC frequency
		HasQuadROI_S          : std_logic;
		StartColumn1_D        : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		StartRow1_D           : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		EndColumn1_D          : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		EndRow1_D             : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		StartColumn2_D        : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		StartRow2_D           : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		EndColumn2_D          : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		EndRow2_D             : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		StartColumn3_D        : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		StartRow3_D           : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		EndColumn3_D          : unsigned(APS_USER_LENGTH_COLUMNS - 1 downto 0);
		EndRow3_D             : unsigned(APS_USER_LENGTH_ROWS - 1 downto 0);
		HasInternalADC_S      : std_logic;
		SampleEnable_S        : std_logic;
		SampleSettle_D        : unsigned(APS_SAMPLESETTLETIME_SIZE - 1 downto 0); -- in cycles at ADC frequency
		RampReset_D           : unsigned(APS_RAMPRESETTIME_SIZE - 1 downto 0); -- in cycles at ADC frequency
		RampShortReset_S      : std_logic;
		ADCTestMode_S         : std_logic;
		ROI0Enabled_S         : std_logic;
		ROI1Enabled_S         : std_logic;
		ROI2Enabled_S         : std_logic;
		ROI3Enabled_S         : std_logic;
	end record tAPSADCConfig;

	constant tAPSADCConfigDefault : tAPSADCConfig := (
		SizeColumns_D         => CHIP_APS_SIZE_COLUMNS,
		SizeRows_D            => CHIP_APS_SIZE_ROWS,
		OrientationInfo_D     => CHIP_APS_AXES_INVERT & CHIP_APS_STREAM_START,
		ColorFilter_D         => "0000",
		Run_S                 => '0',
		ResetRead_S           => '1',
		WaitOnTransferStall_S => '1',
		HasGlobalShutter_S    => CHIP_APS_HAS_GLOBAL_SHUTTER,
		GlobalShutter_S       => CHIP_APS_HAS_GLOBAL_SHUTTER,
		StartColumn0_D        => to_unsigned(0, APS_USER_LENGTH_COLUMNS),
		StartRow0_D           => to_unsigned(0, APS_USER_LENGTH_ROWS),
		EndColumn0_D          => to_unsigned(APS_USER_VALUE_COLUMNS - 1, APS_USER_LENGTH_COLUMNS),
		EndRow0_D             => to_unsigned(APS_USER_VALUE_ROWS - 1, APS_USER_LENGTH_ROWS),
		Exposure_D            => to_unsigned(integer(4000.0 * ADC_CLOCK_FREQ_REAL), APS_EXPOSURE_SIZE),
		FrameDelay_D          => to_unsigned(integer(1000.0 * ADC_CLOCK_FREQ_REAL), APS_FRAMEDELAY_SIZE),
		ResetSettle_D         => to_unsigned(ADC_CLOCK_FREQ / 3, APS_RESETTIME_SIZE),
		ColumnSettle_D        => to_unsigned(ADC_CLOCK_FREQ, APS_COLSETTLETIME_SIZE),
		RowSettle_D           => to_unsigned(ADC_CLOCK_FREQ / 3, APS_ROWSETTLETIME_SIZE),
		NullSettle_D          => to_unsigned(ADC_CLOCK_FREQ / 10, APS_NULLTIME_SIZE),
		HasQuadROI_S          => '0',
		StartColumn1_D        => to_unsigned(0, APS_USER_LENGTH_COLUMNS),
		StartRow1_D           => to_unsigned(0, APS_USER_LENGTH_ROWS),
		EndColumn1_D          => to_unsigned(APS_USER_VALUE_COLUMNS - 1, APS_USER_LENGTH_COLUMNS),
		EndRow1_D             => to_unsigned(APS_USER_VALUE_ROWS - 1, APS_USER_LENGTH_ROWS),
		StartColumn2_D        => to_unsigned(0, APS_USER_LENGTH_COLUMNS),
		StartRow2_D           => to_unsigned(0, APS_USER_LENGTH_ROWS),
		EndColumn2_D          => to_unsigned(APS_USER_VALUE_COLUMNS - 1, APS_USER_LENGTH_COLUMNS),
		EndRow2_D             => to_unsigned(APS_USER_VALUE_ROWS - 1, APS_USER_LENGTH_ROWS),
		StartColumn3_D        => to_unsigned(0, APS_USER_LENGTH_COLUMNS),
		StartRow3_D           => to_unsigned(0, APS_USER_LENGTH_ROWS),
		EndColumn3_D          => to_unsigned(APS_USER_VALUE_COLUMNS - 1, APS_USER_LENGTH_COLUMNS),
		EndRow3_D             => to_unsigned(APS_USER_VALUE_ROWS - 1, APS_USER_LENGTH_ROWS),
		HasInternalADC_S      => CHIP_APS_HAS_INTEGRATED_ADC,
		SampleEnable_S        => '1',
		SampleSettle_D        => to_unsigned(ADC_CLOCK_FREQ, APS_SAMPLESETTLETIME_SIZE),
		RampReset_D           => to_unsigned(ADC_CLOCK_FREQ / 3, APS_RAMPRESETTIME_SIZE),
		RampShortReset_S      => '0',
		ADCTestMode_S         => '0',
		ROI0Enabled_S         => '1',
		ROI1Enabled_S         => '0',
		ROI2Enabled_S         => '0',
		ROI3Enabled_S         => '0');
end package APSADCConfigRecords;
