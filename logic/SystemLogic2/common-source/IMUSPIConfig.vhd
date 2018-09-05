library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.IMUConfigRecords.all;

entity IMUSPIConfig is
	generic(
		IMU_ORIENTATION : std_logic_vector(2 downto 0) := "000");
	port(
		Clock_CI                : in  std_logic;
		Reset_RI                : in  std_logic;
		IMUConfig_DO            : out tIMUConfig;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI  : in  unsigned(6 downto 0);
		ConfigParamAddress_DI   : in  unsigned(7 downto 0);
		ConfigParamInput_DI     : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI     : in  std_logic;
		IMUConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity IMUSPIConfig;

architecture Behavioral of IMUSPIConfig is
	signal LatchIMUReg_S                    : std_logic;
	signal IMUOutput_DP, IMUOutput_DN       : std_logic_vector(31 downto 0);
	signal IMUConfigReg_DP, IMUConfigReg_DN : tIMUConfig;
begin
	IMUConfig_DO            <= IMUConfigReg_DP;
	IMUConfigParamOutput_DO <= IMUOutput_DP;

	LatchIMUReg_S <= '1' when ConfigModuleAddress_DI = IMUCONFIG_MODULE_ADDRESS else '0';

	imuIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, IMUConfigReg_DP)
	begin
		IMUConfigReg_DN <= IMUConfigReg_DP;
		IMUOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when IMUCONFIG_PARAM_ADDRESSES.Run_S =>
				IMUConfigReg_DN.Run_S <= ConfigParamInput_DI(0);
				IMUOutput_DN(0)       <= IMUConfigReg_DP.Run_S;

			when IMUCONFIG_PARAM_ADDRESSES.TempStandby_S =>
				IMUConfigReg_DN.TempStandby_S <= ConfigParamInput_DI(0);
				IMUOutput_DN(0)               <= IMUConfigReg_DP.TempStandby_S;

			when IMUCONFIG_PARAM_ADDRESSES.AccelStandby_S =>
				IMUConfigReg_DN.AccelStandby_S                <= ConfigParamInput_DI(tIMUConfig.AccelStandby_S'range);
				IMUOutput_DN(tIMUConfig.AccelStandby_S'range) <= IMUConfigReg_DP.AccelStandby_S;

			when IMUCONFIG_PARAM_ADDRESSES.GyroStandby_S =>
				IMUConfigReg_DN.GyroStandby_S                <= ConfigParamInput_DI(tIMUConfig.GyroStandby_S'range);
				IMUOutput_DN(tIMUConfig.GyroStandby_S'range) <= IMUConfigReg_DP.GyroStandby_S;

			when IMUCONFIG_PARAM_ADDRESSES.LPCycle_S =>
				IMUConfigReg_DN.LPCycle_S <= ConfigParamInput_DI(0);
				IMUOutput_DN(0)           <= IMUConfigReg_DP.LPCycle_S;

			when IMUCONFIG_PARAM_ADDRESSES.LPWakeup_D =>
				IMUConfigReg_DN.LPWakeup_D                <= unsigned(ConfigParamInput_DI(tIMUConfig.LPWakeup_D'range));
				IMUOutput_DN(tIMUConfig.LPWakeup_D'range) <= std_logic_vector(IMUConfigReg_DP.LPWakeup_D);

			when IMUCONFIG_PARAM_ADDRESSES.SampleRateDivider_D =>
				IMUConfigReg_DN.SampleRateDivider_D                <= unsigned(ConfigParamInput_DI(tIMUConfig.SampleRateDivider_D'range));
				IMUOutput_DN(tIMUConfig.SampleRateDivider_D'range) <= std_logic_vector(IMUConfigReg_DP.SampleRateDivider_D);

			when IMUCONFIG_PARAM_ADDRESSES.DigitalLowPassFilter_D =>
				IMUConfigReg_DN.DigitalLowPassFilter_D                <= unsigned(ConfigParamInput_DI(tIMUConfig.DigitalLowPassFilter_D'range));
				IMUOutput_DN(tIMUConfig.DigitalLowPassFilter_D'range) <= std_logic_vector(IMUConfigReg_DP.DigitalLowPassFilter_D);

			when IMUCONFIG_PARAM_ADDRESSES.AccelFullScale_D =>
				IMUConfigReg_DN.AccelFullScale_D                <= unsigned(ConfigParamInput_DI(tIMUConfig.AccelFullScale_D'range));
				IMUOutput_DN(tIMUConfig.AccelFullScale_D'range) <= std_logic_vector(IMUConfigReg_DP.AccelFullScale_D);

			when IMUCONFIG_PARAM_ADDRESSES.GyroFullScale_D =>
				IMUConfigReg_DN.GyroFullScale_D                <= unsigned(ConfigParamInput_DI(tIMUConfig.GyroFullScale_D'range));
				IMUOutput_DN(tIMUConfig.GyroFullScale_D'range) <= std_logic_vector(IMUConfigReg_DP.GyroFullScale_D);

			when IMUCONFIG_PARAM_ADDRESSES.OrientationInfo_D =>
				if IMU_ORIENTATION /= "000" then
					IMUConfigReg_DN.OrientationInfo_D                <= IMU_ORIENTATION;
					IMUOutput_DN(tIMUConfig.OrientationInfo_D'range) <= IMU_ORIENTATION;
				end if;

			when others => null;
		end case;
	end process imuIO;

	imuUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			IMUOutput_DP <= (others => '0');

			IMUConfigReg_DP <= tIMUConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			IMUOutput_DP <= IMUOutput_DN;

			if LatchIMUReg_S = '1' and ConfigLatchInput_SI = '1' then
				IMUConfigReg_DP <= IMUConfigReg_DN;
			end if;
		end if;
	end process imuUpdate;
end architecture Behavioral;
