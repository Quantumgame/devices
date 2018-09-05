library ieee;
use ieee.std_logic_1164.all;
use work.FIFORecords.all;

-- Merge two FIFOs into one FIFO. This is accomplished by taking data,
-- when available, from the input FIFOs, and forwarding it directly to
-- the output FIFO, which may accept the data if it does have available
-- space. If not, it will wait until available space in output FIFO.
-- The two input FIFOs use a balanced arbitration scheme.
-- Please make sure that the ALMOST_FULL_FLAG equals 2 for the output FIFO.
entity FifoMerger is
	generic(
		FIFO_WIDTH : integer);
	port(
		Clock_CI          : in  std_logic;
		Reset_RI          : in  std_logic;

		FifoIn1Control_SI : in  tFromFifoReadSide;
		FifoIn1Control_SO : out tToFifoReadSide;
		FifoIn1Data_DI    : in  std_logic_vector(FIFO_WIDTH - 1 downto 0);

		FifoIn2Control_SI : in  tFromFifoReadSide;
		FifoIn2Control_SO : out tToFifoReadSide;
		FifoIn2Data_DI    : in  std_logic_vector(FIFO_WIDTH - 1 downto 0);

		FifoOutControl_SI : in  tFromFifoWriteSide;
		FifoOutControl_SO : out tToFifoWriteSide;
		FifoOutData_DO    : out std_logic_vector(FIFO_WIDTH - 1 downto 0));
end entity FifoMerger;

architecture Behavioral of FifoMerger is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stFIFO1, stFIFO2);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- present and next state
	signal State_DP, State_DN : tState;

	signal ArbiterPriority_SP, ArbiterPriority_SN : std_logic;

	signal FifoOutWriteReg_S : std_logic;
	signal FifoOutDataReg_D  : std_logic_vector(FIFO_WIDTH - 1 downto 0);
begin
	SM_comb : process(State_DP, ArbiterPriority_SP, FifoIn1Control_SI, FifoIn2Control_SI, FifoOutControl_SI, FifoIn1Data_DI, FifoIn2Data_DI)
	begin
		State_DN           <= State_DP;
		ArbiterPriority_SN <= ArbiterPriority_SP;

		FifoOutWriteReg_S <= '0';
		FifoOutDataReg_D  <= (others => '0');

		FifoIn1Control_SO.Read_S <= '0';
		FifoIn2Control_SO.Read_S <= '0';

		case State_DP is
			when stIdle =>
				if FifoOutControl_SI.AlmostFull_S = '0' then
					if FifoIn1Control_SI.Empty_S = '0' and FifoIn2Control_SI.Empty_S = '1' then
						State_DN <= stFIFO1;
					elsif FifoIn1Control_SI.Empty_S = '1' and FifoIn2Control_SI.Empty_S = '0' then
						State_DN <= stFIFO2;
					elsif FifoIn1Control_SI.Empty_S = '0' and FifoIn2Control_SI.Empty_S = '0' then
						if ArbiterPriority_SP = '0' then
							State_DN <= stFIFO1;
						else
							State_DN <= stFIFO2;
						end if;
					end if;
				end if;

			when stFIFO1 =>
				ArbiterPriority_SN       <= '1';
				FifoIn1Control_SO.Read_S <= '1';

				FifoOutWriteReg_S <= '1';
				FifoOutDataReg_D  <= FifoIn1Data_DI;

				State_DN <= stIdle;

			when stFIFO2 =>
				ArbiterPriority_SN       <= '0';
				FifoIn2Control_SO.Read_S <= '1';

				FifoOutWriteReg_S <= '1';
				FifoOutDataReg_D  <= FifoIn2Data_DI;

				State_DN <= stIdle;

			when others => null;
		end case;
	end process SM_comb;

	SM_seq : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			State_DP           <= stIdle;
			ArbiterPriority_SP <= '0';

			FifoOutControl_SO.Write_S <= '0';
			FifoOutData_DO            <= (others => '0');
		elsif rising_edge(Clock_CI) then -- rising clock edge
			State_DP           <= State_DN;
			ArbiterPriority_SP <= ArbiterPriority_SN;

			FifoOutControl_SO.Write_S <= FifoOutWriteReg_S;
			FifoOutData_DO            <= FifoOutDataReg_D;
		end if;
	end process SM_seq;
end architecture Behavioral;
