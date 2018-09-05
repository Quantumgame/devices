library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.DACConfigRecords.all;

entity DACSPIConfig is
	port(
		Clock_CI                : in  std_logic;
		Reset_RI                : in  std_logic;
		DACConfig_DO            : out tDACConfig;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI  : in  unsigned(6 downto 0);
		ConfigParamAddress_DI   : in  unsigned(7 downto 0);
		ConfigParamInput_DI     : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI     : in  std_logic;
		DACConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity DACSPIConfig;

architecture Behavioral of DACSPIConfig is
	signal DACConfigStorage_DP, DACConfigStorage_DN : std_logic_vector(DAC_DATA_LENGTH - 1 downto 0);

	constant DAC_CHAN_SIZE : integer := integer(ceil(log2(real(DAC_CHAN_NUMBER))));

	signal DACConfigStorageAddress_D     : unsigned(DAC_CHAN_SIZE - 1 downto 0);
	signal DACConfigStorageWriteEnable_S : std_logic;

	signal LatchDACReg_S                    : std_logic;
	signal DACInput_DP, DACInput_DN         : std_logic_vector(31 downto 0);
	signal DACOutput_DP, DACOutput_DN       : std_logic_vector(31 downto 0);
	signal DACConfigReg_DP, DACConfigReg_DN : tDACConfig;
begin
	DACConfig_DO            <= DACConfigReg_DP;
	DACConfigParamOutput_DO <= DACOutput_DP;

	LatchDACReg_S <= '1' when ConfigModuleAddress_DI = DACCONFIG_MODULE_ADDRESS else '0';

	dacConfigStorage : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => DAC_CHAN_NUMBER,
			ADDRESS_WIDTH => DAC_CHAN_SIZE,
			DATA_WIDTH    => DAC_DATA_LENGTH)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI,
			Address_DI     => DACConfigStorageAddress_D,
			Enable_SI      => '1',
			WriteEnable_SI => DACConfigStorageWriteEnable_S,
			Data_DI        => DACConfigStorage_DN,
			Data_DO        => DACConfigStorage_DP);

	DACConfigStorageAddress_D     <= DACConfigReg_DP.DAC_D & DACConfigReg_DP.Register_D & DACConfigReg_DP.Channel_D;
	DACConfigStorageWriteEnable_S <= '1' when (LatchDACReg_S = '1' and ConfigLatchInput_SI = '1' and ConfigParamAddress_DI = DACCONFIG_PARAM_ADDRESSES.Set_S) else '0';
	DACConfigStorage_DN           <= DACConfigReg_DP.DataWrite_D;

	dacIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, DACInput_DP, DACConfigReg_DP, DACConfigStorage_DP)
	begin
		DACConfigReg_DN <= DACConfigReg_DP;
		DACInput_DN     <= ConfigParamInput_DI;
		DACOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when DACCONFIG_PARAM_ADDRESSES.Run_S =>
				DACConfigReg_DN.Run_S <= DACInput_DP(0);
				DACOutput_DN(0)       <= DACConfigReg_DP.Run_S;

			when DACCONFIG_PARAM_ADDRESSES.DAC_D =>
				DACConfigReg_DN.DAC_D                <= unsigned(DACInput_DP(tDACConfig.DAC_D'range));
				DACOutput_DN(tDACConfig.DAC_D'range) <= std_logic_vector(DACConfigReg_DP.DAC_D);

			when DACCONFIG_PARAM_ADDRESSES.Register_D =>
				DACConfigReg_DN.Register_D                <= unsigned(DACInput_DP(tDACConfig.Register_D'range));
				DACOutput_DN(tDACConfig.Register_D'range) <= std_logic_vector(DACConfigReg_DP.Register_D);

			when DACCONFIG_PARAM_ADDRESSES.Channel_D =>
				DACConfigReg_DN.Channel_D                <= unsigned(DACInput_DP(tDACConfig.Channel_D'range));
				DACOutput_DN(tDACConfig.Channel_D'range) <= std_logic_vector(DACConfigReg_DP.Channel_D);

			when DACCONFIG_PARAM_ADDRESSES.DataRead_D =>
				DACOutput_DN(DAC_DATA_LENGTH - 1 downto 0) <= DACConfigStorage_DP;

			when DACCONFIG_PARAM_ADDRESSES.DataWrite_D =>
				DACConfigReg_DN.DataWrite_D                <= DACInput_DP(tDACConfig.DataWrite_D'range);
				DACOutput_DN(tDACConfig.DataWrite_D'range) <= DACConfigReg_DP.DataWrite_D;

			when DACCONFIG_PARAM_ADDRESSES.Set_S =>
				DACConfigReg_DN.Set_S <= DACInput_DP(0);
				DACOutput_DN(0)       <= DACConfigReg_DP.Set_S;

			when DACCONFIG_PARAM_ADDRESSES.RunRandomDACUSB_S =>
				DACConfigReg_DN.RunRandomDACUSB_S <= DACInput_DP(0);
				DACOutput_DN(0)                <= DACConfigReg_DP.RunRandomDACUSB_S;

			when DACCONFIG_PARAM_ADDRESSES.RunRandomDAC_S =>
				DACConfigReg_DN.RunRandomDAC_S <= DACInput_DP(0);
				DACOutput_DN(0)                <= DACConfigReg_DP.RunRandomDAC_S;

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan00_D =>
				DACConfigReg_DN.RandomDACVMaxChan00_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan00_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan00_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan00_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan01_D =>
				DACConfigReg_DN.RandomDACVMaxChan01_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan01_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan01_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan01_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan02_D =>
				DACConfigReg_DN.RandomDACVMaxChan02_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan02_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan02_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan02_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan03_D =>
				DACConfigReg_DN.RandomDACVMaxChan03_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan03_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan03_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan03_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan04_D =>
				DACConfigReg_DN.RandomDACVMaxChan04_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan04_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan04_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan04_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan05_D =>
				DACConfigReg_DN.RandomDACVMaxChan05_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan05_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan05_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan05_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan06_D =>
				DACConfigReg_DN.RandomDACVMaxChan06_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan06_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan06_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan06_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan07_D =>
				DACConfigReg_DN.RandomDACVMaxChan07_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan07_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan07_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan07_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan08_D =>
				DACConfigReg_DN.RandomDACVMaxChan08_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan08_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan08_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan08_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan09_D =>
				DACConfigReg_DN.RandomDACVMaxChan09_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan09_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan09_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan09_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan10_D =>
				DACConfigReg_DN.RandomDACVMaxChan10_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan10_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan10_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan10_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan11_D =>
				DACConfigReg_DN.RandomDACVMaxChan11_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan11_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan11_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan11_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan12_D =>
				DACConfigReg_DN.RandomDACVMaxChan12_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan12_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan12_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan12_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan13_D =>
				DACConfigReg_DN.RandomDACVMaxChan13_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan13_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan13_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan13_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan14_D =>
				DACConfigReg_DN.RandomDACVMaxChan14_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan14_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan14_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan14_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMaxChan15_D =>
				DACConfigReg_DN.RandomDACVMaxChan15_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMaxChan15_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMaxChan15_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMaxChan15_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan00_D =>
				DACConfigReg_DN.RandomDACVMinChan00_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan00_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan00_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan00_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan01_D =>
				DACConfigReg_DN.RandomDACVMinChan01_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan01_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan01_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan01_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan02_D =>
				DACConfigReg_DN.RandomDACVMinChan02_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan02_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan02_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan02_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan03_D =>
				DACConfigReg_DN.RandomDACVMinChan03_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan03_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan03_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan03_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan04_D =>
				DACConfigReg_DN.RandomDACVMinChan04_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan04_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan04_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan04_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan05_D =>
				DACConfigReg_DN.RandomDACVMinChan05_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan05_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan05_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan05_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan06_D =>
				DACConfigReg_DN.RandomDACVMinChan06_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan06_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan06_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan06_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan07_D =>
				DACConfigReg_DN.RandomDACVMinChan07_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan07_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan07_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan07_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan08_D =>
				DACConfigReg_DN.RandomDACVMinChan08_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan08_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan08_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan08_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan09_D =>
				DACConfigReg_DN.RandomDACVMinChan09_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan09_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan09_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan09_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan10_D =>
				DACConfigReg_DN.RandomDACVMinChan10_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan10_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan10_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan10_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan11_D =>
				DACConfigReg_DN.RandomDACVMinChan11_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan11_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan11_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan11_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan12_D =>
				DACConfigReg_DN.RandomDACVMinChan12_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan12_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan12_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan12_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan13_D =>
				DACConfigReg_DN.RandomDACVMinChan13_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan13_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan13_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan13_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan14_D =>
				DACConfigReg_DN.RandomDACVMinChan14_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan14_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan14_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan14_D);

			when DACCONFIG_PARAM_ADDRESSES.RandomDACVMinChan15_D =>
				DACConfigReg_DN.RandomDACVMinChan15_D                <= unsigned(DACInput_DP(tDACConfig.RandomDACVMinChan15_D'range));
				DACOutput_DN(tDACConfig.RandomDACVMinChan15_D'range) <= std_logic_vector(DACConfigReg_DP.RandomDACVMinChan15_D);

			when others => null;
		end case;
	end process dacIO;

	dacUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			DACInput_DP  <= (others => '0');
			DACOutput_DP <= (others => '0');

			DACConfigReg_DP <= tDACConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			DACInput_DP  <= DACInput_DN;
			DACOutput_DP <= DACOutput_DN;

			if LatchDACReg_S = '1' and ConfigLatchInput_SI = '1' then
				DACConfigReg_DP <= DACConfigReg_DN;
			end if;
		end if;
	end process dacUpdate;
end architecture Behavioral;
