library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use ieee.math_real."**";
use work.EventCodes.EVENT_WIDTH;
use work.Functions.BooleanToStdLogic;
use work.DVSAERConfigRecords.DVS_FILTER_BA_DELTAT_WIDTH;
use work.Settings.CHIP_DVS_SIZE_ROWS;
use work.Settings.CHIP_DVS_SIZE_COLUMNS;
use work.Settings.LOGIC_CLOCK_FREQ;

entity DVSBAFilterStateMachine is
	generic(
		BA_FILTER_SUBSAMPLE_COLUMN : integer := 2;
		BA_FILTER_SUBSAMPLE_ROW    : integer := 2);
	port(
		Clock_CI                                : in  std_logic;
		Reset_RI                                : in  std_logic;

		-- Filter control and settings.
		FilterBackgroundActivity_SI             : in  std_logic;
		FilterBackgroundActivityTime_DI         : in  unsigned(DVS_FILTER_BA_DELTAT_WIDTH - 1 downto 0);
		FilterRefractoryPeriod_SI               : in  std_logic;
		FilterRefractoryPeriodTime_DI           : in  unsigned(DVS_FILTER_BA_DELTAT_WIDTH - 1 downto 0);

		-- Statistics output.
		StatisticsFilteredBackgroundActivity_SO : out std_logic;
		StatisticsFilteredRefractoryPeriod_SO   : out std_logic;

		-- Data input.
		BAFilterInputData_DI                    : in  std_logic_vector(EVENT_WIDTH - 1 downto 0);
		BAFilterInputValid_SI                   : in  std_logic;

		-- Data output.
		BAFilterOutputData_DO                   : out std_logic_vector(EVENT_WIDTH - 1 downto 0);
		BAFilterOutputValid_SO                  : out std_logic);
end entity DVSBAFilterStateMachine;

architecture Behavioral of DVSBAFilterStateMachine is
	-- Bits needed for each address.
	constant DVS_ROW_ADDRESS_WIDTH    : integer := integer(ceil(log2(real(to_integer(CHIP_DVS_SIZE_ROWS)))));
	constant DVS_COLUMN_ADDRESS_WIDTH : integer := integer(ceil(log2(real(to_integer(CHIP_DVS_SIZE_COLUMNS)))));

	constant BA_COLUMN_ADDRESS_WIDTH : integer := DVS_COLUMN_ADDRESS_WIDTH - BA_FILTER_SUBSAMPLE_COLUMN;
	constant BA_ROW_ADDRESS_WIDTH    : integer := DVS_ROW_ADDRESS_WIDTH - BA_FILTER_SUBSAMPLE_ROW;
	constant BA_COLUMN_CELL_NUMBER   : integer := integer(ceil(real(to_integer(CHIP_DVS_SIZE_COLUMNS)) /(2.0 ** real(BA_FILTER_SUBSAMPLE_COLUMN))));
	constant BA_ROW_CELL_NUMBER      : integer := integer(ceil(real(to_integer(CHIP_DVS_SIZE_ROWS)) /(2.0 ** real(BA_FILTER_SUBSAMPLE_ROW))));
	constant BA_COLUMN_CELL_ADDRESS  : integer := integer(ceil(real(BA_COLUMN_CELL_NUMBER) / 2.0));
	constant BA_ROW_CELL_ADDRESS     : integer := integer(ceil(real(BA_ROW_CELL_NUMBER) / 2.0));
	constant BA_ADDRESS_DEPTH        : integer := BA_COLUMN_CELL_ADDRESS * BA_ROW_CELL_ADDRESS;
	constant BA_ADDRESS_WIDTH        : integer := integer(ceil(log2(real(BA_ADDRESS_DEPTH))));
	constant BA_TIMESTAMP_WIDTH      : integer := 18;

	signal TimestampMap0_DP, TimestampMap0_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampMap1_DP, TimestampMap1_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampMap2_DP, TimestampMap2_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampMap3_DP, TimestampMap3_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);

	signal TimestampMap0En_S, TimestampMap0WrEn_S : std_logic;
	signal TimestampMap1En_S, TimestampMap1WrEn_S : std_logic;
	signal TimestampMap2En_S, TimestampMap2WrEn_S : std_logic;
	signal TimestampMap3En_S, TimestampMap3WrEn_S : std_logic;

	signal TimestampMap0Address_D : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMap1Address_D : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMap2Address_D : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMap3Address_D : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);

	signal TimestampMapCenter_DP, TimestampMapCenter_DN : unsigned(1 downto 0);

	signal TimestampMapSelectLeft_SP, TimestampMapSelectLeft_SN           : std_logic;
	signal TimestampMapSelectRight_SP, TimestampMapSelectRight_SN         : std_logic;
	signal TimestampMapSelectDown_SP, TimestampMapSelectDown_SN           : std_logic;
	signal TimestampMapSelectDownLeft_SP, TimestampMapSelectDownLeft_SN   : std_logic;
	signal TimestampMapSelectDownRight_SP, TimestampMapSelectDownRight_SN : std_logic;
	signal TimestampMapSelectUp_SP, TimestampMapSelectUp_SN               : std_logic;
	signal TimestampMapSelectUpLeft_SP, TimestampMapSelectUpLeft_SN       : std_logic;
	signal TimestampMapSelectUpRight_SP, TimestampMapSelectUpRight_SN     : std_logic;

	signal TimestampMapAddressCenter_DP, TimestampMapAddressCenter_DN       : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressLeft_DP, TimestampMapAddressLeft_DN           : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressRight_DP, TimestampMapAddressRight_DN         : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressDown_DP, TimestampMapAddressDown_DN           : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressDownLeft_DP, TimestampMapAddressDownLeft_DN   : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressDownRight_DP, TimestampMapAddressDownRight_DN : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressUp_DP, TimestampMapAddressUp_DN               : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressUpLeft_DP, TimestampMapAddressUpLeft_DN       : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);
	signal TimestampMapAddressUpRight_DP, TimestampMapAddressUpRight_DN     : unsigned(BA_ADDRESS_WIDTH - 1 downto 0);

	-- Generate continuous timestamp value, expanded to N microseconds per tick.
	constant TICK_EXPANSION : integer := 250;
	constant TS_TICK        : integer := LOGIC_CLOCK_FREQ * TICK_EXPANSION;
	constant TS_TICK_SIZE   : integer := integer(ceil(log2(real(TS_TICK))));

	signal TimestampTick_S          : std_logic;
	signal Timestamp_D              : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampBuffer_D        : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampBufferRefresh_S : std_logic;

	signal TimestampDifference0_DP, TimestampDifference0_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampDifference1_DP, TimestampDifference1_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampDifference2_DP, TimestampDifference2_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);
	signal TimestampDifference3_DP, TimestampDifference3_DN : unsigned(BA_TIMESTAMP_WIDTH - 1 downto 0);

	signal LastRowAddress_DP, LastRowAddress_DN : unsigned(DVS_ROW_ADDRESS_WIDTH - 1 downto 0);

	attribute syn_enum_encoding : string;

	type tState is (stIdle, stLookup0, stLookup1, stLookup2Results0, stLookup3Results1DecideRefractory, stResults2, stResults3, stDecideBA);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- Present and next state (state machine).
	signal State_DP, State_DN : tState;

	-- Is the filter running at all?
	signal FilterIsEnabled_S : std_logic;

	-- Keep track of BAFilter results, we can only verify at the end of all lookups
	-- because the question we need to answer is "did any of the neighbors spike
	-- within the time period?", and we need to read them all to do that.
	-- The lookup 0 results also track the refractory period filter result, so 3 bits.
	signal BAFilterLookup0Results_DP, BAFilterLookup0Results_DN : std_logic_vector(2 downto 0);
	signal BAFilterLookup1Results_DP, BAFilterLookup1Results_DN : std_logic_vector(1 downto 0);
	signal BAFilterLookup2Results_DP, BAFilterLookup2Results_DN : std_logic_vector(1 downto 0);
	signal BAFilterLookup3Results_DP, BAFilterLookup3Results_DN : std_logic_vector(1 downto 0);
