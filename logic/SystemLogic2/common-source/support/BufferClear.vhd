library ieee;
use ieee.std_logic_1164.all;

-- Detect when InputSignal_SI changes (polarity of change is configurable),
-- and then emit an active-high signal on OutputSignal_SO on the next clock cycle
-- to notify a listener of this change. Until the listener manually clears this by
-- pulsing Clear_SI, the output signal will continue to be emitted regardless of
-- the input signal changing state again.
-- If both an input and a clear signal come in during the same clock cycle,
-- the input wins and the change signal is emitted. This is to avoid ever loosing
-- changes and their subsequent notification, if they happen to coincide
-- with an acknowledgement (clear) from outside.
entity BufferClear is
	generic(
		INPUT_SIGNAL_POLARITY : std_logic := '1');
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;
		Clear_SI        : in  std_logic;
		InputSignal_SI  : in  std_logic;
		OutputSignal_SO : out std_logic);
end entity BufferClear;

architecture Behavioral of BufferClear is
	signal Memory_SP, Memory_SN : std_logic;
begin
	detectChange : process(Memory_SP, InputSignal_SI, Clear_SI)
	begin
		Memory_SN <= Memory_SP;

		if InputSignal_SI = INPUT_SIGNAL_POLARITY then
			Memory_SN <= '1';
		elsif Clear_SI = '1' then
			Memory_SN <= '0';
		end if;
	end process detectChange;

	-- Change state on clock edge (synchronous).
	registerUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			Memory_SP <= '0';
		elsif rising_edge(Clock_CI) then
			Memory_SP <= Memory_SN;
		end if;
	end process registerUpdate;

	-- Direct flip-flop output outside.
	OutputSignal_SO <= Memory_SP;
end architecture Behavioral;
