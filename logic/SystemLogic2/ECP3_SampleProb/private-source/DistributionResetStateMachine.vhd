library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.EventCodes.all;
use work.FIFORecords.all;
use work.SampleProbChipBiasConfigRecords.CHANNEL_NUMBER;
use work.SampleProbChipBiasConfigRecords.CHANNEL_NUMBER_SIZE;

entity DistributionResetStateMachine is
	port(
		Clock_CI             : in  std_logic;
		Reset_RI             : in  std_logic;

		-- Fifo output (to Mux)
		OutFifoEnable_SI     : in  std_logic;
		OutFifoControl_SI    : in  tFromFifoWriteSide;
		OutFifoControl_SO    : out tToFifoWriteSide;
		OutFifoData_DO       : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		-- Fifo input (from AER)
		InFifoControl_SI     : in  tFromFifoReadSide;
		InFifoControl_SO     : out tToFifoReadSide;
		InFifoData_DI        : in  std_logic_vector(EVENT_WIDTH - 1 downto 0);

		-- Reset distribution after spike signals.
		DistributionReset_SO : out std_logic_vector(CHANNEL_NUMBER - 1 downto 0));
end entity DistributionResetStateMachine;

architecture Behavioral of DistributionResetStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stForward);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- present and next state
	signal State_DP, State_DN : tState;

	signal FifoOutReady_S : std_logic;
	signal FifoInReady_S  : std_logic;
begin
	-- Forward elements 1:1 between the IN and OUT FIFOs. Do not lose elements, block if full!
	FifoOutReady_S <= not OutFifoControl_SI.AlmostFull_S;
	FifoInReady_S  <= not InFifoControl_SI.Empty_S;

	resetComb : process(State_DP, FifoInReady_S, FifoOutReady_S, InFifoData_DI, OutFifoEnable_SI)
	begin
		State_DN <= State_DP;           -- Keep current state by default.

		OutFifoData_DO            <= (others => '0');
		OutFifoControl_SO.Write_S <= '0';

		InFifoControl_SO.Read_S <= '0';

		-- If FIFO is disabled (AER reset), reset also all distributions. This guarantees a correct startup.
		DistributionReset_SO <= (others => '1');

		case State_DP is
			when stIdle =>
				if OutFifoEnable_SI = '1' then
					DistributionReset_SO <= (others => '0');

					if FifoInReady_S = '1' and FifoOutReady_S = '1' then
						State_DN <= stForward;
					end if;
				end if;

			when stForward =>
				OutFifoData_DO            <= InFifoData_DI;
				OutFifoControl_SO.Write_S <= '1';

				InFifoControl_SO.Read_S <= '1';

				State_DN <= stIdle;

				-- Signal reset of distribution.
				with InFifoData_DI(CHANNEL_NUMBER_SIZE - 1 downto 0) select DistributionReset_SO <=
					(0 => '1', others => '0') when "0000",
					(1 => '1', others => '0') when "0001",
					(2 => '1', others => '0') when "0010",
					(3 => '1', others => '0') when "0011",
					(4 => '1', others => '0') when "0100",
					(5 => '1', others => '0') when "0101",
					(6 => '1', others => '0') when "0110",
					(7 => '1', others => '0') when "0111",
					(8 => '1', others => '0') when "1000",
					(9 => '1', others => '0') when "1001",
					(10 => '1', others => '0') when "1010",
					(11 => '1', others => '0') when "1011",
					(12 => '1', others => '0') when "1100",
					(13 => '1', others => '0') when "1101",
					(14 => '1', others => '0') when "1110",
					(15 => '1', others => '0') when "1111",
					(others => '0') when others;

			when others => null;
		end case;
	end process resetComb;

	registerUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			State_DP <= stIdle;
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;
		end if;
	end process registerUpdate;
end architecture Behavioral;
