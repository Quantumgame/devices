library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package MultiplexerConfigRecords is
	constant MULTIPLEXERCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(0, 7);

	type tMultiplexerConfigParamAddresses is record
		Run_S                       : unsigned(7 downto 0);
		TimestampRun_S              : unsigned(7 downto 0);
		TimestampReset_S            : unsigned(7 downto 0);
		ForceChipBiasEnable_S       : unsigned(7 downto 0);
		DropInput1OnTransferStall_S : unsigned(7 downto 0);
		DropInput2OnTransferStall_S : unsigned(7 downto 0);
		DropInput3OnTransferStall_S : unsigned(7 downto 0);
		DropInput4OnTransferStall_S : unsigned(7 downto 0);
		DropInput5OnTransferStall_S : unsigned(7 downto 0);
		DropInput6OnTransferStall_S : unsigned(7 downto 0);
		HasStatistics_S             : unsigned(7 downto 0);
		StatisticsInput1Dropped64_D : unsigned(7 downto 0);
		StatisticsInput1Dropped32_D : unsigned(7 downto 0);
		StatisticsInput2Dropped64_D : unsigned(7 downto 0);
		StatisticsInput2Dropped32_D : unsigned(7 downto 0);
		StatisticsInput3Dropped64_D : unsigned(7 downto 0);
		StatisticsInput3Dropped32_D : unsigned(7 downto 0);
		StatisticsInput4Dropped64_D : unsigned(7 downto 0);
		StatisticsInput4Dropped32_D : unsigned(7 downto 0);
		StatisticsInput5Dropped64_D : unsigned(7 downto 0);
		StatisticsInput5Dropped32_D : unsigned(7 downto 0);
		StatisticsInput6Dropped64_D : unsigned(7 downto 0);
		StatisticsInput6Dropped32_D : unsigned(7 downto 0);
	end record tMultiplexerConfigParamAddresses;

	constant MULTIPLEXERCONFIG_PARAM_ADDRESSES : tMultiplexerConfigParamAddresses := (
		Run_S                       => to_unsigned(0, 8),
		TimestampRun_S              => to_unsigned(1, 8),
		TimestampReset_S            => to_unsigned(2, 8),
		ForceChipBiasEnable_S       => to_unsigned(3, 8),
		DropInput1OnTransferStall_S => to_unsigned(4, 8),
		DropInput2OnTransferStall_S => to_unsigned(5, 8),
		DropInput3OnTransferStall_S => to_unsigned(6, 8),
		DropInput4OnTransferStall_S => to_unsigned(7, 8),
		DropInput5OnTransferStall_S => to_unsigned(8, 8),
		DropInput6OnTransferStall_S => to_unsigned(9, 8),
		HasStatistics_S             => to_unsigned(10, 8),
		StatisticsInput1Dropped64_D => to_unsigned(11, 8),
		StatisticsInput1Dropped32_D => to_unsigned(12, 8),
		StatisticsInput2Dropped64_D => to_unsigned(13, 8),
		StatisticsInput2Dropped32_D => to_unsigned(14, 8),
		StatisticsInput3Dropped64_D => to_unsigned(15, 8),
		StatisticsInput3Dropped32_D => to_unsigned(16, 8),
		StatisticsInput4Dropped64_D => to_unsigned(17, 8),
		StatisticsInput4Dropped32_D => to_unsigned(18, 8),
		StatisticsInput5Dropped64_D => to_unsigned(19, 8),
		StatisticsInput5Dropped32_D => to_unsigned(20, 8),
		StatisticsInput6Dropped64_D => to_unsigned(21, 8),
		StatisticsInput6Dropped32_D => to_unsigned(22, 8));

	type tMultiplexerConfig is record
		Run_S                       : std_logic;
		TimestampRun_S              : std_logic;
		TimestampReset_S            : std_logic;
		ForceChipBiasEnable_S       : std_logic;
		DropInput1OnTransferStall_S : std_logic;
		DropInput2OnTransferStall_S : std_logic;
		DropInput3OnTransferStall_S : std_logic;
		DropInput4OnTransferStall_S : std_logic;
		DropInput5OnTransferStall_S : std_logic;
		DropInput6OnTransferStall_S : std_logic;
	end record tMultiplexerConfig;

	constant tMultiplexerConfigDefault : tMultiplexerConfig := (
		Run_S                       => '0',
		TimestampRun_S              => '0',
		TimestampReset_S            => '0',
		ForceChipBiasEnable_S       => '0',
		DropInput1OnTransferStall_S => '0',
		DropInput2OnTransferStall_S => '0',
		DropInput3OnTransferStall_S => '0',
		DropInput4OnTransferStall_S => '0',
		DropInput5OnTransferStall_S => '0',
		DropInput6OnTransferStall_S => '0');

	constant TRANSACTION_COUNTER_WIDTH     : integer := 40;

	type tMultiplexerConfigInfoOut is record
		StatisticsInput1Dropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsInput2Dropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsInput3Dropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsInput4Dropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsInput5Dropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
		StatisticsInput6Dropped_D : unsigned(TRANSACTION_COUNTER_WIDTH - 1 downto 0);
	end record tMultiplexerConfigInfoOut;

	constant tMultiplexerConfigInfoOutDefault : tMultiplexerConfigInfoOut := (
		StatisticsInput1Dropped_D => (others => '0'),
		StatisticsInput2Dropped_D => (others => '0'),
		StatisticsInput3Dropped_D => (others => '0'),
		StatisticsInput4Dropped_D => (others => '0'),
		StatisticsInput5Dropped_D => (others => '0'),
		StatisticsInput6Dropped_D => (others => '0'));
end package MultiplexerConfigRecords;
