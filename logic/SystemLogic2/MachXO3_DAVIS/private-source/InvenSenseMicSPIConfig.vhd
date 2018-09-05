library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.InvenSenseMicConfigRecords.all;

entity InvenSenseMicSPIConfig is
	port(
		Clock_CI                          : in  std_logic;
		Reset_RI                          : in  std_logic;
		InvenSenseMicConfig_DO            : out tInvenSenseMicConfig;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI            : in  unsigned(6 downto 0);
		ConfigParamAddress_DI             : in  unsigned(7 downto 0);
		ConfigParamInput_DI               : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI               : in  std_logic;
		InvenSenseMicConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity InvenSenseMicSPIConfig;

architecture Behavioral of InvenSenseMicSPIConfig is
	signal LatchInvenSenseMicReg_S                              : std_logic;
	signal InvenSenseMicOutput_DP, InvenSenseMicOutput_DN       : std_logic_vector(31 downto 0);
	signal InvenSenseMicConfigReg_DP, InvenSenseMicConfigReg_DN : tInvenSenseMicConfig;
begin
	InvenSenseMicConfig_DO            <= InvenSenseMicConfigReg_DP;
	InvenSenseMicConfigParamOutput_DO <= InvenSenseMicOutput_DP;

	LatchInvenSenseMicReg_S <= '1' when ConfigModuleAddress_DI = INVENSENSEMICCONFIG_MODULE_ADDRESS else '0';

	invenSenseMicIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, InvenSenseMicConfigReg_DP)
	begin
		InvenSenseMicConfigReg_DN <= InvenSenseMicConfigReg_DP;
		InvenSenseMicOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when INVENSENSEMICCONFIG_PARAM_ADDRESSES.Run_S =>
				InvenSenseMicConfigReg_DN.Run_S <= ConfigParamInput_DI(0);
				InvenSenseMicOutput_DN(0)       <= InvenSenseMicConfigReg_DP.Run_S;

			when INVENSENSEMICCONFIG_PARAM_ADDRESSES.SampleFrequency_D =>
				-- Limit value to be between 30 and 219. Default is 32 at startup.
				if unsigned(ConfigParamInput_DI(tInvenSenseMicConfig.SampleCycles_D'range)) < 30 then
					InvenSenseMicConfigReg_DN.SampleCycles_D <= to_unsigned(30, tInvenSenseMicConfig.SampleCycles_D'length);
				elsif unsigned(ConfigParamInput_DI(tInvenSenseMicConfig.SampleCycles_D'range)) > 219 then
					InvenSenseMicConfigReg_DN.SampleCycles_D <= to_unsigned(219, tInvenSenseMicConfig.SampleCycles_D'length);
				else
					InvenSenseMicConfigReg_DN.SampleCycles_D <= unsigned(ConfigParamInput_DI(tInvenSenseMicConfig.SampleCycles_D'range));
				end if;
				InvenSenseMicOutput_DN(tInvenSenseMicConfig.SampleCycles_D'range) <= std_logic_vector(InvenSenseMicConfigReg_DP.SampleCycles_D);

			when others => null;
		end case;
	end process invenSenseMicIO;

	invenSenseMicRegisterUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			InvenSenseMicOutput_DP <= (others => '0');

			InvenSenseMicConfigReg_DP <= tInvenSenseMicConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			InvenSenseMicOutput_DP <= InvenSenseMicOutput_DN;

			if LatchInvenSenseMicReg_S = '1' and ConfigLatchInput_SI = '1' then
				InvenSenseMicConfigReg_DP <= InvenSenseMicConfigReg_DN;
			end if;
		end if;
	end process invenSenseMicRegisterUpdate;
end architecture Behavioral;
