library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.DVSAERConfigRecords.all;
use work.Settings.CHIP_DVS_SIZE_COLUMNS;
use work.Settings.CHIP_DVS_SIZE_ROWS;
use work.Settings.CHIP_DVS_ORIGIN_POINT;
use work.Settings.CHIP_DVS_AXES_INVERT;

entity DVSAERSPIConfig is
	generic(
		ENABLE_ROI_FILTERING     : boolean := false;
		ENABLE_PIXEL_FILTERING   : boolean := false;
		ENABLE_BA_REFR_FILTERING : boolean := false;
		ENABLE_TEST_GENERATOR    : boolean := false;
		ENABLE_STATISTICS        : boolean := false);
	port(
		Clock_CI                   : in  std_logic;
		Reset_RI                   : in  std_logic;

		DVSAERConfig_DO            : out tDVSAERConfig;
		DVSAERConfigInfoOut_DI     : in  tDVSAERConfigInfoOut;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI     : in  unsigned(6 downto 0);
		ConfigParamAddress_DI      : in  unsigned(7 downto 0);
		ConfigParamInput_DI        : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI        : in  std_logic;
		DVSAERConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity DVSAERSPIConfig;

architecture Behavioral of DVSAERSPIConfig is
	signal LatchDVSAERReg_S                       : std_logic;
	signal DVSAEROutput_DP, DVSAEROutput_DN       : std_logic_vector(31 downto 0);
	signal DVSAERConfigReg_DP, DVSAERConfigReg_DN : tDVSAERConfig;
begin
	DVSAERConfig_DO            <= DVSAERConfigReg_DP;
	DVSAERConfigParamOutput_DO <= DVSAEROutput_DP;

	LatchDVSAERReg_S <= '1' when ConfigModuleAddress_DI = DVSAERCONFIG_MODULE_ADDRESS else '0';

	dvsaerIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, DVSAERConfigReg_DP, DVSAERConfigInfoOut_DI)
	begin
		DVSAERConfigReg_DN <= DVSAERConfigReg_DP;
		DVSAEROutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when DVSAERCONFIG_PARAM_ADDRESSES.SizeColumns_D =>
				DVSAERConfigReg_DN.SizeColumns_D                   <= CHIP_DVS_SIZE_COLUMNS;
				DVSAEROutput_DN(tDVSAERConfig.SizeColumns_D'range) <= std_logic_vector(CHIP_DVS_SIZE_COLUMNS);

			when DVSAERCONFIG_PARAM_ADDRESSES.SizeRows_D =>
				DVSAERConfigReg_DN.SizeRows_D                   <= CHIP_DVS_SIZE_ROWS;
				DVSAEROutput_DN(tDVSAERConfig.SizeRows_D'range) <= std_logic_vector(CHIP_DVS_SIZE_ROWS);

			when DVSAERCONFIG_PARAM_ADDRESSES.OrientationInfo_D =>
				DVSAERConfigReg_DN.OrientationInfo_D                   <= CHIP_DVS_AXES_INVERT & CHIP_DVS_ORIGIN_POINT;
				DVSAEROutput_DN(tDVSAERConfig.OrientationInfo_D'range) <= CHIP_DVS_AXES_INVERT & CHIP_DVS_ORIGIN_POINT;

			when DVSAERCONFIG_PARAM_ADDRESSES.Run_S =>
				DVSAERConfigReg_DN.Run_S <= ConfigParamInput_DI(0);
				DVSAEROutput_DN(0)       <= DVSAERConfigReg_DP.Run_S;

			when DVSAERCONFIG_PARAM_ADDRESSES.AckDelayRow_D =>
				DVSAERConfigReg_DN.AckDelayRow_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.AckDelayRow_D'range));
				DVSAEROutput_DN(tDVSAERConfig.AckDelayRow_D'range) <= std_logic_vector(DVSAERConfigReg_DP.AckDelayRow_D);

			when DVSAERCONFIG_PARAM_ADDRESSES.AckDelayColumn_D =>
				DVSAERConfigReg_DN.AckDelayColumn_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.AckDelayColumn_D'range));
				DVSAEROutput_DN(tDVSAERConfig.AckDelayColumn_D'range) <= std_logic_vector(DVSAERConfigReg_DP.AckDelayColumn_D);

			when DVSAERCONFIG_PARAM_ADDRESSES.AckExtensionRow_D =>
				DVSAERConfigReg_DN.AckExtensionRow_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.AckExtensionRow_D'range));
				DVSAEROutput_DN(tDVSAERConfig.AckExtensionRow_D'range) <= std_logic_vector(DVSAERConfigReg_DP.AckExtensionRow_D);

			when DVSAERCONFIG_PARAM_ADDRESSES.AckExtensionColumn_D =>
				DVSAERConfigReg_DN.AckExtensionColumn_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.AckExtensionColumn_D'range));
				DVSAEROutput_DN(tDVSAERConfig.AckExtensionColumn_D'range) <= std_logic_vector(DVSAERConfigReg_DP.AckExtensionColumn_D);

			when DVSAERCONFIG_PARAM_ADDRESSES.WaitOnTransferStall_S =>
				DVSAERConfigReg_DN.WaitOnTransferStall_S <= ConfigParamInput_DI(0);
				DVSAEROutput_DN(0)                       <= DVSAERConfigReg_DP.WaitOnTransferStall_S;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterRowOnlyEvents_S =>
				DVSAERConfigReg_DN.FilterRowOnlyEvents_S <= ConfigParamInput_DI(0);
				DVSAEROutput_DN(0)                       <= DVSAERConfigReg_DP.FilterRowOnlyEvents_S;

			when DVSAERCONFIG_PARAM_ADDRESSES.ExternalAERControl_S =>
				DVSAERConfigReg_DN.ExternalAERControl_S <= ConfigParamInput_DI(0);
				DVSAEROutput_DN(0)                      <= DVSAERConfigReg_DP.ExternalAERControl_S;

			when DVSAERCONFIG_PARAM_ADDRESSES.HasPixelFilter_S =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.HasPixelFilter_S <= '1';
					DVSAEROutput_DN(0)                  <= '1';
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel0Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel0Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel0Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel0Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel0Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel0Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel0Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel0Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel0Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel0Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel1Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel1Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel1Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel1Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel1Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel1Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel1Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel1Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel1Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel1Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel2Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel2Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel2Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel2Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel2Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel2Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel2Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel2Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel2Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel2Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel3Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel3Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel3Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel3Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel3Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel3Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel3Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel3Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel3Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel3Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel4Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel4Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel4Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel4Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel4Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel4Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel4Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel4Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel4Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel4Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel5Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel5Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel5Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel5Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel5Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel5Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel5Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel5Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel5Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel5Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel6Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel6Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel6Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel6Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel6Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel6Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel6Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel6Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel6Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel6Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel7Row_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel7Row_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel7Row_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel7Row_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel7Row_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterPixel7Column_D =>
				if ENABLE_PIXEL_FILTERING = true then
					DVSAERConfigReg_DN.FilterPixel7Column_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterPixel7Column_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterPixel7Column_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterPixel7Column_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.HasBackgroundActivityFilter_S =>
				if ENABLE_BA_REFR_FILTERING = true then
					DVSAERConfigReg_DN.HasBackgroundActivityFilter_S <= '1';
					DVSAEROutput_DN(0)                               <= '1';
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterBackgroundActivity_S =>
				if ENABLE_BA_REFR_FILTERING = true then
					DVSAERConfigReg_DN.FilterBackgroundActivity_S <= ConfigParamInput_DI(0);
					DVSAEROutput_DN(0)                            <= DVSAERConfigReg_DP.FilterBackgroundActivity_S;
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterBackgroundActivityTime_D =>
				if ENABLE_BA_REFR_FILTERING = true then
					DVSAERConfigReg_DN.FilterBackgroundActivityTime_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterBackgroundActivityTime_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterBackgroundActivityTime_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterBackgroundActivityTime_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.HasTestEventGenerator_S =>
				if ENABLE_TEST_GENERATOR = true then
					DVSAERConfigReg_DN.HasTestEventGenerator_S <= '1';
					DVSAEROutput_DN(0)                         <= '1';
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.TestEventGeneratorEnable_S =>
				if ENABLE_TEST_GENERATOR = true then
					DVSAERConfigReg_DN.TestEventGeneratorEnable_S <= ConfigParamInput_DI(0);
					DVSAEROutput_DN(0)                            <= DVSAERConfigReg_DP.TestEventGeneratorEnable_S;
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterRefractoryPeriod_S =>
				if ENABLE_BA_REFR_FILTERING = true then
					DVSAERConfigReg_DN.FilterRefractoryPeriod_S <= ConfigParamInput_DI(0);
					DVSAEROutput_DN(0)                          <= DVSAERConfigReg_DP.FilterRefractoryPeriod_S;
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterRefractoryPeriodTime_D =>
				if ENABLE_BA_REFR_FILTERING = true then
					DVSAERConfigReg_DN.FilterRefractoryPeriodTime_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterRefractoryPeriodTime_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterRefractoryPeriodTime_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterRefractoryPeriodTime_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.HasROIFilter_S =>
				if ENABLE_ROI_FILTERING = true then
					DVSAERConfigReg_DN.HasROIFilter_S <= '1';
					DVSAEROutput_DN(0)                <= '1';
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterROIStartColumn_D =>
				if ENABLE_ROI_FILTERING = true then
					DVSAERConfigReg_DN.FilterROIStartColumn_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterROIStartColumn_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterROIStartColumn_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterROIStartColumn_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterROIStartRow_D =>
				if ENABLE_ROI_FILTERING = true then
					DVSAERConfigReg_DN.FilterROIStartRow_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterROIStartRow_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterROIStartRow_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterROIStartRow_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterROIEndColumn_D =>
				if ENABLE_ROI_FILTERING = true then
					DVSAERConfigReg_DN.FilterROIEndColumn_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterROIEndColumn_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterROIEndColumn_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterROIEndColumn_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.FilterROIEndRow_D =>
				if ENABLE_ROI_FILTERING = true then
					DVSAERConfigReg_DN.FilterROIEndRow_D                   <= unsigned(ConfigParamInput_DI(tDVSAERConfig.FilterROIEndRow_D'range));
					DVSAEROutput_DN(tDVSAERConfig.FilterROIEndRow_D'range) <= std_logic_vector(DVSAERConfigReg_DP.FilterROIEndRow_D);
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.HasStatistics_S =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(0) <= '1';
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsEventsRow64_D =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsEventsRow_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsEventsRow32_D =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(31 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsEventsRow_D(31 downto 0));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsEventsColumn64_D =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsEventsColumn_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsEventsColumn32_D =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(31 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsEventsColumn_D(31 downto 0));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsEventsDropped64_D =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsEventsDropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsEventsDropped32_D =>
				if ENABLE_STATISTICS = true then
					DVSAEROutput_DN(31 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsEventsDropped_D(31 downto 0));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsFilteredPixels64_D =>
				if ENABLE_STATISTICS = true and ENABLE_PIXEL_FILTERING = true then
					DVSAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsFilteredPixels_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsFilteredPixels32_D =>
				if ENABLE_STATISTICS = true and ENABLE_PIXEL_FILTERING = true then
					DVSAEROutput_DN(31 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsFilteredPixels_D(31 downto 0));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsFilteredBackgroundActivity64_D =>
				if ENABLE_STATISTICS = true and ENABLE_BA_REFR_FILTERING = true then
					DVSAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsFilteredBackgroundActivity_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsFilteredBackgroundActivity32_D =>
				if ENABLE_STATISTICS = true and ENABLE_BA_REFR_FILTERING = true then
					DVSAEROutput_DN(31 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsFilteredBackgroundActivity_D(31 downto 0));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsFilteredRefractoryPeriod64_D =>
				if ENABLE_STATISTICS = true and ENABLE_BA_REFR_FILTERING = true then
					DVSAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsFilteredRefractoryPeriod_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when DVSAERCONFIG_PARAM_ADDRESSES.StatisticsFilteredRefractoryPeriod32_D =>
				if ENABLE_STATISTICS = true and ENABLE_BA_REFR_FILTERING = true then
					DVSAEROutput_DN(31 downto 0) <= std_logic_vector(DVSAERConfigInfoOut_DI.StatisticsFilteredRefractoryPeriod_D(31 downto 0));
				end if;
			when others => null;
		end case;
	end process dvsaerIO;

	dvsaerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			DVSAEROutput_DP <= (others => '0');

			DVSAERConfigReg_DP <= tDVSAERConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			DVSAEROutput_DP <= DVSAEROutput_DN;

			if LatchDVSAERReg_S = '1' and ConfigLatchInput_SI = '1' then
				DVSAERConfigReg_DP <= DVSAERConfigReg_DN;
			end if;
		end if;
	end process dvsaerUpdate;
end architecture Behavioral;
