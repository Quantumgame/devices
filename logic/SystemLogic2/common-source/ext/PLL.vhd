library ieee;
use ieee.std_logic_1164.all;
use work.Settings.DEVICE_FAMILY;

entity PLL is
	generic(
		CLOCK_FREQ     : integer;
		OUT_CLOCK_FREQ : integer;
		PHASE_ADJUST   : integer := 0);
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;
		OutClock_CO     : out std_logic;
		OutClockHalf_CO : out std_logic;
		PLLLock_SO      : out std_logic);
end entity PLL;

architecture Structural of PLL is
	signal OutClock_C : std_logic;
begin
	pll : component work.pmi_components.pmi_pll
		generic map(
			pmi_freq_clki    => CLOCK_FREQ,
			pmi_freq_clkfb   => OUT_CLOCK_FREQ,
			pmi_freq_clkop   => OUT_CLOCK_FREQ,
			pmi_freq_clkos   => OUT_CLOCK_FREQ / 2,
			pmi_freq_clkok   => OUT_CLOCK_FREQ,
			pmi_family       => DEVICE_FAMILY,
			pmi_phase_adj    => PHASE_ADJUST,
			pmi_duty_cycle   => 50,
			pmi_clkfb_source => "CLKOP",
			pmi_fdel         => "off",
			pmi_fdel_val     => 0)
		port map(
			CLKI   => Clock_CI,
			CLKFB  => OutClock_C,
			RESET  => Reset_RI,
			CLKOP  => OutClock_C,
			CLKOS  => OutClockHalf_CO,
			CLKOK  => open,
			CLKOK2 => open,
			LOCK   => PLLLock_SO);

	OutClock_CO <= OutClock_C;
end architecture Structural;
