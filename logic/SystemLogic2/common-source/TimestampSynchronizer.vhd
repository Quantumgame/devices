library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.floor;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;

-- On our MachXO and Spartan6 based boards, we always employ FX2 chips.
-- Those generate a precise 30 MHz clock, and can thus be used directly
-- to generate the needed 1us timestamp increase signals.
-- On our newer MachXO3 and ECP3 based boards, we use an FX3 chip instead.
-- This one generates a clock that is not exactly as we expect it, instead of
-- 100 MHz it's 100.8 MHz, so off by a factor of 1.008. This must be taken
-- into account when generating timestamp increase signals, so that the device
-- time as reported for events and real-time, as well as the sync signals,
-- don't diverge after some time the device is running.
entity TimestampSynchronizer is
	port(
		Clock_CI          : in  std_logic;
		Reset_RI          : in  std_logic;

		SyncInClock_CI    : in  std_logic;
		SyncOutClock_CO   : out std_logic;

		DeviceIsMaster_SO : out std_logic;

		TimestampRun_SI   : in  std_logic;
		TimestampReset_SI : in  std_logic;

		TimestampInc_SO   : out std_logic;
		TimestampReset_SO : out std_logic);
end entity TimestampSynchronizer;

architecture Behavioral of TimestampSynchronizer is
	attribute syn_enum_encoding : string;

	type tState is (stMasterRun, stMasterResetSlaves, stSlaveRun, stSlaveWaitEdge, stStlaveWaitReset);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- Present and next states.
	signal State_DP, State_DN : tState;

	-- Time constants for synchronization.
	constant SYNC_SQUARE_WAVE_HIGH_TIME        : integer := 50; -- 50 microseconds (50% duty cycle)
	constant SYNC_SQUARE_WAVE_PERIOD           : integer := 100; -- 100 microseconds (10 KHz clock)
	constant SYNC_SQUARE_WAVE_HIGH_TIME_CYCLES : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * real(SYNC_SQUARE_WAVE_HIGH_TIME))); -- corresponds to 50 microseconds
	constant SYNC_SQUARE_WAVE_PERIOD_CYCLES    : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * real(SYNC_SQUARE_WAVE_PERIOD))); -- corresponds to 100 microseconds
	constant SYNC_SLAVE_RESET_CYCLES           : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * 200.0)); -- corresponds to 200 microseconds (reset pulse)
	constant TS_COUNTER_INCREASE_CYCLES        : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * 1.0)); -- corresponds to 1 microsecond
	constant SYNC_SLAVE_TIMEOUT_CYCLES         : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * 10.0)); -- corresponds to 10 microseconds
	constant SYNC_SLAVE_CONFIRMATION_CYCLES    : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * real(SYNC_SQUARE_WAVE_HIGH_TIME - 1))); -- corresponds to 49 microseconds
	constant SYNC_SLAVE_WAIT_CYCLES            : integer := integer(floor(LOGIC_CLOCK_FREQ_REAL * real(SYNC_SQUARE_WAVE_PERIOD - 1))); -- corresponds to 99 microseconds

	-- Counters used to produce different timestamp ticks and to remain in a certain state
	-- for a certain amount of time. Divider keeps track of local timestamp increases,
	-- while Counter keeps track of everything else. Confirm is used to make sure, as much as
	-- possible, that when the Master sees a sync clock signal, it really is one, before
	-- becoming a Slave. This is a separate counter, because while this is going on,
	-- Divider and Counter must continue to provide their signals for Master behavior.
	constant DIVIDER_SIZE : integer := integer(ceil(log2(real(TS_COUNTER_INCREASE_CYCLES))));
	constant COUNTER_SIZE : integer := integer(ceil(log2(real(SYNC_SLAVE_RESET_CYCLES))));
	constant CONFIRM_SIZE : integer := integer(ceil(log2(real(SYNC_SLAVE_CONFIRMATION_CYCLES))));

	signal Divider_DP, Divider_DN : unsigned(DIVIDER_SIZE - 1 downto 0);
	signal Counter_DP, Counter_DN : unsigned(COUNTER_SIZE - 1 downto 0);
	signal Confirm_DP, Confirm_DN : unsigned(CONFIRM_SIZE - 1 downto 0);

	-- Register outputs.
	signal SyncOutClockReg_C   : std_logic;
	signal DeviceIsMasterReg_S : std_logic;
