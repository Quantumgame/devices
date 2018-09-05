library ieee;
use ieee.std_logic_1164.all;
use work.Functions.BooleanToStdLogic;
use work.FIFORecords.all;

-- Split a FIFO into two FIFOs. This is accomplished by taking data,
-- when available, from the input FIFO, and forwarding it directly to
-- the output FIFOs, which may accept the data if they do have available
-- space. If not, the data is not copied to that particular output FIFO.
-- The FIFO_GUARANTEE_DELIVERY flag can be used to force the splitter to
-- wait if one of the FIFOs can't accept the current data, therefore
-- guaranteeing delivery of all data packets to both FIFOs. When using it,
-- please make sure that the ALMOST_FULL_FLAG equals 2 for the output FIFOs.
entity FifoSplitter is
	generic(
		FIFO_WIDTH              : integer;
		FIFO_GUARANTEE_DELIVERY : boolean := false);
	port(
		Clock_CI           : in  std_logic;
		Reset_RI           : in  std_logic;

		FifoInControl_SI   : in  tFromFifoReadSide;
		FifoInControl_SO   : out tToFifoReadSide;
		FifoInData_DI      : in  std_logic_vector(FIFO_WIDTH - 1 downto 0);

		FifoOut1Enable_SI  : in  std_logic;
		FifoOut1Control_SI : in  tFromFifoWriteSide;
		FifoOut1Control_SO : out tToFifoWriteSide;
		FifoOut1Data_DO    : out std_logic_vector(FIFO_WIDTH - 1 downto 0);

		FifoOut2Enable_SI  : in  std_logic;
		FifoOut2Control_SI : in  tFromFifoWriteSide;
		FifoOut2Control_SO : out tToFifoWriteSide;
		FifoOut2Data_DO    : out std_logic_vector(FIFO_WIDTH - 1 downto 0));
end entity FifoSplitter;

architecture Behavioral of FifoSplitter is
	signal Fifo1Ready_S : std_logic;
	signal Fifo2Ready_S : std_logic;
	signal FifosReady_S : std_logic;

	signal FifoInNotEmpty_S : std_logic;

	signal WriteDelayReg_S : std_logic;
begin
	-- FIFOs are ready when they are either not full, or also when they are not enabled,
	-- so that the whole guarantee mechanism doesn't get stuck when a full FIFO is disabled.
	Fifo1Ready_S <= not FifoOut1Control_SI.AlmostFull_S or not FifoOut1Enable_SI;
	Fifo2Ready_S <= not FifoOut2Control_SI.AlmostFull_S or not FifoOut2Enable_SI;
	FifosReady_S <= not BooleanToStdLogic(FIFO_GUARANTEE_DELIVERY) or (Fifo1Ready_S and Fifo2Ready_S);

	FifoInNotEmpty_S <= not FifoInControl_SI.Empty_S;

	FifoInControl_SO.Read_S <= FifoInNotEmpty_S and FifosReady_S;

	registerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			WriteDelayReg_S <= '0';
		elsif rising_edge(Clock_CI) then -- rising clock edge
			WriteDelayReg_S <= FifoInNotEmpty_S and FifosReady_S;
		end if;
	end process registerUpdate;

	FifoOut1Control_SO.Write_S <= WriteDelayReg_S and not FifoOut1Control_SI.Full_S and FifoOut1Enable_SI;
	FifoOut2Control_SO.Write_S <= WriteDelayReg_S and not FifoOut2Control_SI.Full_S and FifoOut2Enable_SI;
	FifoOut1Data_DO            <= FifoInData_DI;
	FifoOut2Data_DO            <= FifoInData_DI;
end architecture Behavioral;
