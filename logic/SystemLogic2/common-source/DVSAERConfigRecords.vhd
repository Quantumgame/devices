library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Functions.SelectInteger;
use work.Settings.CHIP_DVS_SIZE_COLUMNS;
use work.Settings.CHIP_DVS_SIZE_ROWS;
use work.Settings.CHIP_DVS_ORIGIN_POINT;
use work.Settings.CHIP_DVS_AXES_INVERT;

package DVSAERConfigRecords is
	constant DVSAERCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(1, 7);

	type tDVSAERConfigParamAddresses is record
		SizeColumns_D                            : unsigned(7 downto 0);
		SizeRows_D                               : unsigned(7 downto 0);
		OrientationInfo_D                        : unsigned(7 downto 0);
		Run_S                                    : unsigned(7 downto 0);
		AckDelayRow_D                            : unsigned(7 downto 0);
		AckDelayColumn_D                         : unsigned(7 downto 0);
		AckExtensionRow_D                        : unsigned(7 downto 0);
		AckExtensionColumn_D                     : unsigned(7 downto 0);
		WaitOnTransferStall_S                    : unsigned(7 downto 0);
		FilterRowOnlyEvents_S                    : unsigned(7 downto 0);
		ExternalAERControl_S                     : unsigned(7 downto 0);
		HasPixelFilter_S                         : unsigned(7 downto 0);
		FilterPixel0Row_D                        : unsigned(7 downto 0);
		FilterPixel0Column_D                     : unsigned(7 downto 0);
		FilterPixel1Row_D                        : unsigned(7 downto 0);
		FilterPixel1Column_D                     : unsigned(7 downto 0);
		FilterPixel2Row_D                        : unsigned(7 downto 0);
		FilterPixel2Column_D                     : unsigned(7 downto 0);
		FilterPixel3Row_D                        : unsigned(7 downto 0);
		FilterPixel3Column_D                     : unsigned(7 downto 0);
		FilterPixel4Row_D                        : unsigned(7 downto 0);
		FilterPixel4Column_D                     : unsigned(7 downto 0);
		FilterPixel5Row_D                        : unsigned(7 downto 0);
		FilterPixel5Column_D                     : unsigned(7 downto 0);
		FilterPixel6Row_D                        : unsigned(7 downto 0);
		FilterPixel6Column_D                     : unsigned(7 downto 0);
		FilterPixel7Row_D                        : unsigned(7 downto 0);
		FilterPixel7Column_D                     : unsigned(7 downto 0);
		HasBackgroundActivityFilter_S            : unsigned(7 downto 0);
		FilterBackgroundActivity_S               : unsigned(7 downto 0);
		FilterBackgroundActivityTime_D           : unsigned(7 downto 0);
		HasTestEventGenerator_S                  : unsigned(7 downto 0);
		TestEventGeneratorEnable_S               : unsigned(7 downto 0);
		FilterRefractoryPeriod_S                 : unsigned(7 downto 0);
		FilterRefractoryPeriodTime_D             : unsigned(7 downto 0);
		HasROIFilter_S                           : unsigned(7 downto 0);
		FilterROIStartColumn_D                   : unsigned(7 downto 0);
		FilterROIStartRow_D                      : unsigned(7 downto 0);
		FilterROIEndColumn_D                     : unsigned(7 downto 0);
		FilterROIEndRow_D                        : unsigned(7 downto 0);
		HasStatistics_S                          : unsigned(7 downto 0);
		StatisticsEventsRow64_D                  : unsigned(7 downto 0);
		StatisticsEventsRow32_D                  : unsigned(7 downto 0);
		StatisticsEventsColumn64_D               : unsigned(7 downto 0);
		StatisticsEventsColumn32_D               : unsigned(7 downto 0);
		StatisticsEventsDropped64_D              : unsigned(7 downto 0);
		StatisticsEventsDropped32_D              : unsigned(7 downto 0);
		StatisticsFilteredPixels64_D             : unsigned(7 downto 0);
		StatisticsFilteredPixels32_D             : unsigned(7 downto 0);
		StatisticsFilteredBackgroundActivity64_D : unsigned(7 downto 0);
		StatisticsFilteredBackgroundActivity32_D : unsigned(7 downto 0);
		StatisticsFilteredRefractoryPeriod64_D   : unsigned(7 downto 0);
		StatisticsFilteredRefractoryPeriod32_D   : unsigned(7 downto 0);
	end record tDVSAERConfigParamAddresses;

	constant DVSAERCONFIG_PARAM_ADDRESSES : tDVSAERConfigParamAddresses := (
		SizeColumns_D                            => to_unsigned(0, 8),
		SizeRows_D                               => to_unsigned(1, 8),
		OrientationInfo_D                        => to_unsigned(2, 8),
		Run_S                                    => to_unsigned(3, 8),
		AckDelayRow_D                            => to_unsigned(4, 8),
		AckDelayColumn_D                         => to_unsigned(5, 8),
		AckExtensionRow_D                        => to_unsigned(6, 8),
		AckExtensionColumn_D                     => to_unsigned(7, 8),
		WaitOnTransferStall_S                    => to_unsigned(8, 8),
		FilterRowOnlyEvents_S                    => to_unsigned(9, 8),
		ExternalAERControl_S                     => to_unsigned(10, 8),
		HasPixelFilter_S                         => to_unsigned(11, 8),
		FilterPixel0Row_D                        => to_unsigned(12, 8),
		FilterPixel0Column_D                     => to_unsigned(13, 8),
		FilterPixel1Row_D                        => to_unsigned(14, 8),
		FilterPixel1Column_D                     => to_unsigned(15, 8),
		FilterPixel2Row_D                        => to_unsigned(16, 8),
		FilterPixel2Column_D                     => to_unsigned(17, 8),
		FilterPixel3Row_D                        => to_unsigned(18, 8),
		FilterPixel3Column_D                     => to_unsigned(19, 8),
		FilterPixel4Row_D                        => to_unsigned(20, 8),
		FilterPixel4Column_D                     => to_unsigned(21, 8),
		FilterPixel5Row_D                        => to_unsigned(22, 8),
		FilterPixel5Column_D                     => to_unsigned(23, 8),
		FilterPixel6Row_D                        => to_unsigned(24, 8),
		FilterPixel6Column_D                     => to_unsigned(25, 8),
		FilterPixel7Row_D                        => to_unsigned(26, 8),
		FilterPixel7Column_D                     => to_unsigned(27, 8),
		HasBackgroundActivityFilter_S            => to_unsigned(28, 8),
		FilterBackgroundActivity_S               => to_unsigned(29, 8),
		FilterBackgroundActivityTime_D           => to_unsigned(30, 8),
		HasTestEventGenerator_S                  => to_unsigned(31, 8),
		TestEventGeneratorEnable_S               => to_unsigned(32, 8),
		FilterRefractoryPeriod_S                 => to_unsigned(33, 8),
		FilterRefractoryPeriodTime_D             => to_unsigned(34, 8),
		HasROIFilter_S                           => to_unsigned(35, 8),
		FilterROIStartColumn_D                   => to_unsigned(36, 8),
		FilterROIStartRow_D                      => to_unsigned(37, 8),
		FilterROIEndColumn_D                     => to_unsigned(38, 8),
		FilterROIEndRow_D                        => to_unsigned(39, 8),
		HasStatistics_S                          => to_unsigned(40, 8),
		StatisticsEventsRow64_D                  => to_unsigned(41, 8),
		StatisticsEventsRow32_D                  => to_unsigned(42, 8),
		StatisticsEventsColumn64_D               => to_unsigned(43, 8),
		StatisticsEventsColumn32_D               => to_unsigned(44, 8),
		StatisticsEventsDropped64_D              => to_unsigned(45, 8),
		StatisticsEventsDropped32_D              => to_unsigned(46, 8),
		StatisticsFilteredPixels64_D             => to_unsigned(47, 8),
		StatisticsFilteredPixels32_D             => to_unsigned(48, 8),
		StatisticsFilteredBackgroundActivity64_D => to_unsigned(49, 8),
		StatisticsFilteredBackgroundActivity32_D => to_unsigned(50, 8),
		StatisticsFilteredRefractoryPeriod64_D   => to_unsigned(51, 8),
		StatisticsFilteredRefractoryPeriod32_D   => to_unsigned(52, 8));

	constant DVS_AER_ACK_COUNTER_WIDTH  : integer := 4;
	constant DVS_FILTER_BA_DELTAT_WIDTH : integer := 12;

	-- Col/Row size as seen by user input depends on AXES_INVERT.
	constant DVS_USER_LENGTH_COLUMNS : integer := SelectInteger(CHIP_DVS_AXES_INVERT = '0', CHIP_DVS_SIZE_COLUMNS'length, CHIP_DVS_SIZE_ROWS'length);
	constant DVS_USER_LENGTH_ROWS    : integer := SelectInteger(CHIP_DVS_AXES_INVERT = '0', CHIP_DVS_SIZE_ROWS'length, CHIP_DVS_SIZE_COLUMNS'length);
	constant DVS_USER_VALUE_COLUMNS  : integer := SelectInteger(CHIP_DVS_AXES_INVERT = '0', to_integer(CHIP_DVS_SIZE_COLUMNS), to_integer(CHIP_DVS_SIZE_ROWS));
	constant DVS_USER_VALUE_ROWS     : integer := SelectInteger(CHIP_DVS_AXES_INVERT = '0', to_integer(CHIP_DVS_SIZE_ROWS), to_integer(CHIP_DVS_SIZE_COLUMNS));

	type tDVSAERConfig is record
		SizeColumns_D                  : unsigned(CHIP_DVS_SIZE_COLUMNS'range);
		SizeRows_D                     : unsigned(CHIP_DVS_SIZE_ROWS'range);
		OrientationInfo_D              : std_logic_vector(2 downto 0);
		Run_S                          : std_logic;
		AckDelayRow_D                  : unsigned(DVS_AER_ACK_COUNTER_WIDTH - 1 downto 0);
		AckDelayColumn_D               : unsigned(DVS_AER_ACK_COUNTER_WIDTH - 1 downto 0);
		AckExtensionRow_D              : unsigned(DVS_AER_ACK_COUNTER_WIDTH - 1 downto 0);
		AckExtensionColumn_D           : unsigned(DVS_AER_ACK_COUNTER_WIDTH - 1 downto 0);
		WaitOnTransferStall_S          : std_logic;
		FilterRowOnlyEvents_S          : std_logic;
		ExternalAERControl_S           : std_logic;
		HasPixelFilter_S               : std_logic;
		FilterPixel0Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel0Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel1Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel1Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel2Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel2Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel3Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel3Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel4Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel4Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel5Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel5Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel6Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel6Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterPixel7Row_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterPixel7Column_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		HasBackgroundActivityFilter_S  : std_logic;
		FilterBackgroundActivity_S     : std_logic;
		FilterBackgroundActivityTime_D : unsigned(DVS_FILTER_BA_DELTAT_WIDTH - 1 downto 0);
		HasTestEventGenerator_S        : std_logic;
		TestEventGeneratorEnable_S     : std_logic;
		FilterRefractoryPeriod_S       : std_logic;
		FilterRefractoryPeriodTime_D   : unsigned(DVS_FILTER_BA_DELTAT_WIDTH - 1 downto 0);
		HasROIFilter_S                 : std_logic;
		FilterROIStartColumn_D         : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterROIStartRow_D            : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
		FilterROIEndColumn_D           : unsigned(DVS_USER_LENGTH_COLUMNS - 1 downto 0);
		FilterROIEndRow_D              : unsigned(DVS_USER_LENGTH_ROWS - 1 downto 0);
	end record tDVSAERConfig;

	constant tDVSAERConfigDefault : tDVSAERConfig := (
		SizeColumns_D                  => CHIP_DVS_SIZE_COLUMNS,
		SizeRows_D                     => CHIP_DVS_SIZE_ROWS,
		OrientationInfo_D              => CHIP_DVS_AXES_INVERT & CHIP_DVS_ORIGIN_POINT,
		Run_S                          => '0',
		AckDelayRow_D                  => to_unsigned(4, tDVSAERConfig.AckDelayRow_D'length),
		AckDelayColumn_D               => to_unsigned(0, tDVSAERConfig.AckDelayColumn_D'length),
		AckExtensionRow_D              => to_unsigned(1, tDVSAERConfig.AckExtensionRow_D'length),
		AckExtensionColumn_D           => to_unsigned(0, tDVSAERConfig.AckExtensionColumn_D'length),
		WaitOnTransferStall_S          => '0',
		FilterRowOnlyEvents_S          => '1',
		ExternalAERControl_S           => '0',
		HasPixelFilter_S               => '0',
		FilterPixel0Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel0Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel1Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel1Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel2Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel2Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel3Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel3Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel4Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel4Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel5Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel5Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel6Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel6Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		FilterPixel7Row_D              => to_unsigned(DVS_USER_VALUE_ROWS, DVS_USER_LENGTH_ROWS),
		FilterPixel7Column_D           => to_unsigned(DVS_USER_VALUE_COLUMNS, DVS_USER_LENGTH_COLUMNS),
		HasBackgroundActivityFilter_S  => '0',
		FilterBackgroundActivity_S     => '0',
		FilterBackgroundActivityTime_D => to_unsigned(80, tDVSAERConfig.FilterBackgroundActivityTime_D'length),
		HasTestEventGenerator_S        => '0',
		TestEventGeneratorEnable_S     => '0',
		FilterRefractoryPeriod_S       => '0',
		FilterRefractoryPeriodTime_D   => to_unsigned(2, tDVSAERConfig.FilterRefractoryPeriodTime_D'length),
		HasROIFilter_S                 => '0',
		FilterROIStartColumn_D         => to_unsigned(0, DVS_USER_LENGTH_COLUMNS),
		FilterROIStartRow_D            => to_unsigned(0, DVS_USER_LENGTH_ROWS),
		FilterROIEndColumn_D           => to_unsigned(DVS_USER_VALUE_COLUMNS - 1, DVS_USER_LENGTH_COLUMNS),
		FilterROIEndRow_D              => to_unsigned(DVS_USER_VALUE_ROWS - 1, DVS_USER_LENGTH_ROWS));

	constant TRANSACTION_COUNTER_WIDTH : integer := 40;

	type tDVSAERConfigInfoOut is record
		StatisticsEventsRow_D                  : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsEventsColumn_D               : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsEventsDropped_D              : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsFilteredPixels_D             : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsFilteredBackgroundActivity_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsFilteredRefractoryPeriod_D   : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
	end record tDVSAERConfigInfoOut;

	constant tDVSAERConfigInfoOutDefault : tDVSAERConfigInfoOut := (
		StatisticsEventsRow_D                  => (others => '0'),
		StatisticsEventsColumn_D               => (others => '0'),
		StatisticsEventsDropped_D              => (others => '0'),
		StatisticsFilteredPixels_D             => (others => '0'),
		StatisticsFilteredBackgroundActivity_D => (others => '0'),
		StatisticsFilteredRefractoryPeriod_D   => (others => '0'));
end package DVSAERConfigRecords;
