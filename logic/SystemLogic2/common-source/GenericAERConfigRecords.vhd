library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package GenericAERConfigRecords is
	constant GENERICAERCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(1, 7);

	type tGenericAERConfigParamAddresses is record
		Run_S                       : unsigned(7 downto 0);
		AckDelay_D                  : unsigned(7 downto 0);
		AckExtension_D              : unsigned(7 downto 0);
		WaitOnTransferStall_S       : unsigned(7 downto 0);
		ExternalAERControl_S        : unsigned(7 downto 0);
		HasStatistics_S             : unsigned(7 downto 0);
		StatisticsEvents64_D        : unsigned(7 downto 0);
		StatisticsEvents32_D        : unsigned(7 downto 0);
		StatisticsEventsDropped64_D : unsigned(7 downto 0);
		StatisticsEventsDropped32_D : unsigned(7 downto 0);
	end record tGenericAERConfigParamAddresses;

	constant GENERICAERCONFIG_PARAM_ADDRESSES : tGenericAERConfigParamAddresses := (
		Run_S                       => to_unsigned(3, 8),
		AckDelay_D                  => to_unsigned(4, 8),
		AckExtension_D              => to_unsigned(6, 8),
		WaitOnTransferStall_S       => to_unsigned(8, 8),
		ExternalAERControl_S        => to_unsigned(10, 8),
		HasStatistics_S             => to_unsigned(40, 8),
		StatisticsEvents64_D        => to_unsigned(41, 8),
		StatisticsEvents32_D        => to_unsigned(42, 8),
		StatisticsEventsDropped64_D => to_unsigned(45, 8),
		StatisticsEventsDropped32_D => to_unsigned(46, 8));

	constant GENERIC_AER_ACK_COUNTER_WIDTH : integer := 12;

	type tGenericAERConfig is record
		Run_S                 : std_logic;
		AckDelay_D            : unsigned(GENERIC_AER_ACK_COUNTER_WIDTH - 1 downto 0);
		AckExtension_D        : unsigned(GENERIC_AER_ACK_COUNTER_WIDTH - 1 downto 0);
		WaitOnTransferStall_S : std_logic;
		ExternalAERControl_S  : std_logic;
	end record tGenericAERConfig;

	constant tGenericAERConfigDefault : tGenericAERConfig := (
		Run_S                 => '0',
		AckDelay_D            => to_unsigned(0, tGenericAERConfig.AckDelay_D'length),
		AckExtension_D        => to_unsigned(0, tGenericAERConfig.AckExtension_D'length),
		WaitOnTransferStall_S => '0',
		ExternalAERControl_S  => '0');

	constant TRANSACTION_COUNTER_WIDTH : integer := 40;

	type tGenericAERConfigInfoOut is record
		StatisticsEvents_D        : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsEventsDropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
	end record tGenericAERConfigInfoOut;

	constant tGenericAERConfigInfoOutDefault : tGenericAERConfigInfoOut := (
		StatisticsEvents_D        => (others => '0'),
		StatisticsEventsDropped_D => (others => '0'));
end package GenericAERConfigRecords;
