library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use ieee.math_real."**";
use work.EventCodes.all;
use work.FIFORecords.all;
use work.DVSAERConfigRecords.all;
use work.Functions.BooleanToStdLogic;
use work.ChipGeometry.AXES_KEEP;
use work.ChipGeometry.AXES_INVERT;
use work.Settings.DVS_AER_BUS_WIDTH;
use work.Settings.CHIP_DVS_ORIGIN_POINT;
use work.Settings.CHIP_DVS_AXES_INVERT;
use work.Settings.CHIP_DVS_SIZE_ROWS;
use work.Settings.CHIP_DVS_SIZE_COLUMNS;
use work.Settings.LOGIC_CLOCK_FREQ;

entity DVSAERStateMachine is
	generic(
		ENABLE_ROI_FILTERING       : boolean := false;
		ENABLE_PIXEL_FILTERING     : boolean := false;
		ENABLE_BA_REFR_FILTERING   : boolean := false;
		BA_FILTER_SUBSAMPLE_COLUMN : integer := 2;
		BA_FILTER_SUBSAMPLE_ROW    : integer := 2;
		ENABLE_TEST_GENERATOR      : boolean := false;
		ENABLE_STATISTICS          : boolean := false);
	port(
		Clock_CI               : in  std_logic;
		Reset_RI               : in  std_logic;

		-- Fifo output (to Multiplexer)
		OutFifoControl_SI      : in  tFromFifoWriteSide;
		OutFifoControl_SO      : out tToFifoWriteSide;
		OutFifoData_DO         : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		DVSAERData_DI          : in  std_logic_vector(DVS_AER_BUS_WIDTH - 1 downto 0);
		DVSAERReq_SBI          : in  std_logic;
		DVSAERAck_SBO          : out std_logic;
		DVSAERReset_SBO        : out std_logic;

		-- Configuration input and output
		DVSAERConfig_DI        : in  tDVSAERConfig;
		DVSAERConfigInfoOut_DO : out tDVSAERConfigInfoOut);
end DVSAERStateMachine;

architecture Behavioral of DVSAERStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stDifferentiateRowCol, stAERHandleRow, stAERAckRow, stAERHandleCol, stAERAckCol, stFIFOFull);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- present and next state
	signal State_DP, State_DN : tState;

	-- Counter to influence acknowledge delays.
	signal AckCount_S, AckDone_S : std_logic;
	signal AckLimit_D            : unsigned(DVS_AER_ACK_COUNTER_WIDTH - 1 downto 0);

	-- Bits needed for each address.
	constant DVS_ROW_ADDRESS_WIDTH    : integer := integer(ceil(log2(real(to_integer(CHIP_DVS_SIZE_ROWS)))));
	constant DVS_COLUMN_ADDRESS_WIDTH : integer := integer(ceil(log2(real(to_integer(CHIP_DVS_SIZE_COLUMNS)))));

	-- Data incoming from DVS.
	signal DVSEventDataReg_D       : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal DVSEventValidReg_S      : std_logic;
	signal DVSEventOutDataReg_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal DVSEventOutValidReg_S   : std_logic;

	-- Register outputs to DVS.
	signal DVSAERAckReg_SB   : std_logic;
	signal DVSAERResetReg_SB : std_logic;

	-- Register configuration input and output.
	signal DVSAERConfigReg_D : tDVSAERConfig;

	-- ROI filtering support.
	signal ROIFilterInDataReg_D   : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal ROIFilterInValidReg_S  : std_logic;
	signal ROIFilterOutDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal ROIFilterOutValidReg_S : std_logic;

	-- Pixel filtering support.
	signal PixelFilterInDataReg_D   : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal PixelFilterInValidReg_S  : std_logic;
	signal PixelFilterOutDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal PixelFilterOutValidReg_S : std_logic;

	-- Background Activity filtering support.
	signal BARefrFilterInDataReg_D   : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal BARefrFilterInValidReg_S  : std_logic;
	signal BARefrFilterOutDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal BARefrFilterOutValidReg_S : std_logic;

	-- Row Only filtering support (at end to catch all the row-only events that
	-- are generated from the other filters due to dropping column events).
	signal RowOnlyFilterInDataReg_D   : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal RowOnlyFilterInValidReg_S  : std_logic;
	signal RowOnlyFilterOutDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal RowOnlyFilterOutValidReg_S : std_logic;
	signal RowOnlyFilterPassRow_S     : std_logic;

	-- Test Event Generator support (generates fake sequential addresses).
	signal TestDVSEventDataReg_D       : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal TestDVSEventValidReg_S      : std_logic;

	-- Statistics support.
	signal StatisticsEventsRow_SP, StatisticsEventsRow_SN                                   : std_logic;
	signal StatisticsEventsColumn_SP, StatisticsEventsColumn_SN                             : std_logic;
	signal StatisticsEventsDropped_SP, StatisticsEventsDropped_SN                           : std_logic;
	signal StatisticsFilteredPixels_SP, StatisticsFilteredPixels_SN                         : std_logic;
	signal StatisticsFilteredBackgroundActivity_SP, StatisticsFilteredBackgroundActivity_SN : std_logic;
	signal StatisticsFilteredRefractoryPeriod_SP, StatisticsFilteredRefractoryPeriod_SN     : std_logic;
