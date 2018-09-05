library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.D4AAPSADCConfigRecords.all;
use work.Settings.CHIP_APS_SIZE_COLUMNS;
use work.Settings.CHIP_APS_SIZE_ROWS;
use work.Settings.CHIP_APS_STREAM_START;
use work.Settings.CHIP_APS_AXES_INVERT;

entity D4AAPSADCSPIConfig is
	generic(
		ENABLE_QUAD_ROI : boolean := false);
	port(
		Clock_CI                      : in  std_logic;
		Reset_RI                      : in  std_logic;
		D4AAPSADCConfig_DO            : out tD4AAPSADCConfig;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI        : in  unsigned(6 downto 0);
		ConfigParamAddress_DI         : in  unsigned(7 downto 0);
		ConfigParamInput_DI           : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI           : in  std_logic;
		D4AAPSADCConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity D4AAPSADCSPIConfig;

architecture Behavioral of D4AAPSADCSPIConfig is
	signal LatchD4AAPSADCReg_S                          : std_logic;
	signal D4AAPSADCOutput_DP, D4AAPSADCOutput_DN       : std_logic_vector(31 downto 0);
	signal D4AAPSADCConfigReg_DP, D4AAPSADCConfigReg_DN : tD4AAPSADCConfig;
begin
	D4AAPSADCConfig_DO            <= D4AAPSADCConfigReg_DP;
	D4AAPSADCConfigParamOutput_DO <= D4AAPSADCOutput_DP;

	LatchD4AAPSADCReg_S <= '1' when ConfigModuleAddress_DI = D4AAPSADCCONFIG_MODULE_ADDRESS else '0';

	apsadcIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, D4AAPSADCConfigReg_DP)
	begin
		D4AAPSADCConfigReg_DN <= D4AAPSADCConfigReg_DP;
		D4AAPSADCOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when D4AAPSADCCONFIG_PARAM_ADDRESSES.SizeColumns_D =>
				D4AAPSADCConfigReg_DN.SizeColumns_D                      <= CHIP_APS_SIZE_COLUMNS;
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.SizeColumns_D'range) <= std_logic_vector(CHIP_APS_SIZE_COLUMNS);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.SizeRows_D =>
				D4AAPSADCConfigReg_DN.SizeRows_D                      <= CHIP_APS_SIZE_ROWS;
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.SizeRows_D'range) <= std_logic_vector(CHIP_APS_SIZE_ROWS);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.OrientationInfo_D =>
				D4AAPSADCConfigReg_DN.OrientationInfo_D                      <= CHIP_APS_AXES_INVERT & CHIP_APS_STREAM_START;
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.OrientationInfo_D'range) <= CHIP_APS_AXES_INVERT & CHIP_APS_STREAM_START;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ColorFilter_D =>
				D4AAPSADCConfigReg_DN.ColorFilter_D                      <= ConfigParamInput_DI(tD4AAPSADCConfig.ColorFilter_D'range);
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.ColorFilter_D'range) <= D4AAPSADCConfigReg_DP.ColorFilter_D;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.Run_S =>
				D4AAPSADCConfigReg_DN.Run_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)       <= D4AAPSADCConfigReg_DP.Run_S;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ResetRead_S =>
				D4AAPSADCConfigReg_DN.ResetRead_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)             <= D4AAPSADCConfigReg_DP.ResetRead_S;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.WaitOnTransferStall_S =>
				D4AAPSADCConfigReg_DN.WaitOnTransferStall_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)                       <= D4AAPSADCConfigReg_DP.WaitOnTransferStall_S;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.HasGlobalShutter_S =>
				D4AAPSADCConfigReg_DN.HasGlobalShutter_S <= '1';
				D4AAPSADCOutput_DN(0)                    <= '1';

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.GlobalShutter_S =>
				D4AAPSADCConfigReg_DN.GlobalShutter_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)                 <= D4AAPSADCConfigReg_DP.GlobalShutter_S;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartColumn0_D =>
				D4AAPSADCConfigReg_DN.StartColumn0_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartColumn0_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartColumn0_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartColumn0_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartRow0_D =>
				D4AAPSADCConfigReg_DN.StartRow0_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartRow0_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartRow0_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartRow0_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndColumn0_D =>
				D4AAPSADCConfigReg_DN.EndColumn0_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndColumn0_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndColumn0_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndColumn0_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndRow0_D =>
				D4AAPSADCConfigReg_DN.EndRow0_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndRow0_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndRow0_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndRow0_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.Exposure_D =>
				D4AAPSADCConfigReg_DN.Exposure_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.Exposure_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.Exposure_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.Exposure_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.FrameDelay_D =>
				D4AAPSADCConfigReg_DN.FrameDelay_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.FrameDelay_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.FrameDelay_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.FrameDelay_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.RowSettle_D =>
				D4AAPSADCConfigReg_DN.RowSettle_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.RowSettle_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.RowSettle_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.RowSettle_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.HasQuadROI_S =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.HasQuadROI_S <= '1';
					D4AAPSADCOutput_DN(0)              <= '1';
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartColumn1_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.StartColumn1_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartColumn1_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartColumn1_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartColumn1_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartRow1_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.StartRow1_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartRow1_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartRow1_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartRow1_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndColumn1_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.EndColumn1_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndColumn1_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndColumn1_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndColumn1_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndRow1_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.EndRow1_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndRow1_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndRow1_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndRow1_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartColumn2_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.StartColumn2_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartColumn2_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartColumn2_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartColumn2_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartRow2_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.StartRow2_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartRow2_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartRow2_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartRow2_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndColumn2_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.EndColumn2_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndColumn2_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndColumn2_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndColumn2_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndRow2_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.EndRow2_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndRow2_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndRow2_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndRow2_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartColumn3_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.StartColumn3_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartColumn3_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartColumn3_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartColumn3_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.StartRow3_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.StartRow3_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.StartRow3_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.StartRow3_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.StartRow3_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndColumn3_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.EndColumn3_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndColumn3_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndColumn3_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndColumn3_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.EndRow3_D =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.EndRow3_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.EndRow3_D'range));
					D4AAPSADCOutput_DN(tD4AAPSADCConfig.EndRow3_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.EndRow3_D);
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.HasInternalADC_S =>
				D4AAPSADCConfigReg_DN.HasInternalADC_S <= '1';
				D4AAPSADCOutput_DN(0)                  <= '1';

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.SampleEnable_S =>
				D4AAPSADCConfigReg_DN.SampleEnable_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)                <= D4AAPSADCConfigReg_DP.SampleEnable_S;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.SampleSettle_D =>
				D4AAPSADCConfigReg_DN.SampleSettle_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.SampleSettle_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.SampleSettle_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.SampleSettle_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.RampReset_D =>
				D4AAPSADCConfigReg_DN.RampReset_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.RampReset_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.RampReset_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.RampReset_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.RampShortReset_S =>
				D4AAPSADCConfigReg_DN.RampShortReset_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)                  <= D4AAPSADCConfigReg_DP.RampShortReset_S;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ADCTestMode_S =>
				D4AAPSADCConfigReg_DN.ADCTestMode_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)               <= D4AAPSADCConfigReg_DP.ADCTestMode_S;
				
			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ROI0Enabled_S =>
				D4AAPSADCConfigReg_DN.ROI0Enabled_S <= ConfigParamInput_DI(0);
				D4AAPSADCOutput_DN(0)               <= D4AAPSADCConfigReg_DP.ROI0Enabled_S;
				
			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ROI1Enabled_S =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.ROI1Enabled_S <= ConfigParamInput_DI(0);
					D4AAPSADCOutput_DN(0)               <= D4AAPSADCConfigReg_DP.ROI1Enabled_S;
				end if;
				
			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ROI2Enabled_S =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.ROI2Enabled_S <= ConfigParamInput_DI(0);
					D4AAPSADCOutput_DN(0)               <= D4AAPSADCConfigReg_DP.ROI2Enabled_S;
				end if;
				
			when D4AAPSADCCONFIG_PARAM_ADDRESSES.ROI3Enabled_S =>
				if ENABLE_QUAD_ROI = true then
					D4AAPSADCConfigReg_DN.ROI3Enabled_S <= ConfigParamInput_DI(0);
					D4AAPSADCOutput_DN(0)               <= D4AAPSADCConfigReg_DP.ROI3Enabled_S;
				end if;

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.Transfer_D =>
				D4AAPSADCConfigReg_DN.Transfer_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.Transfer_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.Transfer_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.Transfer_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.RSFDSettle_D =>
				D4AAPSADCConfigReg_DN.RSFDSettle_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.RSFDSettle_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.RSFDSettle_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.RSFDSettle_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.GSPDReset_D =>
				D4AAPSADCConfigReg_DN.GSPDReset_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.GSPDReset_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.GSPDReset_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.GSPDReset_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.GSResetFall_D =>
				D4AAPSADCConfigReg_DN.GSResetFall_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.GSResetFall_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.GSResetFall_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.GSResetFall_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.GSTXFall_D =>
				D4AAPSADCConfigReg_DN.GSTXFall_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.GSTXFall_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.GSTXFall_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.GSTXFall_D);

			when D4AAPSADCCONFIG_PARAM_ADDRESSES.GSFDReset_D =>
				D4AAPSADCConfigReg_DN.GSFDReset_D                      <= unsigned(ConfigParamInput_DI(tD4AAPSADCConfig.GSFDReset_D'range));
				D4AAPSADCOutput_DN(tD4AAPSADCConfig.GSFDReset_D'range) <= std_logic_vector(D4AAPSADCConfigReg_DP.GSFDReset_D);

			when others => null;
		end case;
	end process apsadcIO;

	apsadcUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			D4AAPSADCOutput_DP <= (others => '0');

			D4AAPSADCConfigReg_DP <= tD4AAPSADCConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			D4AAPSADCOutput_DP <= D4AAPSADCOutput_DN;

			if LatchD4AAPSADCReg_S = '1' and ConfigLatchInput_SI = '1' then
				D4AAPSADCConfigReg_DP <= D4AAPSADCConfigReg_DN;
			end if;
		end if;
	end process apsadcUpdate;
end architecture Behavioral;