begin
	-- The next value, if and when we're going to write to a RAM address, is
	-- always going to be the current timestamp. So we can just hardcode that.
	TimestampMap0_DN <= TimestampBuffer_D;
	TimestampMap1_DN <= TimestampBuffer_D;
	TimestampMap2_DN <= TimestampBuffer_D;
	TimestampMap3_DN <= TimestampBuffer_D;

	TimestampDifference0_DN <= (TimestampBuffer_D - TimestampMap0_DP);
	TimestampDifference1_DN <= (TimestampBuffer_D - TimestampMap1_DP);
	TimestampDifference2_DN <= (TimestampBuffer_D - TimestampMap2_DP);
	TimestampDifference3_DN <= (TimestampBuffer_D - TimestampMap3_DP);

	FilterIsEnabled_S <= FilterBackgroundActivity_SI or FilterRefractoryPeriod_SI;

	baFilterLogic : process(State_DP, LastRowAddress_DP, BAFilterInputData_DI, BAFilterInputValid_SI, TimestampMapAddressDownLeft_DP, TimestampMapAddressDownRight_DP, TimestampMapAddressDown_DP, TimestampMapAddressLeft_DP, TimestampMapAddressRight_DP, TimestampMapAddressUpLeft_DP, TimestampMapAddressUpRight_DP, TimestampMapAddressUp_DP, TimestampMapAddressCenter_DP, TimestampMapCenter_DP, FilterIsEnabled_S, TimestampMapSelectDownLeft_SP, TimestampMapSelectDownRight_SP, TimestampMapSelectDown_SP, TimestampMapSelectLeft_SP, TimestampMapSelectRight_SP, TimestampMapSelectUpLeft_SP, TimestampMapSelectUpRight_SP, TimestampMapSelectUp_SP, FilterBackgroundActivityTime_DI, FilterRefractoryPeriodTime_DI, FilterBackgroundActivity_SI, FilterRefractoryPeriod_SI, BAFilterLookup0Results_DP, BAFilterLookup1Results_DP, BAFilterLookup2Results_DP, BAFilterLookup3Results_DP, TimestampDifference0_DP, TimestampDifference1_DP, TimestampDifference2_DP, TimestampDifference3_DP)
		variable ColumnAddress_D : unsigned(BA_COLUMN_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
		variable RowAddress_D    : unsigned(BA_ROW_ADDRESS_WIDTH - 1 downto 0)    := (others => '0');

		variable BorderLeft_S  : std_logic := '0';
		variable BorderDown_S  : std_logic := '0';
		variable BorderRight_S : std_logic := '0';
		variable BorderUp_S    : std_logic := '0';

		variable TimestampMapAddress_D     : unsigned(BA_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
		variable TimestampMapAddressDown_D : unsigned(BA_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
		variable TimestampMapAddressUp_D   : unsigned(BA_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
	begin
		State_DN <= State_DP;           -- Keep current state by default.

		LastRowAddress_DN <= LastRowAddress_DP;

		TimestampMapCenter_DN <= TimestampMapCenter_DP;

		TimestampMapSelectLeft_SN      <= TimestampMapSelectLeft_SP;
		TimestampMapSelectRight_SN     <= TimestampMapSelectRight_SP;
		TimestampMapSelectDown_SN      <= TimestampMapSelectDown_SP;
		TimestampMapSelectDownLeft_SN  <= TimestampMapSelectDownLeft_SP;
		TimestampMapSelectDownRight_SN <= TimestampMapSelectDownRight_SP;
		TimestampMapSelectUp_SN        <= TimestampMapSelectUp_SP;
		TimestampMapSelectUpLeft_SN    <= TimestampMapSelectUpLeft_SP;
		TimestampMapSelectUpRight_SN   <= TimestampMapSelectUpRight_SP;

		TimestampMapAddressCenter_DN    <= TimestampMapAddressCenter_DP;
		TimestampMapAddressLeft_DN      <= TimestampMapAddressLeft_DP;
		TimestampMapAddressRight_DN     <= TimestampMapAddressRight_DP;
		TimestampMapAddressDown_DN      <= TimestampMapAddressDown_DP;
		TimestampMapAddressDownLeft_DN  <= TimestampMapAddressDownLeft_DP;
		TimestampMapAddressDownRight_DN <= TimestampMapAddressDownRight_DP;
		TimestampMapAddressUp_DN        <= TimestampMapAddressUp_DP;
		TimestampMapAddressUpLeft_DN    <= TimestampMapAddressUpLeft_DP;
		TimestampMapAddressUpRight_DN   <= TimestampMapAddressUpRight_DP;

		TimestampBufferRefresh_S <= '0';

		TimestampMap0En_S <= '0';
		TimestampMap1En_S <= '0';
		TimestampMap2En_S <= '0';
		TimestampMap3En_S <= '0';

		TimestampMap0WrEn_S <= '0';
		TimestampMap1WrEn_S <= '0';
		TimestampMap2WrEn_S <= '0';
		TimestampMap3WrEn_S <= '0';

		TimestampMap0Address_D <= (others => '0');
		TimestampMap1Address_D <= (others => '0');
		TimestampMap2Address_D <= (others => '0');
		TimestampMap3Address_D <= (others => '0');

		-- Keep track of BAFilter results.
		BAFilterLookup0Results_DN <= BAFilterLookup0Results_DP;
		BAFilterLookup1Results_DN <= BAFilterLookup1Results_DP;
		BAFilterLookup2Results_DN <= BAFilterLookup2Results_DP;
		BAFilterLookup3Results_DN <= BAFilterLookup3Results_DP;

		-- Nothing is being filtered out by default.
		StatisticsFilteredBackgroundActivity_SO <= '0';
		StatisticsFilteredRefractoryPeriod_SO   <= '0';

		BAFilterOutputData_DO  <= BAFilterInputData_DI;
		BAFilterOutputValid_SO <= '0';

		case State_DP is
			when stIdle =>
				if FilterIsEnabled_S then
					if BAFilterInputValid_SI then
						if BAFilterInputData_DI(EVENT_WIDTH - 2) = '0' then
							-- This is a row address, we just save it for later and forward it.
							LastRowAddress_DN <= unsigned(BAFilterInputData_DI(DVS_ROW_ADDRESS_WIDTH - 1 downto 0));

							BAFilterOutputValid_SO <= BAFilterInputValid_SI;
						else
							-- This is a column address, save it and calculate all map-related
							-- lookup information, so then we can execute all the lookup states.
							ColumnAddress_D := unsigned(BAFilterInputData_DI(DVS_COLUMN_ADDRESS_WIDTH - 1 downto BA_FILTER_SUBSAMPLE_COLUMN));
							RowAddress_D    := LastRowAddress_DP(DVS_ROW_ADDRESS_WIDTH - 1 downto BA_FILTER_SUBSAMPLE_ROW);

							BorderLeft_S  := BooleanToStdLogic(ColumnAddress_D = 0);
							BorderDown_S  := BooleanToStdLogic(RowAddress_D = (BA_ROW_CELL_NUMBER - 1));
							BorderRight_S := BooleanToStdLogic(ColumnAddress_D = (BA_COLUMN_CELL_NUMBER - 1));
							BorderUp_S    := BooleanToStdLogic(RowAddress_D = 0);

							TimestampMapCenter_DN <= RowAddress_D(0) & ColumnAddress_D(0);

							TimestampMapSelectLeft_SN      <= not BorderLeft_S;
							TimestampMapSelectRight_SN     <= not BorderRight_S;
							TimestampMapSelectDown_SN      <= not BorderDown_S;
							TimestampMapSelectDownLeft_SN  <= not BorderLeft_S and not BorderDown_S;
							TimestampMapSelectDownRight_SN <= not BorderRight_S and not BorderDown_S;
							TimestampMapSelectUp_SN        <= not BorderUp_S;
							TimestampMapSelectUpLeft_SN    <= not BorderLeft_S and not BorderUp_S;
							TimestampMapSelectUpRight_SN   <= not BorderRight_S and not BorderUp_S;

							-- Use only one multiplication, add/sub for up/down after.
							TimestampMapAddress_D        := resize(RowAddress_D(BA_ROW_ADDRESS_WIDTH - 1 downto 1) * to_unsigned(BA_COLUMN_CELL_ADDRESS, BA_COLUMN_ADDRESS_WIDTH) + ColumnAddress_D(BA_COLUMN_ADDRESS_WIDTH - 1 downto 1), BA_ADDRESS_WIDTH);
							TimestampMapAddressCenter_DN <= TimestampMapAddress_D;
							TimestampMapAddressLeft_DN   <= TimestampMapAddress_D - 1;
							TimestampMapAddressRight_DN  <= TimestampMapAddress_D + 1;

							TimestampMapAddressDown_D       := TimestampMapAddress_D + to_unsigned(BA_COLUMN_CELL_ADDRESS, BA_COLUMN_ADDRESS_WIDTH);
							TimestampMapAddressDown_DN      <= TimestampMapAddressDown_D;
							TimestampMapAddressDownLeft_DN  <= TimestampMapAddressDown_D - 1;
							TimestampMapAddressDownRight_DN <= TimestampMapAddressDown_D + 1;

							TimestampMapAddressUp_D       := TimestampMapAddress_D - to_unsigned(BA_COLUMN_CELL_ADDRESS, BA_COLUMN_ADDRESS_WIDTH);
							TimestampMapAddressUp_DN      <= TimestampMapAddressUp_D;
							TimestampMapAddressUpLeft_DN  <= TimestampMapAddressUp_D - 1;
							TimestampMapAddressUpRight_DN <= TimestampMapAddressUp_D + 1;

							-- Fix timestamp for the subsequent series of lookups and comparisons.
							TimestampBufferRefresh_S <= '1';

							-- Go do first lookup. No data/valid output here, only if all filter stages
							-- work out do we send out the column address with a valid bit.
							State_DN <= stLookup0;
						end if;
					end if;
				else
					-- Filter disabled, just forward input valid and remain in this state.
					BAFilterOutputValid_SO <= BAFilterInputValid_SI;
				end if;

			-- Lookups are to be done in the following sequence:
			-- +---+---+---+
			-- | 2 | 3 | 0 |
			-- +---+---+---+
			-- | 0 |w0w| 1 |
			-- +---+---+---+
			-- | 1 | 2 | 3 |
			-- +---+---+---+
			-- stLookup0 will do the ones marked 0, stLookup1 the ones marked 1 and so on.
			-- The next-next state is always responsible for checking the prev-prev state's
			-- results, so stLookup2 will check the 0 cells, stLookup3 the 1 cells and so on.
			-- If a concrete filtering decision can be taken early, it will be.
			-- A final stDecide state checks number 3 cells and returns to stIdle.
			-- The central cell, which is also being written with the new up-to-date timestamp,
			-- is checked right at the start, to allow an early exit for the refractory case.
			when stLookup0 =>
				-- Prepare lookup for Center (write), Left and UpRight.
				case TimestampMapCenter_DP is
					when "00" =>
						TimestampMap0En_S      <= '1';
						TimestampMap0WrEn_S    <= '1';
						TimestampMap0Address_D <= TimestampMapAddressCenter_DP;

						TimestampMap1En_S      <= TimestampMapSelectLeft_SP;
						TimestampMap1Address_D <= TimestampMapAddressLeft_DP;

						TimestampMap3En_S      <= TimestampMapSelectUpRight_SP;
						TimestampMap3Address_D <= TimestampMapAddressUpRight_DP;

					when "01" =>
						TimestampMap1En_S      <= '1';
						TimestampMap1WrEn_S    <= '1';
						TimestampMap1Address_D <= TimestampMapAddressCenter_DP;

						TimestampMap0En_S      <= TimestampMapSelectLeft_SP;
						TimestampMap0Address_D <= TimestampMapAddressLeft_DP;

						TimestampMap2En_S      <= TimestampMapSelectUpRight_SP;
						TimestampMap2Address_D <= TimestampMapAddressUpRight_DP;

					when "10" =>
						TimestampMap2En_S      <= '1';
						TimestampMap2WrEn_S    <= '1';
						TimestampMap2Address_D <= TimestampMapAddressCenter_DP;

						TimestampMap3En_S      <= TimestampMapSelectLeft_SP;
						TimestampMap3Address_D <= TimestampMapAddressLeft_DP;

						TimestampMap1En_S      <= TimestampMapSelectUpRight_SP;
						TimestampMap1Address_D <= TimestampMapAddressUpRight_DP;

					when "11" =>
						TimestampMap3En_S      <= '1';
						TimestampMap3WrEn_S    <= '1';
						TimestampMap3Address_D <= TimestampMapAddressCenter_DP;

						TimestampMap2En_S      <= TimestampMapSelectLeft_SP;
						TimestampMap2Address_D <= TimestampMapAddressLeft_DP;

						TimestampMap0En_S      <= TimestampMapSelectUpRight_SP;
						TimestampMap0Address_D <= TimestampMapAddressUpRight_DP;

					when others => null;
				end case;

				State_DN <= stLookup1;

			when stLookup1 =>
				-- Prepare lookup for DownLeft and Right.
				case TimestampMapCenter_DP is
					when "00" =>
						TimestampMap3En_S      <= TimestampMapSelectDownLeft_SP;
						TimestampMap3Address_D <= TimestampMapAddressDownLeft_DP;

						TimestampMap1En_S      <= TimestampMapSelectRight_SP;
						TimestampMap1Address_D <= TimestampMapAddressRight_DP;

					when "01" =>
						TimestampMap2En_S      <= TimestampMapSelectDownLeft_SP;
						TimestampMap2Address_D <= TimestampMapAddressDownLeft_DP;

						TimestampMap0En_S      <= TimestampMapSelectRight_SP;
						TimestampMap0Address_D <= TimestampMapAddressRight_DP;

					when "10" =>
						TimestampMap1En_S      <= TimestampMapSelectDownLeft_SP;
						TimestampMap1Address_D <= TimestampMapAddressDownLeft_DP;

						TimestampMap3En_S      <= TimestampMapSelectRight_SP;
						TimestampMap3Address_D <= TimestampMapAddressRight_DP;

					when "11" =>
						TimestampMap0En_S      <= TimestampMapSelectDownLeft_SP;
						TimestampMap0Address_D <= TimestampMapAddressDownLeft_DP;

						TimestampMap2En_S      <= TimestampMapSelectRight_SP;
						TimestampMap2Address_D <= TimestampMapAddressRight_DP;

					when others => null;
				end case;

				State_DN <= stLookup2Results0;

			when stLookup2Results0 =>
				-- Verify lookup 0 results for Center, Left and UpRight.
				case TimestampMapCenter_DP is
					when "00" =>
						-- Center result. REFR: '0' means invalid.
						BAFilterLookup0Results_DN(2) <= BooleanToStdLogic(TimestampDifference0_DP >= FilterRefractoryPeriodTime_DI);

						-- Left result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(0) <= TimestampMapSelectLeft_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

						-- UpRight result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(1) <= TimestampMapSelectUpRight_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

					when "01" =>
						-- Center result. REFR: '0' means invalid.
						BAFilterLookup0Results_DN(2) <= BooleanToStdLogic(TimestampDifference1_DP >= FilterRefractoryPeriodTime_DI);

						-- Left result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(0) <= TimestampMapSelectLeft_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

						-- UpRight result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(1) <= TimestampMapSelectUpRight_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

					when "10" =>
						-- Center result. REFR: '0' means invalid.
						BAFilterLookup0Results_DN(2) <= BooleanToStdLogic(TimestampDifference2_DP >= FilterRefractoryPeriodTime_DI);

						-- Left result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(0) <= TimestampMapSelectLeft_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

						-- UpRight result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(1) <= TimestampMapSelectUpRight_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

					when "11" =>
						-- Center result. REFR: '0' means invalid.
						BAFilterLookup0Results_DN(2) <= BooleanToStdLogic(TimestampDifference3_DP >= FilterRefractoryPeriodTime_DI);

						-- Left result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(0) <= TimestampMapSelectLeft_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

						-- UpRight result. BA: '0' means invalid.
						BAFilterLookup0Results_DN(1) <= TimestampMapSelectUpRight_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

					when others => null;
				end case;

				-- Prepare lookup for UpLeft and Down.
				case TimestampMapCenter_DP is
					when "00" =>
						TimestampMap3En_S      <= TimestampMapSelectUpLeft_SP;
						TimestampMap3Address_D <= TimestampMapAddressUpLeft_DP;

						TimestampMap2En_S      <= TimestampMapSelectDown_SP;
						TimestampMap2Address_D <= TimestampMapAddressDown_DP;

					when "01" =>
						TimestampMap2En_S      <= TimestampMapSelectUpLeft_SP;
						TimestampMap2Address_D <= TimestampMapAddressUpLeft_DP;

						TimestampMap3En_S      <= TimestampMapSelectDown_SP;
						TimestampMap3Address_D <= TimestampMapAddressDown_DP;

					when "10" =>
						TimestampMap1En_S      <= TimestampMapSelectUpLeft_SP;
						TimestampMap1Address_D <= TimestampMapAddressUpLeft_DP;

						TimestampMap0En_S      <= TimestampMapSelectDown_SP;
						TimestampMap0Address_D <= TimestampMapAddressDown_DP;

					when "11" =>
						TimestampMap0En_S      <= TimestampMapSelectUpLeft_SP;
						TimestampMap0Address_D <= TimestampMapAddressUpLeft_DP;

						TimestampMap1En_S      <= TimestampMapSelectDown_SP;
						TimestampMap1Address_D <= TimestampMapAddressDown_DP;

					when others => null;
				end case;

				State_DN <= stLookup3Results1DecideRefractory;

			when stLookup3Results1DecideRefractory =>
				-- Verify lookup 1 results for DownLeft and Right.
				case TimestampMapCenter_DP is
					when "00" =>
						-- DownLeft result.
						BAFilterLookup1Results_DN(0) <= TimestampMapSelectDownLeft_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

						-- Right result.
						BAFilterLookup1Results_DN(1) <= TimestampMapSelectRight_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

					when "01" =>
						-- DownLeft result.
						BAFilterLookup1Results_DN(0) <= TimestampMapSelectDownLeft_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

						-- Right result.
						BAFilterLookup1Results_DN(1) <= TimestampMapSelectRight_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

					when "10" =>
						-- DownLeft result.
						BAFilterLookup1Results_DN(0) <= TimestampMapSelectDownLeft_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

						-- Right result.
						BAFilterLookup1Results_DN(1) <= TimestampMapSelectRight_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

					when "11" =>
						-- DownLeft result.
						BAFilterLookup1Results_DN(0) <= TimestampMapSelectDownLeft_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

						-- Right result.
						BAFilterLookup1Results_DN(1) <= TimestampMapSelectRight_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

					when others => null;
				end case;

				-- Prepare lookup for Up and DownRight.
				case TimestampMapCenter_DP is
					when "00" =>
						TimestampMap2En_S      <= TimestampMapSelectUp_SP;
						TimestampMap2Address_D <= TimestampMapAddressUp_DP;

						TimestampMap3En_S      <= TimestampMapSelectDownRight_SP;
						TimestampMap3Address_D <= TimestampMapAddressDownRight_DP;

					when "01" =>
						TimestampMap3En_S      <= TimestampMapSelectUp_SP;
						TimestampMap3Address_D <= TimestampMapAddressUp_DP;

						TimestampMap2En_S      <= TimestampMapSelectDownRight_SP;
						TimestampMap2Address_D <= TimestampMapAddressDownRight_DP;

					when "10" =>
						TimestampMap0En_S      <= TimestampMapSelectUp_SP;
						TimestampMap0Address_D <= TimestampMapAddressUp_DP;

						TimestampMap1En_S      <= TimestampMapSelectDownRight_SP;
						TimestampMap1Address_D <= TimestampMapAddressDownRight_DP;

					when "11" =>
						TimestampMap1En_S      <= TimestampMapSelectUp_SP;
						TimestampMap1Address_D <= TimestampMapAddressUp_DP;

						TimestampMap0En_S      <= TimestampMapSelectDownRight_SP;
						TimestampMap0Address_D <= TimestampMapAddressDownRight_DP;

					when others => null;
				end case;

				-- If true, time between spikes is smaller than limit, so the event is
				-- filtered out (if RefractoryFilter enabled). Return to idle, doing
				-- the other lookups and checks makes no sense.
				if FilterRefractoryPeriod_SI and not BAFilterLookup0Results_DP(2) then
					State_DN <= stIdle;

					StatisticsFilteredRefractoryPeriod_SO <= '1';
				elsif FilterBackgroundActivity_SI then
					-- Only continue with BA filtering if really enabled.
					State_DN <= stResults2;
				else
					-- Both filters turend off in the meantime, or only refractory enabled
					-- but with a valid event, so pass the current event.
					State_DN <= stIdle;

					BAFilterOutputValid_SO <= '1';
				end if;

			when stResults2 =>
				-- Verify lookup 2 results for UpLeft and Down.
				case TimestampMapCenter_DP is
					when "00" =>
						-- UpLeft result.
						BAFilterLookup2Results_DN(0) <= TimestampMapSelectUpLeft_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

						-- Down result.
						BAFilterLookup2Results_DN(1) <= TimestampMapSelectDown_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

					when "01" =>
						-- UpLeft result.
						BAFilterLookup2Results_DN(0) <= TimestampMapSelectUpLeft_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

						-- Down result.
						BAFilterLookup2Results_DN(1) <= TimestampMapSelectDown_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

					when "10" =>
						-- UpLeft result.
						BAFilterLookup2Results_DN(0) <= TimestampMapSelectUpLeft_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

						-- Down result.
						BAFilterLookup2Results_DN(1) <= TimestampMapSelectDown_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

					when "11" =>
						-- UpLeft result.
						BAFilterLookup2Results_DN(0) <= TimestampMapSelectUpLeft_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

						-- Down result.
						BAFilterLookup2Results_DN(1) <= TimestampMapSelectDown_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

					when others => null;
				end case;

				State_DN <= stResults3;

			when stResults3 =>
				-- Verify lookup 3 results for Up and DownRight.
				case TimestampMapCenter_DP is
					when "00" =>
						-- Up result.
						BAFilterLookup3Results_DN(0) <= TimestampMapSelectUp_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

						-- DownRight result.
						BAFilterLookup3Results_DN(1) <= TimestampMapSelectDownRight_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

					when "01" =>
						-- Up result.
						BAFilterLookup3Results_DN(0) <= TimestampMapSelectUp_SP and BooleanToStdLogic(TimestampDifference3_DP <= FilterBackgroundActivityTime_DI);

						-- DownRight result.
						BAFilterLookup3Results_DN(1) <= TimestampMapSelectDownRight_SP and BooleanToStdLogic(TimestampDifference2_DP <= FilterBackgroundActivityTime_DI);

					when "10" =>
						-- Up result.
						BAFilterLookup3Results_DN(0) <= TimestampMapSelectUp_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

						-- DownRight result.
						BAFilterLookup3Results_DN(1) <= TimestampMapSelectDownRight_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

					when "11" =>
						-- Up result.
						BAFilterLookup3Results_DN(0) <= TimestampMapSelectUp_SP and BooleanToStdLogic(TimestampDifference1_DP <= FilterBackgroundActivityTime_DI);

						-- DownRight result.
						BAFilterLookup3Results_DN(1) <= TimestampMapSelectDownRight_SP and BooleanToStdLogic(TimestampDifference0_DP <= FilterBackgroundActivityTime_DI);

					when others => null;
				end case;

				State_DN <= stDecideBA;

			when stDecideBA =>
				-- If all lookup results are zero, no neighbor spiked within the time limit,
				-- so we must suppress this event (only if BAFilter enabled).
				if FilterBackgroundActivity_SI and BooleanToStdLogic(BAFilterLookup0Results_DP(1 downto 0) = "00") and BooleanToStdLogic(BAFilterLookup1Results_DP = "00") and BooleanToStdLogic(BAFilterLookup2Results_DP = "00") and BooleanToStdLogic(BAFilterLookup3Results_DP = "00") then
					-- Invalid event, don't pass it on.
					StatisticsFilteredBackgroundActivity_SO <= '1';
				else
					-- Filter was turend off in the meantime, or is enabled
					-- but with a valid event, so pass the current event.
					BAFilterOutputValid_SO <= '1';
				end if;

				State_DN <= stIdle;

			when others => null;
		end case;
	end process baFilterLogic;

	-- Change state on clock edge (synchronous).
	baFilterRegUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			State_DP <= stIdle;
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;
		end if;
	end process baFilterRegUpdate;

	TSMap0 : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => BA_ADDRESS_DEPTH,
			ADDRESS_WIDTH => BA_ADDRESS_WIDTH,
			DATA_WIDTH    => BA_TIMESTAMP_WIDTH,
			WRITE_MODE    => "readbeforewrite")
		port map(
			Clock_CI          => Clock_CI,
			Reset_RI          => Reset_RI,
			Address_DI        => TimestampMap0Address_D,
			Enable_SI         => TimestampMap0En_S,
			WriteEnable_SI    => TimestampMap0WrEn_S,
			Data_DI           => std_logic_vector(TimestampMap0_DN),
			unsigned(Data_DO) => TimestampMap0_DP,
			DataValid_SO      => open);

	TSMap1 : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => BA_ADDRESS_DEPTH,
			ADDRESS_WIDTH => BA_ADDRESS_WIDTH,
			DATA_WIDTH    => BA_TIMESTAMP_WIDTH,
			WRITE_MODE    => "readbeforewrite")
		port map(
			Clock_CI          => Clock_CI,
			Reset_RI          => Reset_RI,
			Address_DI        => TimestampMap1Address_D,
			Enable_SI         => TimestampMap1En_S,
			WriteEnable_SI    => TimestampMap1WrEn_S,
			Data_DI           => std_logic_vector(TimestampMap1_DN),
			unsigned(Data_DO) => TimestampMap1_DP,
			DataValid_SO      => open);

	TSMap2 : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => BA_ADDRESS_DEPTH,
			ADDRESS_WIDTH => BA_ADDRESS_WIDTH,
			DATA_WIDTH    => BA_TIMESTAMP_WIDTH,
			WRITE_MODE    => "readbeforewrite")
		port map(
			Clock_CI          => Clock_CI,
			Reset_RI          => Reset_RI,
			Address_DI        => TimestampMap2Address_D,
			Enable_SI         => TimestampMap2En_S,
			WriteEnable_SI    => TimestampMap2WrEn_S,
			Data_DI           => std_logic_vector(TimestampMap2_DN),
			unsigned(Data_DO) => TimestampMap2_DP,
			DataValid_SO      => open);

	TSMap3 : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => BA_ADDRESS_DEPTH,
			ADDRESS_WIDTH => BA_ADDRESS_WIDTH,
			DATA_WIDTH    => BA_TIMESTAMP_WIDTH,
			WRITE_MODE    => "readbeforewrite")
		port map(
			Clock_CI          => Clock_CI,
			Reset_RI          => Reset_RI,
			Address_DI        => TimestampMap3Address_D,
			Enable_SI         => TimestampMap3En_S,
			WriteEnable_SI    => TimestampMap3WrEn_S,
			Data_DI           => std_logic_vector(TimestampMap3_DN),
			unsigned(Data_DO) => TimestampMap3_DP,
			DataValid_SO      => open);

	TSDifference0 : entity work.SimpleRegister
		generic map(
			SIZE => BA_TIMESTAMP_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampDifference0_DN),
			unsigned(Output_SO) => TimestampDifference0_DP);

	TSDifference1 : entity work.SimpleRegister
		generic map(
			SIZE => BA_TIMESTAMP_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampDifference1_DN),
			unsigned(Output_SO) => TimestampDifference1_DP);

	TSDifference2 : entity work.SimpleRegister
		generic map(
			SIZE => BA_TIMESTAMP_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampDifference2_DN),
			unsigned(Output_SO) => TimestampDifference2_DP);

	TSDifference3 : entity work.SimpleRegister
		generic map(
			SIZE => BA_TIMESTAMP_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampDifference3_DN),
			unsigned(Output_SO) => TimestampDifference3_DP);

	TSMapCenter : entity work.SimpleRegister
		generic map(
			SIZE => 2)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapCenter_DN),
			unsigned(Output_SO) => TimestampMapCenter_DP);

	TSMapSelectLeft : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectLeft_SN,
			Output_SO(0) => TimestampMapSelectLeft_SP);

	TSMapSelectRight : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectRight_SN,
			Output_SO(0) => TimestampMapSelectRight_SP);

	TSMapSelectDown : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectDown_SN,
			Output_SO(0) => TimestampMapSelectDown_SP);

	TSMapSelectDownLeft : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectDownLeft_SN,
			Output_SO(0) => TimestampMapSelectDownLeft_SP);

	TSMapSelectDownRight : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectDownRight_SN,
			Output_SO(0) => TimestampMapSelectDownRight_SP);

	TSMapSelectUp : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectUp_SN,
			Output_SO(0) => TimestampMapSelectUp_SP);

	TSMapSelectUpLeft : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectUpLeft_SN,
			Output_SO(0) => TimestampMapSelectUpLeft_SP);

	TSMapSelectUpRight : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => TimestampMapSelectUpRight_SN,
			Output_SO(0) => TimestampMapSelectUpRight_SP);

	TSMapAddressCenter : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressCenter_DN),
			unsigned(Output_SO) => TimestampMapAddressCenter_DP);

	TSMapAddressLeft : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressLeft_DN),
			unsigned(Output_SO) => TimestampMapAddressLeft_DP);

	TSMapAddressRight : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressRight_DN),
			unsigned(Output_SO) => TimestampMapAddressRight_DP);

	TSMapAddressDown : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressDown_DN),
			unsigned(Output_SO) => TimestampMapAddressDown_DP);

	TSMapAddressDownLeft : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressDownLeft_DN),
			unsigned(Output_SO) => TimestampMapAddressDownLeft_DP);

	TSMapAddressDownRight : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressDownRight_DN),
			unsigned(Output_SO) => TimestampMapAddressDownRight_DP);

	TSMapAddressUp : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressUp_DN),
			unsigned(Output_SO) => TimestampMapAddressUp_DP);

	TSMapAddressUpLeft : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressUpLeft_DN),
			unsigned(Output_SO) => TimestampMapAddressUpLeft_DP);

	TSMapAddressUpRight : entity work.SimpleRegister
		generic map(
			SIZE => BA_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(TimestampMapAddressUpRight_DN),
			unsigned(Output_SO) => TimestampMapAddressUpRight_DP);

	baFilterTSTick : entity work.ContinuousCounter
		generic map(
			SIZE => TS_TICK_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not FilterIsEnabled_S,
			Enable_SI    => '1',
			DataLimit_DI => to_unsigned(TS_TICK - 1, TS_TICK_SIZE),
			Overflow_SO  => TimestampTick_S,
			Data_DO      => open);

	baFilterTSCounter : entity work.Counter
		generic map(
			SIZE => BA_TIMESTAMP_WIDTH)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Clear_SI  => not FilterIsEnabled_S,
			Enable_SI => TimestampTick_S,
			Data_DO   => Timestamp_D);

	baFilterTSBuffer : entity work.SimpleRegister
		generic map(
			SIZE => BA_TIMESTAMP_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => TimestampBufferRefresh_S,
			Input_SI            => std_logic_vector(Timestamp_D),
			unsigned(Output_SO) => TimestampBuffer_D);

	baFilterLastRowAddressRegister : entity work.SimpleRegister
		generic map(
			SIZE => DVS_ROW_ADDRESS_WIDTH)
		port map(
			Clock_CI            => Clock_CI,
			Reset_RI            => Reset_RI,
			Enable_SI           => '1',
			Input_SI            => std_logic_vector(LastRowAddress_DN),
			unsigned(Output_SO) => LastRowAddress_DP);

	baFilterLookup0ResultsRegister : entity work.SimpleRegister
		generic map(
			SIZE => 3)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Enable_SI => '1',
			Input_SI  => BAFilterLookup0Results_DN,
			Output_SO => BAFilterLookup0Results_DP);

	baFilterLookup1ResultsRegister : entity work.SimpleRegister
		generic map(
			SIZE => 2)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Enable_SI => '1',
			Input_SI  => BAFilterLookup1Results_DN,
			Output_SO => BAFilterLookup1Results_DP);

	baFilterLookup2ResultsRegister : entity work.SimpleRegister
		generic map(
			SIZE => 2)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Enable_SI => '1',
			Input_SI  => BAFilterLookup2Results_DN,
			Output_SO => BAFilterLookup2Results_DP);

	baFilterLookup3ResultsRegister : entity work.SimpleRegister
		generic map(
			SIZE => 2)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Enable_SI => '1',
			Input_SI  => BAFilterLookup3Results_DN,
			Output_SO => BAFilterLookup3Results_DP);
end architecture Behavioral;
