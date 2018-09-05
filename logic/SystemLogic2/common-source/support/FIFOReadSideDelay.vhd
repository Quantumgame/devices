library ieee;
use ieee.std_logic_1164.all;
use work.FIFORecords.all;

entity FIFOReadSideDelay is
	generic(
		DATA_WIDTH : integer);
	port(
		Clock_CI          : in  std_logic;
		Reset_RI          : in  std_logic;
		InFifoControl_SI  : in  tFromFifoReadSide;
		InFifoControl_SO  : out tToFifoReadSide;
		OutFifoControl_SI : in  tToFifoReadSide;
		OutFifoControl_SO : out tFromFifoReadSide;
		FifoData_DI       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		FifoData_DO       : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity FIFOReadSideDelay;

architecture Structural of FIFOReadSideDelay is
	attribute syn_enum_encoding : string;

	type tState is (stInit, stGetData, stWaitRead);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- present and next state
	signal State_DP, State_DN : tState;

	signal DataInRegEnable_S : std_logic;

	signal EmptyReg_S       : std_logic;
	signal AlmostEmptyReg_S : std_logic;
begin
	readSideOutputsRegisteringLogic : process(State_DP, InFifoControl_SI, OutFifoControl_SI)
	begin
		State_DN <= State_DP;

		EmptyReg_S       <= '1';
		AlmostEmptyReg_S <= '1';

		DataInRegEnable_S       <= '0';
		InFifoControl_SO.Read_S <= '0';

		case State_DP is
			when stInit =>
				if InFifoControl_SI.Empty_S = '0' then
					InFifoControl_SO.Read_S <= '1';
					EmptyReg_S              <= '0';
					AlmostEmptyReg_S        <= InFifoControl_SI.AlmostEmpty_S;
					State_DN                <= stGetData;
				end if;

			when stGetData =>
				DataInRegEnable_S <= '1';

				if OutFifoControl_SI.Read_S = '1' then
					if InFifoControl_SI.Empty_S = '0' then
						InFifoControl_SO.Read_S <= '1';
						EmptyReg_S              <= '0';
						AlmostEmptyReg_S        <= InFifoControl_SI.AlmostEmpty_S;
					else
						State_DN <= stInit;
					end if;
				else
					EmptyReg_S       <= '0';
					AlmostEmptyReg_S <= InFifoControl_SI.AlmostEmpty_S;
					State_DN         <= stWaitRead;
				end if;

			when stWaitRead =>
				if OutFifoControl_SI.Read_S = '1' then
					if InFifoControl_SI.Empty_S = '0' then
						InFifoControl_SO.Read_S <= '1';
						EmptyReg_S              <= '0';
						AlmostEmptyReg_S        <= InFifoControl_SI.AlmostEmpty_S;
						State_DN                <= stGetData;
					else
						State_DN <= stInit;
					end if;
				else
					EmptyReg_S       <= '0';
					AlmostEmptyReg_S <= InFifoControl_SI.AlmostEmpty_S;
				end if;

			when others => null;
		end case;
	end process readSideOutputsRegisteringLogic;

	registerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			State_DP <= stInit;

			OutFifoControl_SO.Empty_S       <= '1';
			OutFifoControl_SO.AlmostEmpty_S <= '1';

			FifoData_DO <= (others => '0');
		elsif rising_edge(Clock_CI) then -- rising clock edge
			State_DP <= State_DN;

			OutFifoControl_SO.Empty_S       <= EmptyReg_S;
			OutFifoControl_SO.AlmostEmpty_S <= AlmostEmptyReg_S;

			if DataInRegEnable_S = '1' then
				FifoData_DO <= FifoData_DI;
			end if;
		end if;
	end process registerUpdate;
end architecture Structural;