begin
	aerAckCounter : entity work.ContinuousCounter
		generic map(
			SIZE => DVS_AER_ACK_COUNTER_WIDTH)
		port map(Clock_CI     => Clock_CI,
		         Reset_RI     => Reset_RI,
		         Clear_SI     => '0',
		         Enable_SI    => AckCount_S,
		         DataLimit_DI => AckLimit_D,
		         Overflow_SO  => AckDone_S,
		         Data_DO      => open);

	dvsHandleAERComb : process(State_DP, OutFifoControl_SI, DVSAERReq_SBI, DVSAERData_DI, DVSAERConfigReg_D, AckDone_S)
	begin
		State_DN <= State_DP;           -- Keep current state by default.

		DVSEventValidReg_S      <= '0';
		DVSEventDataReg_D       <= (others => '0');

		DVSAERAckReg_SB   <= '1';       -- No AER ACK by default.
		DVSAERResetReg_SB <= '1';       -- Keep DVS out of reset by default, so we don't have to repeat this in every state.

		AckCount_S <= '0';
		AckLimit_D <= (others => '1');

		StatisticsEventsRow_SN     <= '0';
		StatisticsEventsColumn_SN  <= '0';
		StatisticsEventsDropped_SN <= '0';

		case State_DP is
			when stIdle =>
				-- Only exit idle state if DVS data producer is active.
				if DVSAERConfigReg_D.Run_S = '1' then
					if DVSAERReq_SBI = '0' then
						if OutFifoControl_SI.AlmostFull_S = '0' then
							-- Got a request on the AER bus, let's get the data.
							-- We do have space in the output FIFO for it.
							State_DN <= stDifferentiateRowCol;
						elsif DVSAERConfigReg_D.WaitOnTransferStall_S = '0' then
							-- FIFO full, keep ACKing.
							State_DN <= stFIFOFull;

							StatisticsEventsDropped_SN <= '1';
						end if;
					end if;
				else
					if DVSAERConfigReg_D.ExternalAERControl_S = '1' then
						-- Support handing off control of AER to external systems connected through the CAVIAR
						-- connector on the board. This ensures the chip is kept out of reset and the ACK is
						-- not driven from our logic.
						DVSAERAckReg_SB   <= 'Z';
						DVSAERResetReg_SB <= '1';
					else
						-- Keep the DVS in reset if data producer turned off.
						DVSAERResetReg_SB <= '0';
					end if;
				end if;

			when stFIFOFull =>
				-- Output FIFO is full, just ACK the data, so that, when
				-- we'll have space in the FIFO again, the newest piece of
				-- data is the next to be inserted, and not stale old data.
				DVSAERAckReg_SB <= DVSAERReq_SBI;

				-- Only go back to idle when FIFO has space again, and when
				-- the sender is not requesting (to avoid AER races).
				if OutFifoControl_SI.AlmostFull_S = '0' and DVSAERReq_SBI = '1' then
					State_DN <= stIdle;
				end if;

			when stDifferentiateRowCol =>
				-- Get data and format it. AER(WIDTH-1) holds the axis.
				if DVSAERData_DI(DVS_AER_BUS_WIDTH - 1) = '0' then
					-- This is an Y address.
					State_DN <= stAERHandleRow;
				else
					State_DN <= stAERHandleCol;
				end if;

			when stAERHandleRow =>
				AckLimit_D <= DVSAERConfigReg_D.AckDelayRow_D;

				-- We might need to delay the ACK.
				if AckDone_S = '1' then
					-- Row address (Y).
					DVSEventDataReg_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) <= EVENT_CODE_Y_ADDR;

					if CHIP_DVS_ORIGIN_POINT(0) = '1' then
						DVSEventDataReg_D(DVS_ROW_ADDRESS_WIDTH - 1 downto 0) <= std_logic_vector(resize(CHIP_DVS_SIZE_ROWS - 1, DVS_ROW_ADDRESS_WIDTH) - unsigned(DVSAERData_DI(DVS_ROW_ADDRESS_WIDTH - 1 downto 0)));
					else
						DVSEventDataReg_D(DVS_ROW_ADDRESS_WIDTH - 1 downto 0) <= DVSAERData_DI(DVS_ROW_ADDRESS_WIDTH - 1 downto 0);
					end if;

					DVSEventValidReg_S <= '1';

					StatisticsEventsRow_SN <= '1';

					DVSAERAckReg_SB <= '0';
					State_DN        <= stAERAckRow;
				end if;

				AckCount_S <= '1';

			when stAERAckRow =>
				AckLimit_D <= DVSAERConfigReg_D.AckExtensionRow_D;

				DVSAERAckReg_SB <= '0';

				if DVSAERReq_SBI = '1' then
					-- We might need to extend the ACK period.
					if AckDone_S = '1' then
						DVSAERAckReg_SB <= '1';
						State_DN        <= stIdle;
					end if;

					AckCount_S <= '1';
				end if;

			when stAERHandleCol =>
				AckLimit_D <= DVSAERConfigReg_D.AckDelayColumn_D;

				-- We might need to delay the ACK.
				if AckDone_S = '1' then
					-- Column address (X).
					DVSEventDataReg_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) <= EVENT_CODE_X_ADDR & DVSAERData_DI(0);

					if CHIP_DVS_ORIGIN_POINT(1) = '1' then
						DVSEventDataReg_D(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0) <= std_logic_vector(resize(CHIP_DVS_SIZE_COLUMNS - 1, DVS_COLUMN_ADDRESS_WIDTH) - unsigned(DVSAERData_DI(DVS_COLUMN_ADDRESS_WIDTH downto 1)));
					else
						DVSEventDataReg_D(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0) <= DVSAERData_DI(DVS_COLUMN_ADDRESS_WIDTH downto 1);
					end if;

					DVSEventValidReg_S <= '1';

					StatisticsEventsColumn_SN <= '1';

					DVSAERAckReg_SB <= '0';
					State_DN        <= stAERAckCol;
				end if;

				AckCount_S <= '1';

			when stAERAckCol =>
				AckLimit_D <= DVSAERConfigReg_D.AckExtensionColumn_D;

				DVSAERAckReg_SB <= '0';

				if DVSAERReq_SBI = '1' then
					-- We might need to extend the ACK period.
					if AckDone_S = '1' then
						DVSAERAckReg_SB <= '1';
						State_DN        <= stIdle;
					end if;

					AckCount_S <= '1';
				end if;

			when others => null;
		end case;
	end process dvsHandleAERComb;

	-- Change state on clock edge (synchronous).
	dvsHandleAERRegisterUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			State_DP <= stIdle;

			DVSAERAck_SBO   <= '1';
			DVSAERReset_SBO <= '0';

			DVSAERConfigReg_D <= tDVSAERConfigDefault;
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;

			DVSAERAck_SBO   <= DVSAERAckReg_SB;
			DVSAERReset_SBO <= DVSAERResetReg_SB;

			DVSAERConfigReg_D <= DVSAERConfig_DI;
		end if;
	end process dvsHandleAERRegisterUpdate;

	testGeneratorProcesses : if ENABLE_TEST_GENERATOR = true generate
		attribute syn_enum_encoding : string;

		type tTestState is (stIdle, stTestGenerateAddressRow, stTestGenerateAddressColOn, stTestGenerateAddressColOff);
		attribute syn_enum_encoding of tTestState : type is "onehot";

		-- present and next state
		signal TestState_DP, TestState_DN : tTestState;

		-- Test Event Generator support (generates fake sequential addresses).
		signal TestGeneratorRowCount_S    : std_logic;
		signal TestGeneratorRowDone_S     : std_logic;
		signal TestGeneratorRow_D         : unsigned(DVS_ROW_ADDRESS_WIDTH - 1 downto 0);
		signal TestGeneratorColumnCount_S : std_logic;
		signal TestGeneratorColumnDone_S  : std_logic;
		signal TestGeneratorColumn_D      : unsigned(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0);
	begin
		dvsTestGeneratorComb : process(TestState_DP, OutFifoControl_SI, DVSAERConfigReg_D, TestGeneratorColumnDone_S, TestGeneratorColumn_D, TestGeneratorRowDone_S, TestGeneratorRow_D)
		begin
			TestState_DN <= TestState_DP; -- Keep current state by default.

			-- Test Event Generator always disabled in normal operation.
			TestGeneratorRowCount_S    <= '0';
			TestGeneratorColumnCount_S <= '0';

			TestDVSEventValidReg_S      <= '0';
			TestDVSEventDataReg_D       <= (others => '0');

			case TestState_DP is
				when stIdle =>
					-- If requested, produce fake events that sequentially span the whole array size.
					if DVSAERConfigReg_D.TestEventGeneratorEnable_S = '1' and DVSAERConfigReg_D.Run_S = '0' and DVSAERConfigReg_D.ExternalAERControl_S = '0' then
						-- Inject fake address.
						TestState_DN <= stTestGenerateAddressRow;
					end if;

				when stTestGenerateAddressRow =>
					if OutFifoControl_SI.AlmostFull_S = '0' then
						-- Send out fake row address (Y).
						TestDVSEventDataReg_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) <= EVENT_CODE_Y_ADDR;
						TestDVSEventDataReg_D(DVS_ROW_ADDRESS_WIDTH - 1 downto 0)     <= std_logic_vector(TestGeneratorRow_D);
						TestDVSEventValidReg_S                                        <= '1';

						-- Increase row count for next pass.
						TestGeneratorRowCount_S <= '1';

						if TestGeneratorRowDone_S = '1' then
							-- Once done, go back to Idle state.
							TestState_DN <= stIdle;

							-- Don't forward at this point due to maximum address reached.
							TestDVSEventValidReg_S <= '0';
						else
							-- Go to send all columns for this row.
							TestState_DN <= stTestGenerateAddressColOn;
						end if;
					end if;

				when stTestGenerateAddressColOn =>
					if OutFifoControl_SI.AlmostFull_S = '0' then
						-- Send out fake column address (X) with ON polarity.
						TestDVSEventDataReg_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) <= EVENT_CODE_X_ADDR_POL_ON;
						TestDVSEventDataReg_D(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0)  <= std_logic_vector(TestGeneratorColumn_D);
						TestDVSEventValidReg_S                                        <= '1';

						-- Increase column count for next pass.
						TestGeneratorColumnCount_S <= '1';

						-- Send next column ON value, or when maximum reached, go and send OFF events for all columns.
						if TestGeneratorColumnDone_S = '1' then
							TestState_DN <= stTestGenerateAddressColOff;
						else
							TestState_DN <= stTestGenerateAddressColOn;
						end if;
					end if;

				when stTestGenerateAddressColOff =>
					if OutFifoControl_SI.AlmostFull_S = '0' then
						-- Send out fake column address (X) with OFF polarity.
						TestDVSEventDataReg_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) <= EVENT_CODE_X_ADDR_POL_OFF;
						TestDVSEventDataReg_D(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0)  <= std_logic_vector(TestGeneratorColumn_D);
						TestDVSEventValidReg_S                                        <= '1';

						-- Increase column count for next pass.
						TestGeneratorColumnCount_S <= '1';

						-- Send next column OFF value, or when maximum reached, go to next row.
						if TestGeneratorColumnDone_S = '1' then
							TestState_DN <= stTestGenerateAddressRow;
						else
							TestState_DN <= stTestGenerateAddressColOff;
						end if;
					end if;

				when others => null;
			end case;
		end process dvsTestGeneratorComb;

		-- Change state on clock edge (synchronous).
		dvsTestGeneratorRegisterUpdate : process(Clock_CI, Reset_RI)
		begin
			if Reset_RI = '1' then      -- asynchronous reset (active-high for FPGAs)
				TestState_DP <= stIdle;
			elsif rising_edge(Clock_CI) then
				TestState_DP <= TestState_DN;
			end if;
		end process dvsTestGeneratorRegisterUpdate;

		testGeneratorRowCounter : entity work.ContinuousCounter
			generic map(
				SIZE => CHIP_DVS_SIZE_ROWS'length)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Clear_SI     => '0',
				Enable_SI    => TestGeneratorRowCount_S,
				DataLimit_DI => CHIP_DVS_SIZE_ROWS,
				Overflow_SO  => TestGeneratorRowDone_S,
				Data_DO      => TestGeneratorRow_D);

		testGeneratorColumnCounter : entity work.ContinuousCounter
			generic map(
				SIZE => DVS_COLUMN_ADDRESS_WIDTH)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Clear_SI     => '0',
				Enable_SI    => TestGeneratorColumnCount_S,
				DataLimit_DI => CHIP_DVS_SIZE_COLUMNS - 1,
				Overflow_SO  => TestGeneratorColumnDone_S,
				Data_DO      => TestGeneratorColumn_D);
	end generate testGeneratorProcesses;

	testGeneratorDisabled : if ENABLE_TEST_GENERATOR = false generate
	begin
		TestDVSEventValidReg_S      <= '0';
		TestDVSEventDataReg_D       <= (others => '0');
	end generate testGeneratorDisabled;

	dvsEventDataRegister : entity work.SimpleRegister
		generic map(
			SIZE => EVENT_WIDTH)
		port map(
			Clock_CI                            => Clock_CI,
			Reset_RI                            => Reset_RI,
			Enable_SI                           => DVSEventValidReg_S or TestDVSEventValidReg_S,
			Input_SI(EVENT_WIDTH - 1 downto 0)  => DVSEventDataReg_D or TestDVSEventDataReg_D,
			Output_SO(EVENT_WIDTH - 1 downto 0) => DVSEventOutDataReg_D);

	dvsEventValidRegister : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => DVSEventValidReg_S or TestDVSEventValidReg_S,
			Output_SO(0) => DVSEventOutValidReg_S);

	roiFilterSupportDisabled : if ENABLE_ROI_FILTERING = false generate
	begin
		ROIFilterInDataReg_D  <= DVSEventOutDataReg_D;
		ROIFilterInValidReg_S <= DVSEventOutValidReg_S;

		ROIFilterOutDataReg_D  <= ROIFilterInDataReg_D;
		ROIFilterOutValidReg_S <= ROIFilterInValidReg_S;
	end generate roiFilterSupportDisabled;

	roiFilterSupportEnabled : if ENABLE_ROI_FILTERING = true generate
		signal LastRowAddress_DP, LastRowAddress_DN : unsigned(DVS_ROW_ADDRESS_WIDTH - 1 downto 0);

		signal FilterROIStartColumn_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterROIStartRow_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterROIEndColumn_D   : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterROIEndRow_D      : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
	begin
		roiFilterLastRowAddressRegister : entity work.SimpleRegister
			generic map(
				SIZE => DVS_ROW_ADDRESS_WIDTH)
			port map(
				Clock_CI            => Clock_CI,
				Reset_RI            => Reset_RI,
				Enable_SI           => '1',
				Input_SI            => std_logic_vector(LastRowAddress_DN),
				unsigned(Output_SO) => LastRowAddress_DP);

		axesNormal : if CHIP_DVS_AXES_INVERT = AXES_KEEP generate
		begin
			FilterROIStartColumn_D <= resize(DVSAERConfigReg_D.FilterROIStartColumn_D, EVENT_DATA_WIDTH_MAX);
			FilterROIStartRow_D    <= resize(DVSAERConfigReg_D.FilterROIStartRow_D, EVENT_DATA_WIDTH_MAX);
			FilterROIEndColumn_D   <= resize(DVSAERConfigReg_D.FilterROIEndColumn_D, EVENT_DATA_WIDTH_MAX);
			FilterROIEndRow_D      <= resize(DVSAERConfigReg_D.FilterROIEndRow_D, EVENT_DATA_WIDTH_MAX);
		end generate axesNormal;

		axesInverted : if CHIP_DVS_AXES_INVERT = AXES_INVERT generate
		begin
			FilterROIStartColumn_D <= resize(DVSAERConfigReg_D.FilterROIStartRow_D, EVENT_DATA_WIDTH_MAX);
			FilterROIStartRow_D    <= resize(DVSAERConfigReg_D.FilterROIStartColumn_D, EVENT_DATA_WIDTH_MAX);
			FilterROIEndColumn_D   <= resize(DVSAERConfigReg_D.FilterROIEndRow_D, EVENT_DATA_WIDTH_MAX);
			FilterROIEndRow_D      <= resize(DVSAERConfigReg_D.FilterROIEndColumn_D, EVENT_DATA_WIDTH_MAX);
		end generate axesInverted;

		roiFilter : process(DVSEventOutDataReg_D, DVSEventOutValidReg_S, LastRowAddress_DP, FilterROIEndColumn_D, FilterROIEndRow_D, FilterROIStartColumn_D, FilterROIStartRow_D)
			variable ColumnAddress_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0) := (others => '0');
			variable RowAddress_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0) := (others => '0');

			variable ColumnValid_S    : boolean := false;
			variable RowValid_S       : boolean := false;
			variable ROIFilterValid_S : boolean := false;
		begin
			ROIFilterInDataReg_D  <= DVSEventOutDataReg_D;
			ROIFilterInValidReg_S <= DVSEventOutValidReg_S;

			LastRowAddress_DN <= LastRowAddress_DP;

			ColumnAddress_D := resize(unsigned(DVSEventOutDataReg_D(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0)), EVENT_DATA_WIDTH_MAX);
			RowAddress_D    := resize(LastRowAddress_DP, EVENT_DATA_WIDTH_MAX);

			ColumnValid_S := ColumnAddress_D >= FilterROIStartColumn_D and ColumnAddress_D <= FilterROIEndColumn_D;
			RowValid_S    := RowAddress_D >= FilterROIStartRow_D and RowAddress_D <= FilterROIEndRow_D;

			ROIFilterValid_S := ColumnValid_S and RowValid_S;

			if DVSEventOutValidReg_S = '1' then
				if DVSEventOutDataReg_D(EVENT_WIDTH - 2) = '0' then
					-- This is a row address, we just save it.
					LastRowAddress_DN <= unsigned(DVSEventOutDataReg_D(DVS_ROW_ADDRESS_WIDTH - 1 downto 0));
				else
					-- This is a column address, we use the full comparison at this point.
					-- If it matches any of the pixels that should be filtered, we set the column
					-- address to be invalid.
					ROIFilterInValidReg_S <= BooleanToStdLogic(ROIFilterValid_S);
				end if;
			end if;
		end process roiFilter;

		roiFilterDataRegister : entity work.SimpleRegister
			generic map(
				SIZE => EVENT_WIDTH)
			port map(
				Clock_CI  => Clock_CI,
				Reset_RI  => Reset_RI,
				Enable_SI => ROIFilterInValidReg_S,
				Input_SI  => ROIFilterInDataReg_D,
				Output_SO => ROIFilterOutDataReg_D);

		roiFilterValidRegister : entity work.SimpleRegister
			generic map(
				SIZE => 1)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => ROIFilterInValidReg_S,
				Output_SO(0) => ROIFilterOutValidReg_S);
	end generate roiFilterSupportEnabled;

	pixelFilterSupportDisabled : if ENABLE_PIXEL_FILTERING = false generate
	begin
		PixelFilterInDataReg_D  <= ROIFilterOutDataReg_D;
		PixelFilterInValidReg_S <= ROIFilterOutValidReg_S;

		PixelFilterOutDataReg_D  <= PixelFilterInDataReg_D;
		PixelFilterOutValidReg_S <= PixelFilterInValidReg_S;
	end generate pixelFilterSupportDisabled;

	pixelFilterSupportEnabled : if ENABLE_PIXEL_FILTERING = true generate
		signal LastRowAddress_DP, LastRowAddress_DN : unsigned(DVS_ROW_ADDRESS_WIDTH - 1 downto 0);

		signal FilterPixel0Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel0Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel1Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel1Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel2Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel2Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel3Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel3Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel4Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel4Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel5Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel5Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel6Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel6Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel7Row_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
		signal FilterPixel7Column_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0);
	begin
		pixelFilterLastRowAddressRegister : entity work.SimpleRegister
			generic map(
				SIZE => DVS_ROW_ADDRESS_WIDTH)
			port map(
				Clock_CI            => Clock_CI,
				Reset_RI            => Reset_RI,
				Enable_SI           => '1',
				Input_SI            => std_logic_vector(LastRowAddress_DN),
				unsigned(Output_SO) => LastRowAddress_DP);

		axesNormal : if CHIP_DVS_AXES_INVERT = AXES_KEEP generate
		begin
			FilterPixel0Row_D    <= resize(DVSAERConfigReg_D.FilterPixel0Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel0Column_D <= resize(DVSAERConfigReg_D.FilterPixel0Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel1Row_D    <= resize(DVSAERConfigReg_D.FilterPixel1Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel1Column_D <= resize(DVSAERConfigReg_D.FilterPixel1Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel2Row_D    <= resize(DVSAERConfigReg_D.FilterPixel2Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel2Column_D <= resize(DVSAERConfigReg_D.FilterPixel2Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel3Row_D    <= resize(DVSAERConfigReg_D.FilterPixel3Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel3Column_D <= resize(DVSAERConfigReg_D.FilterPixel3Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel4Row_D    <= resize(DVSAERConfigReg_D.FilterPixel4Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel4Column_D <= resize(DVSAERConfigReg_D.FilterPixel4Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel5Row_D    <= resize(DVSAERConfigReg_D.FilterPixel5Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel5Column_D <= resize(DVSAERConfigReg_D.FilterPixel5Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel6Row_D    <= resize(DVSAERConfigReg_D.FilterPixel6Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel6Column_D <= resize(DVSAERConfigReg_D.FilterPixel6Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel7Row_D    <= resize(DVSAERConfigReg_D.FilterPixel7Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel7Column_D <= resize(DVSAERConfigReg_D.FilterPixel7Column_D, EVENT_DATA_WIDTH_MAX);
		end generate axesNormal;

		axesInverted : if CHIP_DVS_AXES_INVERT = AXES_INVERT generate
		begin
			FilterPixel0Row_D    <= resize(DVSAERConfigReg_D.FilterPixel0Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel0Column_D <= resize(DVSAERConfigReg_D.FilterPixel0Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel1Row_D    <= resize(DVSAERConfigReg_D.FilterPixel1Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel1Column_D <= resize(DVSAERConfigReg_D.FilterPixel1Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel2Row_D    <= resize(DVSAERConfigReg_D.FilterPixel2Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel2Column_D <= resize(DVSAERConfigReg_D.FilterPixel2Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel3Row_D    <= resize(DVSAERConfigReg_D.FilterPixel3Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel3Column_D <= resize(DVSAERConfigReg_D.FilterPixel3Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel4Row_D    <= resize(DVSAERConfigReg_D.FilterPixel4Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel4Column_D <= resize(DVSAERConfigReg_D.FilterPixel4Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel5Row_D    <= resize(DVSAERConfigReg_D.FilterPixel5Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel5Column_D <= resize(DVSAERConfigReg_D.FilterPixel5Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel6Row_D    <= resize(DVSAERConfigReg_D.FilterPixel6Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel6Column_D <= resize(DVSAERConfigReg_D.FilterPixel6Row_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel7Row_D    <= resize(DVSAERConfigReg_D.FilterPixel7Column_D, EVENT_DATA_WIDTH_MAX);
			FilterPixel7Column_D <= resize(DVSAERConfigReg_D.FilterPixel7Row_D, EVENT_DATA_WIDTH_MAX);
		end generate axesInverted;

		pixelFilter : process(ROIFilterOutDataReg_D, ROIFilterOutValidReg_S, LastRowAddress_DP, FilterPixel0Column_D, FilterPixel0Row_D, FilterPixel1Column_D, FilterPixel1Row_D, FilterPixel2Column_D, FilterPixel2Row_D, FilterPixel3Column_D, FilterPixel3Row_D, FilterPixel4Column_D, FilterPixel4Row_D, FilterPixel5Column_D, FilterPixel5Row_D, FilterPixel6Column_D, FilterPixel6Row_D, FilterPixel7Column_D, FilterPixel7Row_D)
			variable ColumnAddress_D : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0) := (others => '0');
			variable RowAddress_D    : unsigned(EVENT_DATA_WIDTH_MAX - 1 downto 0) := (others => '0');

			variable Pixel0Hit_S : boolean := false;
			variable Pixel1Hit_S : boolean := false;
			variable Pixel2Hit_S : boolean := false;
			variable Pixel3Hit_S : boolean := false;
			variable Pixel4Hit_S : boolean := false;
			variable Pixel5Hit_S : boolean := false;
			variable Pixel6Hit_S : boolean := false;
			variable Pixel7Hit_S : boolean := false;

			variable PixelFilterInvalid_S : boolean := false;
		begin
			PixelFilterInDataReg_D  <= ROIFilterOutDataReg_D;
			PixelFilterInValidReg_S <= ROIFilterOutValidReg_S;

			LastRowAddress_DN <= LastRowAddress_DP;

			StatisticsFilteredPixels_SN <= '0';

			ColumnAddress_D := resize(unsigned(ROIFilterOutDataReg_D(DVS_COLUMN_ADDRESS_WIDTH - 1 downto 0)), EVENT_DATA_WIDTH_MAX);
			RowAddress_D    := resize(LastRowAddress_DP, EVENT_DATA_WIDTH_MAX);

			Pixel0Hit_S := RowAddress_D = FilterPixel0Row_D and ColumnAddress_D = FilterPixel0Column_D;
			Pixel1Hit_S := RowAddress_D = FilterPixel1Row_D and ColumnAddress_D = FilterPixel1Column_D;
			Pixel2Hit_S := RowAddress_D = FilterPixel2Row_D and ColumnAddress_D = FilterPixel2Column_D;
			Pixel3Hit_S := RowAddress_D = FilterPixel3Row_D and ColumnAddress_D = FilterPixel3Column_D;
			Pixel4Hit_S := RowAddress_D = FilterPixel4Row_D and ColumnAddress_D = FilterPixel4Column_D;
			Pixel5Hit_S := RowAddress_D = FilterPixel5Row_D and ColumnAddress_D = FilterPixel5Column_D;
			Pixel6Hit_S := RowAddress_D = FilterPixel6Row_D and ColumnAddress_D = FilterPixel6Column_D;
			Pixel7Hit_S := RowAddress_D = FilterPixel7Row_D and ColumnAddress_D = FilterPixel7Column_D;

			PixelFilterInvalid_S := Pixel0Hit_S or Pixel1Hit_S or Pixel2Hit_S or Pixel3Hit_S or Pixel4Hit_S or Pixel5Hit_S or Pixel6Hit_S or Pixel7Hit_S;

			if ROIFilterOutValidReg_S = '1' then
				if ROIFilterOutDataReg_D(EVENT_WIDTH - 2) = '0' then
					-- This is a row address, we just save it.
					LastRowAddress_DN <= unsigned(ROIFilterOutDataReg_D(DVS_ROW_ADDRESS_WIDTH - 1 downto 0));
				else
					-- This is a column address, we use the full comparison at this point.
					-- If it matches any of the pixels that should be filtered, we set the column
					-- address to be invalid.
					PixelFilterInValidReg_S <= BooleanToStdLogic(not PixelFilterInvalid_S);

					StatisticsFilteredPixels_SN <= BooleanToStdLogic(PixelFilterInvalid_S);
				end if;
			end if;
		end process pixelFilter;

		pixelFilterDataRegister : entity work.SimpleRegister
			generic map(
				SIZE => EVENT_WIDTH)
			port map(
				Clock_CI  => Clock_CI,
				Reset_RI  => Reset_RI,
				Enable_SI => PixelFilterInValidReg_S,
				Input_SI  => PixelFilterInDataReg_D,
				Output_SO => PixelFilterOutDataReg_D);

		pixelFilterValidRegister : entity work.SimpleRegister
			generic map(
				SIZE => 1)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => PixelFilterInValidReg_S,
				Output_SO(0) => PixelFilterOutValidReg_S);
	end generate pixelFilterSupportEnabled;

	baRefrFilterSupportDisabled : if ENABLE_BA_REFR_FILTERING = false generate
	begin
		BARefrFilterInDataReg_D  <= PixelFilterOutDataReg_D;
		BARefrFilterInValidReg_S <= PixelFilterOutValidReg_S;

		BARefrFilterOutDataReg_D  <= BARefrFilterInDataReg_D;
		BARefrFilterOutValidReg_S <= BARefrFilterInValidReg_S;
	end generate baRefrFilterSupportDisabled;

	baRefrFilterSupportEnabled : if ENABLE_BA_REFR_FILTERING = true generate
		baFilter : entity work.DVSBAFilterStateMachine
			generic map(
				BA_FILTER_SUBSAMPLE_COLUMN => BA_FILTER_SUBSAMPLE_COLUMN,
				BA_FILTER_SUBSAMPLE_ROW    => BA_FILTER_SUBSAMPLE_ROW)
			port map(
				Clock_CI                                => Clock_CI,
				Reset_RI                                => Reset_RI,
				FilterBackgroundActivity_SI             => DVSAERConfigReg_D.FilterBackgroundActivity_S,
				FilterBackgroundActivityTime_DI         => DVSAERConfigReg_D.FilterBackgroundActivityTime_D,
				FilterRefractoryPeriod_SI               => DVSAERConfigReg_D.FilterRefractoryPeriod_S,
				FilterRefractoryPeriodTime_DI           => DVSAERConfigReg_D.FilterRefractoryPeriodTime_D,
				StatisticsFilteredBackgroundActivity_SO => StatisticsFilteredBackgroundActivity_SN,
				StatisticsFilteredRefractoryPeriod_SO   => StatisticsFilteredRefractoryPeriod_SN,
				BAFilterInputData_DI                    => PixelFilterOutDataReg_D,
				BAFilterInputValid_SI                   => PixelFilterOutValidReg_S,
				BAFilterOutputData_DO                   => BARefrFilterInDataReg_D,
				BAFilterOutputValid_SO                  => BARefrFilterInValidReg_S);

		baFilterDataRegister : entity work.SimpleRegister
			generic map(
				SIZE => EVENT_WIDTH)
			port map(
				Clock_CI  => Clock_CI,
				Reset_RI  => Reset_RI,
				Enable_SI => BARefrFilterInValidReg_S,
				Input_SI  => BARefrFilterInDataReg_D,
				Output_SO => BARefrFilterOutDataReg_D);

		baFilterValidRegister : entity work.SimpleRegister
			generic map(
				SIZE => 1)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => BARefrFilterInValidReg_S,
				Output_SO(0) => BARefrFilterOutValidReg_S);
	end generate baRefrFilterSupportEnabled;

	rowOnlyFilter : process(BARefrFilterOutDataReg_D, BARefrFilterOutValidReg_S, DVSAERConfigReg_D, RowOnlyFilterOutDataReg_D)
	begin
		RowOnlyFilterInDataReg_D  <= BARefrFilterOutDataReg_D;
		RowOnlyFilterInValidReg_S <= BARefrFilterOutValidReg_S;

		-- Bypass register and control FIFO directly.
		RowOnlyFilterPassRow_S <= '0';

		if DVSAERConfigReg_D.FilterRowOnlyEvents_S = '1' and BARefrFilterOutValidReg_S = '1' then
			if BARefrFilterOutDataReg_D(EVENT_WIDTH - 2) = '0' then
				-- This is a row address, we force it to be invalid, so that it is not automatically
				-- forwarded to the FIFO. We'll forward it later when encountering a column address.
				RowOnlyFilterInValidReg_S <= '0';
			else
				-- Column address, we pass the previously stored row to FIFO at this point.
				-- But only if the previously stored value was indeed a row, to avoid also
				-- sending column addresses twice.
				-- The column address will go to the register and be forwarded as usual one
				-- cycle later, due to being a valid event.
				if RowOnlyFilterOutDataReg_D(EVENT_WIDTH - 2) = '0' then
					RowOnlyFilterPassRow_S <= '1';
				end if;
			end if;
		end if;
	end process rowOnlyFilter;

	rowOnlyFilterDataRegister : entity work.SimpleRegister
		generic map(
			SIZE => EVENT_WIDTH)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Enable_SI => '1',
			Input_SI  => RowOnlyFilterInDataReg_D,
			Output_SO => RowOnlyFilterOutDataReg_D);

	rowOnlyFilterValidRegister : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => RowOnlyFilterInValidReg_S,
			Output_SO(0) => RowOnlyFilterOutValidReg_S);

	OutFifoData_DO            <= RowOnlyFilterOutDataReg_D;
	OutFifoControl_SO.Write_S <= RowOnlyFilterOutValidReg_S or RowOnlyFilterPassRow_S;

	statisticsSupport : if ENABLE_STATISTICS = true generate
		StatisticsEventsRowReg : entity work.SimpleRegister
			generic map(
				SIZE => 1)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => StatisticsEventsRow_SN,
				Output_SO(0) => StatisticsEventsRow_SP);

		StatisticsEventsRowCounter : entity work.Counter
			generic map(
				SIZE => TRANSACTION_COUNTER_WIDTH)
			port map(
				Clock_CI  => Clock_CI,
				Reset_RI  => Reset_RI,
				Clear_SI  => not DVSAERConfigReg_D.Run_S,
				Enable_SI => StatisticsEventsRow_SP,
				Data_DO   => DVSAERConfigInfoOut_DO.StatisticsEventsRow_D);

		StatisticsEventsColumnReg : entity work.SimpleRegister
			generic map(
				SIZE => 1)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => StatisticsEventsColumn_SN,
				Output_SO(0) => StatisticsEventsColumn_SP);

		StatisticsEventsColumnCounter : entity work.Counter
			generic map(
				SIZE => TRANSACTION_COUNTER_WIDTH)
			port map(
				Clock_CI  => Clock_CI,
				Reset_RI  => Reset_RI,
				Clear_SI  => not DVSAERConfigReg_D.Run_S,
				Enable_SI => StatisticsEventsColumn_SP,
				Data_DO   => DVSAERConfigInfoOut_DO.StatisticsEventsColumn_D);

		StatisticsEventsDroppedReg : entity work.SimpleRegister
			generic map(
				SIZE => 1)
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => StatisticsEventsDropped_SN,
				Output_SO(0) => StatisticsEventsDropped_SP);

		StatisticsEventsDroppedCounter : entity work.Counter
			generic map(
				SIZE => TRANSACTION_COUNTER_WIDTH)
			port map(
				Clock_CI  => Clock_CI,
				Reset_RI  => Reset_RI,
				Clear_SI  => not DVSAERConfigReg_D.Run_S,
				Enable_SI => StatisticsEventsDropped_SP,
				Data_DO   => DVSAERConfigInfoOut_DO.StatisticsEventsDropped_D);

		StatisticsFilteredPixels : if ENABLE_PIXEL_FILTERING = true generate
		begin
			StatisticsFilteredPixelsReg : entity work.SimpleRegister
				generic map(
					SIZE => 1)
				port map(
					Clock_CI     => Clock_CI,
					Reset_RI     => Reset_RI,
					Enable_SI    => '1',
					Input_SI(0)  => StatisticsFilteredPixels_SN,
					Output_SO(0) => StatisticsFilteredPixels_SP);

			StatisticsFilteredPixelsCounter : entity work.Counter
				generic map(
					SIZE => TRANSACTION_COUNTER_WIDTH)
				port map(
					Clock_CI  => Clock_CI,
					Reset_RI  => Reset_RI,
					Clear_SI  => not DVSAERConfigReg_D.Run_S,
					Enable_SI => StatisticsFilteredPixels_SP,
					Data_DO   => DVSAERConfigInfoOut_DO.StatisticsFilteredPixels_D);
		end generate StatisticsFilteredPixels;

		noStatisticsFilteredPixels : if ENABLE_PIXEL_FILTERING = false generate
		begin
			DVSAERConfigInfoOut_DO.StatisticsFilteredPixels_D <= (others => '0');
		end generate noStatisticsFilteredPixels;

		StatisticsFilteredBackgroundActivity : if ENABLE_BA_REFR_FILTERING = true generate
		begin
			StatisticsFilteredBackgroundActivityReg : entity work.SimpleRegister
				generic map(
					SIZE => 1)
				port map(
					Clock_CI     => Clock_CI,
					Reset_RI     => Reset_RI,
					Enable_SI    => '1',
					Input_SI(0)  => StatisticsFilteredBackgroundActivity_SN,
					Output_SO(0) => StatisticsFilteredBackgroundActivity_SP);

			StatisticsFilteredBackgroundActivityCounter : entity work.Counter
				generic map(
					SIZE => TRANSACTION_COUNTER_WIDTH)
				port map(
					Clock_CI  => Clock_CI,
					Reset_RI  => Reset_RI,
					Clear_SI  => not DVSAERConfigReg_D.Run_S,
					Enable_SI => StatisticsFilteredBackgroundActivity_SP,
					Data_DO   => DVSAERConfigInfoOut_DO.StatisticsFilteredBackgroundActivity_D);

			StatisticsFilteredRefractoryPeriodReg : entity work.SimpleRegister
				generic map(
					SIZE => 1)
				port map(
					Clock_CI     => Clock_CI,
					Reset_RI     => Reset_RI,
					Enable_SI    => '1',
					Input_SI(0)  => StatisticsFilteredRefractoryPeriod_SN,
					Output_SO(0) => StatisticsFilteredRefractoryPeriod_SP);

			StatisticsFilteredRefractoryPeriodCounter : entity work.Counter
				generic map(
					SIZE => TRANSACTION_COUNTER_WIDTH)
				port map(
					Clock_CI  => Clock_CI,
					Reset_RI  => Reset_RI,
					Clear_SI  => not DVSAERConfigReg_D.Run_S,
					Enable_SI => StatisticsFilteredRefractoryPeriod_SP,
					Data_DO   => DVSAERConfigInfoOut_DO.StatisticsFilteredRefractoryPeriod_D);
		end generate StatisticsFilteredBackgroundActivity;

		noStatisticsFilteredBackgroundActivity : if ENABLE_BA_REFR_FILTERING = false generate
		begin
			DVSAERConfigInfoOut_DO.StatisticsFilteredBackgroundActivity_D <= (others => '0');
			DVSAERConfigInfoOut_DO.StatisticsFilteredRefractoryPeriod_D   <= (others => '0');
		end generate noStatisticsFilteredBackgroundActivity;
	end generate statisticsSupport;
end Behavioral;
