library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package DACConfigRecords is
	constant DACCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(7, 7);

	type tDACConfigParamAddresses is record
		Run_S                 : unsigned(7 downto 0);
		DAC_D                 : unsigned(7 downto 0);
		Register_D            : unsigned(7 downto 0);
		Channel_D             : unsigned(7 downto 0);
		DataRead_D            : unsigned(7 downto 0);
		DataWrite_D           : unsigned(7 downto 0);
		Set_S                 : unsigned(7 downto 0);
		-- Random DAC support.
		RunRandomDACUSB_S     : unsigned(7 downto 0);
		RunRandomDAC_S        : unsigned(7 downto 0);
		RandomDACVMaxChan00_D : unsigned(7 downto 0);
		RandomDACVMaxChan01_D : unsigned(7 downto 0);
		RandomDACVMaxChan02_D : unsigned(7 downto 0);
		RandomDACVMaxChan03_D : unsigned(7 downto 0);
		RandomDACVMaxChan04_D : unsigned(7 downto 0);
		RandomDACVMaxChan05_D : unsigned(7 downto 0);
		RandomDACVMaxChan06_D : unsigned(7 downto 0);
		RandomDACVMaxChan07_D : unsigned(7 downto 0);
		RandomDACVMaxChan08_D : unsigned(7 downto 0);
		RandomDACVMaxChan09_D : unsigned(7 downto 0);
		RandomDACVMaxChan10_D : unsigned(7 downto 0);
		RandomDACVMaxChan11_D : unsigned(7 downto 0);
		RandomDACVMaxChan12_D : unsigned(7 downto 0);
		RandomDACVMaxChan13_D : unsigned(7 downto 0);
		RandomDACVMaxChan14_D : unsigned(7 downto 0);
		RandomDACVMaxChan15_D : unsigned(7 downto 0);
		RandomDACVMinChan00_D : unsigned(7 downto 0);
		RandomDACVMinChan01_D : unsigned(7 downto 0);
		RandomDACVMinChan02_D : unsigned(7 downto 0);
		RandomDACVMinChan03_D : unsigned(7 downto 0);
		RandomDACVMinChan04_D : unsigned(7 downto 0);
		RandomDACVMinChan05_D : unsigned(7 downto 0);
		RandomDACVMinChan06_D : unsigned(7 downto 0);
		RandomDACVMinChan07_D : unsigned(7 downto 0);
		RandomDACVMinChan08_D : unsigned(7 downto 0);
		RandomDACVMinChan09_D : unsigned(7 downto 0);
		RandomDACVMinChan10_D : unsigned(7 downto 0);
		RandomDACVMinChan11_D : unsigned(7 downto 0);
		RandomDACVMinChan12_D : unsigned(7 downto 0);
		RandomDACVMinChan13_D : unsigned(7 downto 0);
		RandomDACVMinChan14_D : unsigned(7 downto 0);
		RandomDACVMinChan15_D : unsigned(7 downto 0);
	end record tDACConfigParamAddresses;

	constant DACCONFIG_PARAM_ADDRESSES : tDACConfigParamAddresses := (
		Run_S                 => to_unsigned(0, 8),
		DAC_D                 => to_unsigned(1, 8),
		Register_D            => to_unsigned(2, 8),
		Channel_D             => to_unsigned(3, 8),
		DataRead_D            => to_unsigned(4, 8),
		DataWrite_D           => to_unsigned(5, 8),
		Set_S                 => to_unsigned(6, 8),
		RunRandomDACUSB_S     => to_unsigned(14, 8),
		RunRandomDAC_S        => to_unsigned(15, 8),
		RandomDACVMaxChan00_D => to_unsigned(16, 8),
		RandomDACVMaxChan01_D => to_unsigned(17, 8),
		RandomDACVMaxChan02_D => to_unsigned(18, 8),
		RandomDACVMaxChan03_D => to_unsigned(19, 8),
		RandomDACVMaxChan04_D => to_unsigned(20, 8),
		RandomDACVMaxChan05_D => to_unsigned(21, 8),
		RandomDACVMaxChan06_D => to_unsigned(22, 8),
		RandomDACVMaxChan07_D => to_unsigned(23, 8),
		RandomDACVMaxChan08_D => to_unsigned(24, 8),
		RandomDACVMaxChan09_D => to_unsigned(25, 8),
		RandomDACVMaxChan10_D => to_unsigned(26, 8),
		RandomDACVMaxChan11_D => to_unsigned(27, 8),
		RandomDACVMaxChan12_D => to_unsigned(28, 8),
		RandomDACVMaxChan13_D => to_unsigned(29, 8),
		RandomDACVMaxChan14_D => to_unsigned(30, 8),
		RandomDACVMaxChan15_D => to_unsigned(31, 8),
		RandomDACVMinChan00_D => to_unsigned(32, 8),
		RandomDACVMinChan01_D => to_unsigned(33, 8),
		RandomDACVMinChan02_D => to_unsigned(34, 8),
		RandomDACVMinChan03_D => to_unsigned(35, 8),
		RandomDACVMinChan04_D => to_unsigned(36, 8),
		RandomDACVMinChan05_D => to_unsigned(37, 8),
		RandomDACVMinChan06_D => to_unsigned(38, 8),
		RandomDACVMinChan07_D => to_unsigned(39, 8),
		RandomDACVMinChan08_D => to_unsigned(40, 8),
		RandomDACVMinChan09_D => to_unsigned(41, 8),
		RandomDACVMinChan10_D => to_unsigned(42, 8),
		RandomDACVMinChan11_D => to_unsigned(43, 8),
		RandomDACVMinChan12_D => to_unsigned(44, 8),
		RandomDACVMinChan13_D => to_unsigned(45, 8),
		RandomDACVMinChan14_D => to_unsigned(46, 8),
		RandomDACVMinChan15_D => to_unsigned(47, 8));

	-- Support up to 4 DACs, with up to 4 registers, each with up to 16 channels each.
	constant DAC_CHAN_NUMBER : integer := 4 * 4 * 16;

	constant DAC_REGISTER_LENGTH : integer := 2;
	constant DAC_CHANNEL_LENGTH  : integer := 4;
	constant DAC_DATA_LENGTH     : integer := 14; -- This is for an AD5390.

	type tDACConfig is record
		Run_S                 : std_logic;
		DAC_D                 : unsigned(1 downto 0); -- Address up to 4 DACs.
		Register_D            : unsigned(DAC_REGISTER_LENGTH - 1 downto 0);
		Channel_D             : unsigned(DAC_CHANNEL_LENGTH - 1 downto 0);
		DataWrite_D           : std_logic_vector(DAC_DATA_LENGTH - 1 downto 0);
		Set_S                 : std_logic;
		-- Random DAC support.
		RunRandomDACUSB_S     : std_logic;
		RunRandomDAC_S        : std_logic;
		RandomDACVMaxChan00_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan01_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan02_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan03_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan04_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan05_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan06_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan07_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan08_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan09_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan10_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan11_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan12_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan13_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan14_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMaxChan15_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan00_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan01_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan02_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan03_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan04_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan05_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan06_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan07_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan08_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan09_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan10_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan11_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan12_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan13_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan14_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
		RandomDACVMinChan15_D : unsigned(DAC_DATA_LENGTH - 1 downto 0);
	end record tDACConfig;

	constant tDACConfigDefault : tDACConfig := (
		Run_S                 => '0',
		DAC_D                 => (others => '0'),
		Register_D            => (others => '0'),
		Channel_D             => (others => '0'),
		DataWrite_D           => (others => '0'),
		Set_S                 => '0',
		RunRandomDACUSB_S     => '0',
		RunRandomDAC_S        => '0',
		RandomDACVMaxChan00_D => (others => '1'),
		RandomDACVMaxChan01_D => (others => '1'),
		RandomDACVMaxChan02_D => (others => '1'),
		RandomDACVMaxChan03_D => (others => '1'),
		RandomDACVMaxChan04_D => (others => '1'),
		RandomDACVMaxChan05_D => (others => '1'),
		RandomDACVMaxChan06_D => (others => '1'),
		RandomDACVMaxChan07_D => (others => '1'),
		RandomDACVMaxChan08_D => (others => '1'),
		RandomDACVMaxChan09_D => (others => '1'),
		RandomDACVMaxChan10_D => (others => '1'),
		RandomDACVMaxChan11_D => (others => '1'),
		RandomDACVMaxChan12_D => (others => '1'),
		RandomDACVMaxChan13_D => (others => '1'),
		RandomDACVMaxChan14_D => (others => '1'),
		RandomDACVMaxChan15_D => (others => '1'),
		RandomDACVMinChan00_D => (others => '0'),
		RandomDACVMinChan01_D => (others => '0'),
		RandomDACVMinChan02_D => (others => '0'),
		RandomDACVMinChan03_D => (others => '0'),
		RandomDACVMinChan04_D => (others => '0'),
		RandomDACVMinChan05_D => (others => '0'),
		RandomDACVMinChan06_D => (others => '0'),
		RandomDACVMinChan07_D => (others => '0'),
		RandomDACVMinChan08_D => (others => '0'),
		RandomDACVMinChan09_D => (others => '0'),
		RandomDACVMinChan10_D => (others => '0'),
		RandomDACVMinChan11_D => (others => '0'),
		RandomDACVMinChan12_D => (others => '0'),
		RandomDACVMinChan13_D => (others => '0'),
		RandomDACVMinChan14_D => (others => '0'),
		RandomDACVMinChan15_D => (others => '0'));
end package DACConfigRecords;