begin
	tsSynchronizer : process(State_DP, Divider_DP, Counter_DP, Confirm_DP, SyncInClock_CI, TimestampRun_SI, TimestampReset_SI)
	begin
		State_DN <= State_DP;

		Divider_DN <= Divider_DP;
		Counter_DN <= Counter_DP;
		Confirm_DN <= (others => '0');

		SyncOutClockReg_C <= '0';

		DeviceIsMasterReg_S <= '1';

		TimestampReset_SO <= '0';
		TimestampInc_SO   <= '0';

		case State_DP is
			when stMasterRun =>
				Divider_DN <= Divider_DP + 1;

				if Divider_DP = (TS_COUNTER_INCREASE_CYCLES - 1) then
					Divider_DN <= (others => '0');

					TimestampInc_SO <= TimestampRun_SI; -- increment local timestamp, if running
				end if;

				Counter_DN <= Counter_DP + 1;

				if Counter_DP = (SYNC_SQUARE_WAVE_PERIOD_CYCLES - 1) then
					Counter_DN <= (others => '0');
					Divider_DN <= (others => '0');
				end if;

				if Counter_DP < SYNC_SQUARE_WAVE_HIGH_TIME_CYCLES then
					SyncOutClockReg_C <= '0';
				else
					SyncOutClockReg_C <= '1';
				end if;

				if TimestampReset_SI = '1' then
					Divider_DN <= (others => '0');
					Counter_DN <= (others => '0');

					State_DN <= stMasterResetSlaves;
				elsif SyncInClock_CI = '0' then
					Confirm_DN <= Confirm_DP + 1;

					if Confirm_DP = (SYNC_SLAVE_CONFIRMATION_CYCLES - 1) then
						Confirm_DN <= (others => '0');
						Divider_DN <= (others => '0');
						Counter_DN <= (others => '0');

						-- Not a master if getting 0 on its input, so a slave.
						State_DN <= stSlaveRun;

						TimestampReset_SO <= '1';
					end if;
				end if;

			when stMasterResetSlaves =>
				-- Reset slaves by generating at least a 200 microsecond high on output, which slaves should detect.
				SyncOutClockReg_C <= '1';

				Counter_DN <= Counter_DP + 1;

				if Counter_DP = (SYNC_SLAVE_RESET_CYCLES - 1) then
					Counter_DN <= (others => '0');

					State_DN <= stMasterRun;

					TimestampReset_SO <= '1';
				end if;

			when stSlaveRun =>
				DeviceIsMasterReg_S <= '0';

				SyncOutClockReg_C <= SyncInClock_CI;
				TimestampReset_SO <= TimestampReset_SI;

				Divider_DN <= Divider_DP + 1;

				if Divider_DP = (TS_COUNTER_INCREASE_CYCLES - 1) then
					Divider_DN <= (others => '0');

					TimestampInc_SO <= TimestampRun_SI; -- increment local timestamp, if running
				end if;

				Counter_DN <= Counter_DP + 1;

				if Counter_DP = (SYNC_SLAVE_WAIT_CYCLES - 1) then
					Counter_DN <= (others => '0');
					Divider_DN <= (others => '0');

					State_DN <= stSlaveWaitEdge;
				end if;

			when stSlaveWaitEdge =>
				DeviceIsMasterReg_S <= '0';

				SyncOutClockReg_C <= SyncInClock_CI;
				TimestampReset_SO <= TimestampReset_SI;

				Counter_DN <= Counter_DP + 1;

				if Counter_DP = (SYNC_SLAVE_TIMEOUT_CYCLES - 1) then
					Counter_DN <= (others => '0');

					-- No acknowledgement from master. Either resetting timestamps or
					-- lost connection, in which case, become master.
					State_DN <= stStlaveWaitReset;
				elsif SyncInClock_CI = '0' then
					Counter_DN <= (others => '0');

					State_DN <= stSlaveRun;

					TimestampInc_SO <= TimestampRun_SI; -- increment local timestamp, if running
				end if;

			when stStlaveWaitReset =>
				DeviceIsMasterReg_S <= '0';

				SyncOutClockReg_C <= SyncInClock_CI;

				Counter_DN <= Counter_DP + 1;

				if SyncInClock_CI = '0' then
					-- Slave TS reset from master.
					Counter_DN <= (others => '0');

					State_DN <= stSlaveRun;

					TimestampReset_SO <= '1';
				elsif Counter_DP = (SYNC_SLAVE_RESET_CYCLES - 1) then
					-- Lost connection, become master (after making sure that it's not just a reset).
					Counter_DN <= (others => '0');

					State_DN <= stMasterRun;

					TimestampReset_SO <= '1';
				end if;
		end case;
	end process tsSynchronizer;

	registerUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then
			State_DP <= stMasterRun;

			Divider_DP <= (others => '0');
			Counter_DP <= (others => '0');
			Confirm_DP <= (others => '0');

			SyncOutClock_CO <= '0';

			DeviceIsMaster_SO <= '1';
		elsif rising_edge(Clock_CI) then -- rising clock edge
			State_DP <= State_DN;

			Divider_DP <= Divider_DN;
			Counter_DP <= Counter_DN;
			Confirm_DP <= Confirm_DN;

			SyncOutClock_CO <= SyncOutClockReg_C;

			DeviceIsMaster_SO <= DeviceIsMasterReg_S;
		end if;
	end process registerUpdate;
end architecture Behavioral;
