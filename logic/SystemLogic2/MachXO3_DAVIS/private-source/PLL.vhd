library ieee;
use ieee.std_logic_1164.all;

entity PLL is
	generic(
		CLOCK_FREQ     : integer;
		OUT_CLOCK_FREQ : integer);
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;
		OutClock_CO     : out std_logic;
		OutClockHalf_CO : out std_logic;
		PLLLock_SO      : out std_logic);
end entity PLL;

architecture Structural of PLL is
	component pll_100 is
		port(
			CLKI  : in  std_logic;
			RST   : in  std_logic;
			CLKOP : out std_logic;
			LOCK  : out std_logic);
	end component pll_100;

	component pll_60 is
		port(
			CLKI  : in  std_logic;
			RST   : in  std_logic;
			CLKOP : out std_logic;
			LOCK  : out std_logic);
	end component pll_60;
begin
	assert (CLOCK_FREQ = 80) report "PLL input on MachXO3 is hard-coded to 80 MHz." severity FAILURE;
	assert (OUT_CLOCK_FREQ = 100 or OUT_CLOCK_FREQ = 60) report "PLL output on MachXO3 is hard-coded to 100 MHz (logic) or 60 MHz (ADC)." severity FAILURE;

	OutClockHalf_CO <= '0';

	logicPLL : if OUT_CLOCK_FREQ = 100 generate
	begin
		pll100 : pll_100
			port map(
				CLKI  => Clock_CI,
				RST   => Reset_RI,
				CLKOP => OutClock_CO,
				LOCK  => PLLLock_SO);
	end generate logicPLL;

	adcPLL : if OUT_CLOCK_FREQ = 60 generate
	begin
		pll60 : pll_60
			port map(
				CLKI  => Clock_CI,
				RST   => Reset_RI,
				CLKOP => OutClock_CO,
				LOCK  => PLLLock_SO);
	end generate adcPLL;
end architecture Structural;
