library ieee;
use ieee.std_logic_1164.all;

entity ClockDomainGenerator is
	generic(
		CLOCK_FREQ     : integer;
		OUT_CLOCK_FREQ : integer);
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;
		NewClock_CO     : out std_logic;
		NewClockHalf_CO : out std_logic;
		NewReset_RO     : out std_logic);
end ClockDomainGenerator;

architecture Behavioral of ClockDomainGenerator is
	signal PLLClock_C  : std_logic;
	signal PLLLock_S   : std_logic;
	signal SyncReset_R : std_logic;
begin
	pll : entity work.PLL
		generic map(
			CLOCK_FREQ     => CLOCK_FREQ,
			OUT_CLOCK_FREQ => OUT_CLOCK_FREQ)
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			OutClock_CO     => PLLClock_C,
			OutClockHalf_CO => NewClockHalf_CO,
			PLLLock_SO      => PLLLock_S);

	resetSync : entity work.ResetSynchronizer
		port map(
			ExtClock_CI  => PLLClock_C,
			ExtReset_RI  => Reset_RI or not PLLLock_S,
			SyncReset_RO => SyncReset_R);

	-- Only release Reset when PLL is locked.
	NewReset_RO <= SyncReset_R;

	NewClock_CO <= PLLClock_C;
end Behavioral;
