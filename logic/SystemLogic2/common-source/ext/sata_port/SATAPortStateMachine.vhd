library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Functions.BooleanToStdLogic;
use work.FIFORecords.all;
use work.SATAPortConfigRecords.all;

entity SATAPortStateMachine is
	port(
		Clock_CI                                   : in  std_logic;
		Reset_RI                                   : in  std_logic;

		PCSTXData_DO                               : out std_logic_vector(7 downto 0);
		PCSTXIsK_SO                                : out std_logic;
		PCSRXData_DI                               : in  std_logic_vector(7 downto 0);
		PCSRXIsK_SI                                : in  std_logic;

		PCSDisparityError_SI                       : in  std_logic;
		PCSCodeViolationError_SI                   : in  std_logic;
		PCSLossOfSignal_SI                         : in  std_logic;
		PCSEnableWordAlign_SO                      : out std_logic;
		PCSClockToleranceCompensationUnderrun_SI   : in  std_logic;
		PCSClockToleranceCompensationOverrun_SI    : in  std_logic;
		PCSClockToleranceCompensationSKInserted_SI : in  std_logic;
		PCSClockToleranceCompensationSKDeleted_SI  : in  std_logic;
		PCSLossOfRXCDRLock_SI                      : in  std_logic;
		PCSLossOfTXPLLLock_SI                      : in  std_logic;

		TXFIFOData_DI                              : in  std_logic_vector(35 downto 0);
		TXFIFOStatus_SI                            : in  tFromFifoReadSide;
		TXFIFOControl_SO                           : out tToFifoReadSide;

		RXFIFOData_DO                              : out std_logic_vector(35 downto 0);
		RXFIFOStatus_SI                            : in  tFromFifoWriteSide;
		RXFIFOControl_SO                           : out tToFifoWriteSide;

		-- Configuration input and output.
		SATAPortConfigIn_DI                        : in  tSATAPortConfigIn;
		SATAPortConfigOut_DO                       : out tSATAPortConfigOut);
end SATAPortStateMachine;

architecture Behavioral of SATAPortStateMachine is
	-- Sync config to new clock domain! In both directions.
	signal SATAPortConfigInSyncReg_D, SATAPortConfigInReg_D   : tSATAPortConfigIn;
	signal SATAPortConfigOutSyncReg_D, SATAPortConfigOutReg_D : tSATAPortConfigOut;

	-- Communication protocol version. Both devices must have the same to work together.
	constant PROTOCOL_VERSION : unsigned(7 downto 0) := to_unsigned(3, 8);

	constant CLOCKCORRECT_INSERT_COUNT_SIZE   : integer := tSATAPortConfigIn.ClockCorrectionInterval_D'length;
	constant HANDSHAKE_CONSECUTIVE_COUNT_SIZE : integer := tSATAPortConfigIn.HandshakeConsecutiveNeeded_D'length;

	-- K-Characters (control characters)
	-- 8b/10b K28.0: Used for clock correction. A clock correction sequence consists of four of these.
	constant KCHAR_CLOCKCORRECT : std_logic_vector(7 downto 0) := x"1C";

	-- Determine if byte is part of the clock correction sequence.
	function SymbolIsClockCorrection(SYMBOL : in std_logic_vector(7 downto 0); ISKCHAR : in std_logic) return boolean is
	begin
		return (SYMBOL = KCHAR_CLOCKCORRECT and ISKCHAR = '1');
	end function SymbolIsClockCorrection;

	-- 8b/10b K28.5: Commma symbol used to ensure byte-alignment.
	constant KCHAR_COMMA      : std_logic_vector(7 downto 0) := x"BC";
	-- 8b/10b K28.1: Alternative comma symbol #1.
	constant KCHAR_COMMA_ALT1 : std_logic_vector(7 downto 0) := x"3C";
	-- 8b/10b K28.7: Alternative comma symbol #2.
	constant KCHAR_COMMA_ALT2 : std_logic_vector(7 downto 0) := x"FC";

	-- Determine if byte is any of the possible comma symbols.
	function SymbolIsComma(SYMBOL : in std_logic_vector(7 downto 0); ISKCHAR : in std_logic) return boolean is
	begin
		return ((SYMBOL = KCHAR_COMMA or SYMBOL = KCHAR_COMMA_ALT1 or SYMBOL = KCHAR_COMMA_ALT2) and ISKCHAR = '1');
	end function SymbolIsComma;

	-- 8b/10b K28.2: Used within the handshake phase to uniquely identify the handshake words.
	constant KCHAR_HANDSHAKE : std_logic_vector(7 downto 0) := x"5C";

	function WordIsHandshake(WORD : in std_logic_vector(31 downto 0); ISKCHAR : in std_logic_vector(3 downto 0)) return boolean is
	begin
		return (WORD(31 downto 24) = KCHAR_COMMA and WORD(23 downto 16) = KCHAR_HANDSHAKE and ISKCHAR = "1100");
	end function WordIsHandshake;

	-- 8b/10b K28.5 then K27.7: Used for "idle" frames sent across the link (bottom 16 bits of the frame may be arbitrary data).
	constant KCHAR_IDLE : std_logic_vector(7 downto 0) := x"FB";

	function WordIsIdle(WORD : in std_logic_vector(31 downto 0); ISKCHAR : in std_logic_vector(3 downto 0); IDLEDATA : in std_logic_vector(15 downto 0)) return boolean is
	begin
		return (WORD(31 downto 24) = KCHAR_COMMA and WORD(23 downto 16) = KCHAR_IDLE and WORD(15 downto 0) = IDLEDATA and ISKCHAR = "1100");
	end function WordIsIdle;

	attribute syn_enum_encoding : string;

	-- Transmit SM states.
	type tTXState is (stSendStart, stSendClockCorrection2, stSendClockCorrection3, stSendClockCorrection4, stSendHandshake2, stSendHandshake3, stSendHandshake4, stSendData2, stSendData3, stSendData4, stSendIdle2, stSendIdle3, stSendIdle4);
	attribute syn_enum_encoding of tTXState : type is "onehot";

	-- Present and next state for TX side.
	signal TXState_DP, TXState_DN : tTXState;

	-- TX side output registers to PCS.
	signal TXDataReg_D : std_logic_vector(7 downto 0);
	signal TXIsKReg_S  : std_logic;

	signal TXOnline_S : std_logic;

	-- Clock correction counter control.
	signal SendClockCorrection_S  : std_logic;
	signal ClockCorrectionCount_S : std_logic;
	signal ClockCorrectionClear_S : std_logic;

	-- RX side input registers from PCS.
	signal RXDataReg_D : std_logic_vector(7 downto 0);
	signal RXIsKReg_S  : std_logic;

	signal RXOnline_S    : std_logic;
	signal RXValidData_S : std_logic;

	-- External LinkStateMachine support, to signal sync and ready.
	signal PCSLossOfSync_S : std_logic;

	-- Handshake information.
	signal HandshakeComplete_SP, HandshakeComplete_SN               : std_logic;
	signal HandshakePhase_DP, HandshakePhase_DN                     : std_logic; -- 1 bit to keep handshake phase.
	signal HandshakeVersionMismatch_SP, HandshakeVersionMismatch_SN : std_logic;

	-- Consecutive handshake counter control.
	signal HandshakeConsecutiveClear_S : std_logic;
	signal HandshakeConsecutiveCount_S : std_logic;
	signal GotConsecutiveHandshake_S   : std_logic;

	-- Debug and info counters.
	signal PCSLossOfSignalCount_S, PCSLossOfRXCDRLockCount_S, PCSLossOfTXPLLLockCount_S, PCSLossOfSyncCount_S : std_logic;
	signal PCSClockToleranceCompensationOverrunCount_S, PCSClockToleranceCompensationUnderrunCount_S          : std_logic;
	signal PCSClockToleranceCompensationSKInsertedCount_S, PCSClockToleranceCompensationSKDeletedCount_S      : std_logic;
	signal TXClockCorrectionCount_S, TXHandshakeCount_S, TXDataCount_S, TXIdleCount_S                         : std_logic;
	signal RXSymbolsCount_S, RXClockCorrectionSymbolsCount_S, RXCommaSymbolsCount_S, RXDataWordsCount_S       : std_logic;
	signal RXDataHandshakeCount_S, RXDataIdleCount_S, RXDataDataCount_S                                       : std_logic;
	signal RXDataDroppedCount_S, HandshakeResetCountCount_S                                                   : std_logic;

	-- Receive data alignment to comma.
	signal RXCommaAligned_SP, RXCommaAligned_SN : std_logic;
	signal RXAlignment_DP, RXAlignment_DN       : std_logic_vector(1 downto 0);

	-- Received data word reconstruction.
	signal RXWordData_DP, RXWordData_DN   : std_logic_vector(31 downto 0);
	signal RXWordIsK_SP, RXWordIsK_SN     : std_logic_vector(3 downto 0);
	signal RXWordValid_SP, RXWordValid_SN : std_logic;

	-- Output RX FIFO registers.
	signal RXFIFODataReg_D  : std_logic_vector(35 downto 0);
	signal RXFIFOWriteReg_S : std_logic;
begin
	-- PCS debug/statistics counters and signals.
	SATAPortConfigOutReg_D.PCSLossOfSignal_D <= PCSLossOfSignal_SI;

	PCSLossOfSignalCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSLossOfSignal_SI,
			RisingEdgeDetected_SO  => PCSLossOfSignalCount_S,
			FallingEdgeDetected_SO => open);

	PCSLossOfSignalCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSLossOfSignalCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSLossOfSignalCount_D);

	SATAPortConfigOutReg_D.PCSLossOfRXCDRLock_D <= PCSLossOfRXCDRLock_SI;

	PCSLossOfRXCDRLockCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSLossOfRXCDRLock_SI,
			RisingEdgeDetected_SO  => PCSLossOfRXCDRLockCount_S,
			FallingEdgeDetected_SO => open);

	PCSLossOfRXCDRLockCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSLossOfRXCDRLockCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSLossOfRXCDRLockCount_D);

	SATAPortConfigOutReg_D.PCSLossOfTXPLLLock_D <= PCSLossOfTXPLLLock_SI;

	PCSLossOfTXPLLLockCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSLossOfTXPLLLock_SI,
			RisingEdgeDetected_SO  => PCSLossOfTXPLLLockCount_S,
			FallingEdgeDetected_SO => open);

	PCSLossOfTXPLLLockCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSLossOfTXPLLLockCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSLossOfTXPLLLockCount_D);

	SATAPortConfigOutReg_D.PCSLossOfSync_D <= PCSLossOfSync_S;

	PCSLossOfSyncCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSLossOfSync_S,
			RisingEdgeDetected_SO  => PCSLossOfSyncCount_S,
			FallingEdgeDetected_SO => open);

	PCSLossOfSyncCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSLossOfSyncCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSLossOfSyncCount_D);

	-- CTC debug counters.
	PCSClockToleranceCompensationUnderrunCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSClockToleranceCompensationUnderrun_SI,
			RisingEdgeDetected_SO  => PCSClockToleranceCompensationUnderrunCount_S,
			FallingEdgeDetected_SO => open);

	PCSClockToleranceCompensationUnderrunCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSClockToleranceCompensationUnderrunCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSClockToleranceCompensationUnderrun_D);

	PCSClockToleranceCompensationOverrunCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSClockToleranceCompensationOverrun_SI,
			RisingEdgeDetected_SO  => PCSClockToleranceCompensationOverrunCount_S,
			FallingEdgeDetected_SO => open);

	PCSClockToleranceCompensationOverrunCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSClockToleranceCompensationOverrunCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSClockToleranceCompensationOverrun_D);

	PCSClockToleranceCompensationSKInsertedCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSClockToleranceCompensationSKInserted_SI,
			RisingEdgeDetected_SO  => PCSClockToleranceCompensationSKInsertedCount_S,
			FallingEdgeDetected_SO => open);

	PCSClockToleranceCompensationSKInsertedCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSClockToleranceCompensationSKInsertedCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSClockToleranceCompensationSKInserted_D);

	PCSClockToleranceCompensationSKDeletedCountDetector : entity work.EdgeDetector
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => PCSClockToleranceCompensationSKDeleted_SI,
			RisingEdgeDetected_SO  => PCSClockToleranceCompensationSKDeletedCount_S,
			FallingEdgeDetected_SO => open);

	PCSClockToleranceCompensationSKDeletedCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => PCSClockToleranceCompensationSKDeletedCount_S,
			Data_DO      => SATAPortConfigOutReg_D.PCSClockToleranceCompensationSKDeleted_D);

	-- TX debug counters.
	TXClockCorrectionCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not TXOnline_S,
			Enable_SI    => TXClockCorrectionCount_S,
			Data_DO      => SATAPortConfigOutReg_D.TXClockCorrection_D);

	TXHandshakeCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not TXOnline_S,
			Enable_SI    => TXHandshakeCount_S,
			Data_DO      => SATAPortConfigOutReg_D.TXHandshake_D);

	TXDataCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not TXOnline_S,
			Enable_SI    => TXDataCount_S,
			Data_DO      => SATAPortConfigOutReg_D.TXData_D);

	TXIdleCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not TXOnline_S,
			Enable_SI    => TXIdleCount_S,
			Data_DO      => SATAPortConfigOutReg_D.TXIdle_D);

	clockCorrectionCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => CLOCKCORRECT_INSERT_COUNT_SIZE,
			RESET_ON_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => ClockCorrectionClear_S,
			Enable_SI    => ClockCorrectionCount_S,
			DataLimit_DI => SATAPortConfigInReg_D.ClockCorrectionInterval_D,
			Overflow_SO  => SendClockCorrection_S,
			Data_DO      => open);

	TXOnline_S <= not PCSLossOfTXPLLLock_SI;

	txStateMachine : process(TXState_DP, HandshakeComplete_SP, GotConsecutiveHandshake_S, SendClockCorrection_S, TXFIFOStatus_SI, TXFIFOData_DI, TXOnline_S, SATAPortConfigInReg_D)
	begin
		TXState_DN <= TXState_DP;       -- Keep state by default.

		TXDataReg_D <= (others => '0');
		TXIsKReg_S  <= '0';

		TXFIFOControl_SO.Read_S <= '0';

		-- Clock correction counter control.
		ClockCorrectionCount_S <= '0';
		ClockCorrectionClear_S <= '0';

		-- Statistics and debugging.
		TXClockCorrectionCount_S <= '0';
		TXHandshakeCount_S       <= '0';
		TXDataCount_S            <= '0';
		TXIdleCount_S            <= '0';

		case TXState_DP is
			when stSendStart =>
				-- Only operate if basic functionality is present on hardware side.
				if TXOnline_S then
					ClockCorrectionCount_S <= '1';

					-- Decide what to send, if nothing else that has higher priority is to be sent, send the usual
					-- idle frame. Priority is in this order: clock correction, handshake, data, idle frame.
					if SendClockCorrection_S then
						TXDataReg_D <= KCHAR_CLOCKCORRECT;
						TXIsKReg_S  <= '1';

						-- Reset clock correction counter.
						ClockCorrectionClear_S <= '1';

						TXClockCorrectionCount_S <= '1';

						TXState_DN <= stSendClockCorrection2;
					elsif not HandshakeComplete_SP then
						TXDataReg_D <= KCHAR_COMMA;
						TXIsKReg_S  <= '1';

						TXHandshakeCount_S <= '1';

						TXState_DN <= stSendHandshake2;
					elsif not TXFIFOStatus_SI.Empty_S then
						TXDataReg_D <= TXFIFOData_DI(31 downto 24);
						TXIsKReg_S  <= TXFIFOData_DI(35);

						TXDataCount_S <= '1';

						TXState_DN <= stSendData2;
					else
						TXDataReg_D <= KCHAR_COMMA;
						TXIsKReg_S  <= '1';

						TXIdleCount_S <= '1';

						TXState_DN <= stSendIdle2;
					end if;
				else
					-- Loss of PLL lock, can't guarantee anything working at this point.
					-- So just keep clock correction counter in reset and send all zeros (data/isK) out.
					ClockCorrectionClear_S <= '1';

					TXDataReg_D <= (others => '0');
					TXIsKReg_S  <= '0';
				end if;

			when stSendClockCorrection2 =>
				TXDataReg_D <= KCHAR_CLOCKCORRECT;
				TXIsKReg_S  <= '1';

				TXState_DN <= stSendClockCorrection3;

			when stSendClockCorrection3 =>
				TXDataReg_D <= KCHAR_CLOCKCORRECT;
				TXIsKReg_S  <= '1';

				TXState_DN <= stSendClockCorrection4;

			when stSendClockCorrection4 =>
				TXDataReg_D <= KCHAR_CLOCKCORRECT;
				TXIsKReg_S  <= '1';

				TXState_DN <= stSendStart;

			when stSendHandshake2 =>
				TXDataReg_D <= KCHAR_HANDSHAKE;
				TXIsKReg_S  <= '1';

				TXState_DN <= stSendHandshake3;

			when stSendHandshake3 =>
				TXDataReg_D(0) <= GotConsecutiveHandshake_S;
				TXIsKReg_S     <= '0';

				TXState_DN <= stSendHandshake4;

			when stSendHandshake4 =>
				TXDataReg_D <= std_logic_vector(PROTOCOL_VERSION);
				TXIsKReg_S  <= '0';

				TXState_DN <= stSendStart;

			when stSendData2 =>
				TXDataReg_D <= TXFIFOData_DI(23 downto 16);
				TXIsKReg_S  <= TXFIFOData_DI(34);

				TXState_DN <= stSendData3;

			when stSendData3 =>
				TXDataReg_D <= TXFIFOData_DI(15 downto 8);
				TXIsKReg_S  <= TXFIFOData_DI(33);

				TXState_DN <= stSendData4;

			when stSendData4 =>
				TXDataReg_D <= TXFIFOData_DI(7 downto 0);
				TXIsKReg_S  <= TXFIFOData_DI(32);

				-- Advance TX FIFO to next data object (consume).
				TXFIFOControl_SO.Read_S <= '1';

				TXState_DN <= stSendStart;

			when stSendIdle2 =>
				TXDataReg_D <= KCHAR_IDLE;
				TXIsKReg_S  <= '1';

				TXState_DN <= stSendIdle3;

			when stSendIdle3 =>
				TXDataReg_D <= SATAPortConfigInReg_D.IdleDataPart_D(15 downto 8);
				TXIsKReg_S  <= '0';

				TXState_DN <= stSendIdle4;

			when stSendIdle4 =>
				TXDataReg_D <= SATAPortConfigInReg_D.IdleDataPart_D(7 downto 0);
				TXIsKReg_S  <= '0';

				TXState_DN <= stSendStart;

			when others =>
				null;
		end case;
	end process txStateMachine;

	txRegisterUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			TXState_DP <= stSendStart;

			PCSTXData_DO <= (others => '0');
			PCSTXIsK_SO  <= '0';
		elsif rising_edge(Clock_CI) then
			TXState_DP <= TXState_DN;

			PCSTXData_DO <= TXDataReg_D;
			PCSTXIsK_SO  <= TXIsKReg_S;
		end if;
	end process txRegisterUpdate;

	RXSymbolsCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXSymbolsCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXSymbols_D);

	RXClockCorrectionSymbolsCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXClockCorrectionSymbolsCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXClockCorrectionSymbols_D);

	RXCommaSymbolsCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXCommaSymbolsCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXCommaSymbols_D);

	RXDataWordsCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXDataWordsCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXDataWords_D);

	RXDataHandshakeCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXDataHandshakeCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXDataHandshake_D);

	RXDataIdleCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXDataIdleCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXDataIdle_D);

	RXDataDataCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXDataDataCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXDataData_D);

	RXDataDroppedCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => RXDataDroppedCount_S,
			Data_DO      => SATAPortConfigOutReg_D.RXDataDropped_D);

	PCSDisparityErrorCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => PCSDisparityError_SI,
			Data_DO      => SATAPortConfigOutReg_D.PCSDisparityError_D);

	PCSCodeViolationErrorCounter : entity work.Counter
		generic map(
			SIZE=> SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => PCSCodeViolationError_SI,
			Data_DO      => SATAPortConfigOutReg_D.PCSCodeViolationError_D);

	HandshakeResetCountCounter : entity work.Counter
		generic map(
			SIZE => SATAPORTCONFIG_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not RXOnline_S,
			Enable_SI    => HandshakeResetCountCount_S,
			Data_DO      => SATAPortConfigOutReg_D.HandshakeResetCount_D);

	SATAPortConfigOutReg_D.HandshakeComplete_D        <= HandshakeComplete_SP;
	SATAPortConfigOutReg_D.HandshakeVersionMismatch_D <= HandshakeVersionMismatch_SP;

	-- Loss of Comma Sync: we can't use the internal LinkStateMachine provided by Lattice for this,
	-- since it assumes that a comma symbol is followed by a data symbol, but in the SpiNNaker link
	-- protocol this is not the case, a comma symbol is often followed by another control symbol,
	-- especially during handshake phase. So we use the external LinkStateMachine option, meaning
	-- it's not the PCS block that tells us when it successfully aligned to a word of data, but we
	-- tell it when it can go and align to a data word, and expect this to be successful, based on
	-- criteria known to us. The usual requirements are that a comma symbol is present and periodic,
	-- and appears at even intervals: this is guaranteed by the TX state machine, and the RX state
	-- machine then works based on this assumption. Things that make us loose alignment for sure
	-- are errors, so if any of the error flags is true, we see that as a loss of sync.
	PCSLossOfSync_S       <= PCSLossOfRXCDRLock_SI or PCSLossOfSignal_SI or PCSDisparityError_SI or PCSCodeViolationError_SI;
	PCSEnableWordAlign_SO <= not PCSLossOfSync_S;

	-- On receiver side, we don't only check the CDR lock, but also loss of signal and loss of sync
	-- flags, which do work since the transmitter provides clock correction and handshake sequences
	-- at least all the time, and the latter do contain commas for alignment.
	RXOnline_S <= not PCSLossOfRXCDRLock_SI and not PCSLossOfSignal_SI and not PCSLossOfSync_S;

	-- Any data-related receive error invalidates the current data byte! It is simply skipped over.
	RXValidData_S <= not PCSDisparityError_SI and not PCSCodeViolationError_SI;

	rxByteStateMachine : process(RXOnline_S, RXValidData_S, RXDataReg_D, RXIsKReg_S, RXAlignment_DP, RXCommaAligned_SP, RXWordData_DP, RXWordIsK_SP)
	begin
		-- Data alignment to comma symbols.
		RXCommaAligned_SN <= RXCommaAligned_SP;
		RXAlignment_DN    <= RXAlignment_DP;

		-- Output word.
		RXWordData_DN  <= RXWordData_DP;
		RXWordIsK_SN   <= RXWordIsK_SP;
		RXWordValid_SN <= '0';          -- By default, the data is considered invalid.

		-- Statistics and debugging.
		RXSymbolsCount_S                <= '0';
		RXClockCorrectionSymbolsCount_S <= '0';
		RXCommaSymbolsCount_S           <= '0';
		RXDataWordsCount_S              <= '0';

		if RXOnline_S then
			if RXValidData_S then
				RXSymbolsCount_S <= '1';
				-- We're getting valid bytes here. Now, what do they mean? At startup we have
				-- no knowledge about alignment. So we wait for a comma symbol, and align to it.
				-- We then just keep getting 4 byte data blocks, aligned to the last seen comma.
				-- Each of these data blocks can be either a handshake, or actual data, or an idle
				-- frame, and we have to handle those differently later on.
				-- At any point a clock correction sequence may appear, which is made up of
				-- four special control characters.
				if SymbolIsClockCorrection(RXDataReg_D, RXIsKReg_S) then
					-- Count each clock correction byte we get, and discard it.
					RXClockCorrectionSymbolsCount_S <= '1';
				elsif SymbolIsComma(RXDataReg_D, RXIsKReg_S) then
					-- A comma has come! Rejoice and (re)align!
					RXCommaAligned_SN <= '1';
					RXAlignment_DN    <= "01";

					RXCommaSymbolsCount_S <= '1';

					RXWordData_DN(31 downto 24) <= RXDataReg_D;
					RXWordIsK_SN(3)             <= RXIsKReg_S;
				else
					-- Some kind of data here.
					if RXAlignment_DP = "00" then
						RXWordData_DN(31 downto 24) <= RXDataReg_D;
						RXWordIsK_SN(3)             <= RXIsKReg_S;

						RXAlignment_DN <= "01";
					elsif RXAlignment_DP = "01" then
						RXWordData_DN(23 downto 16) <= RXDataReg_D;
						RXWordIsK_SN(2)             <= RXIsKReg_S;

						RXAlignment_DN <= "10";
					elsif RXAlignment_DP = "10" then
						RXWordData_DN(15 downto 8) <= RXDataReg_D;
						RXWordIsK_SN(1)            <= RXIsKReg_S;

						RXAlignment_DN <= "11";
					elsif RXAlignment_DP = "11" then
						RXWordData_DN(7 downto 0) <= RXDataReg_D;
						RXWordIsK_SN(0)           <= RXIsKReg_S;

						RXAlignment_DN <= "00";

						-- We got a full data word, signal it, but only if we saw a comma first.
						RXWordValid_SN     <= RXCommaAligned_SP;
						RXDataWordsCount_S <= RXCommaAligned_SP;
					end if;
				end if;
			end if;
		else
			-- Reinitialize alignment after connection loss.
			RXCommaAligned_SN <= '0';

			RXWordData_DN <= (others => '0');
			RXWordIsK_SN  <= (others => '0');
		end if;
	end process rxByteStateMachine;

	rxByteRegisterUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			RXDataReg_D <= (others => '0');
			RXIsKReg_S  <= '0';

			RXCommaAligned_SP <= '0';
			RXAlignment_DP    <= "00";

			RXWordData_DP  <= (others => '0');
			RXWordIsK_SP   <= (others => '0');
			RXWordValid_SP <= '0';
		elsif rising_edge(Clock_CI) then
			RXDataReg_D <= PCSRXData_DI;
			RXIsKReg_S  <= PCSRXIsK_SI;

			RXCommaAligned_SP <= RXCommaAligned_SN;
			RXAlignment_DP    <= RXAlignment_DN;

			RXWordData_DP  <= RXWordData_DN;
			RXWordIsK_SP   <= RXWordIsK_SN;
			RXWordValid_SP <= RXWordValid_SN;
		end if;
	end process rxByteRegisterUpdate;

	handshakeConsecutiveCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => HANDSHAKE_CONSECUTIVE_COUNT_SIZE,
			RESET_ON_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => HandshakeConsecutiveClear_S,
			Enable_SI    => HandshakeConsecutiveCount_S,
			DataLimit_DI => SATAPortConfigInReg_D.HandshakeConsecutiveNeeded_D,
			Overflow_SO  => GotConsecutiveHandshake_S,
			Data_DO      => open);

	rxWordStateMachine : process(HandshakeComplete_SP, HandshakePhase_DP, HandshakeVersionMismatch_SP, RXFIFOStatus_SI, RXWordData_DP, RXWordIsK_SP, RXWordValid_SP, RXOnline_S, GotConsecutiveHandshake_S, SATAPortConfigInReg_D)
		variable RXWordIsHandshake_S  : boolean;
		variable RXWordIsIdle_S       : boolean;
		variable RXWordIsData_S       : boolean;
		variable HandshakeInVersion_D : unsigned(7 downto 0);
		variable HandshakeInPhase_D   : std_logic;
	begin
		-- Handshake notification. Keep values by default.
		HandshakeComplete_SN        <= HandshakeComplete_SP;
		HandshakePhase_DN           <= HandshakePhase_DP;
		HandshakeVersionMismatch_SN <= HandshakeVersionMismatch_SP;

		-- Consecutive handshake counter control.
		HandshakeConsecutiveClear_S <= '0';
		HandshakeConsecutiveCount_S <= '0';

		-- Here we have info on receiver state and assembled words.
		-- Clock correction sequences have been filtered already, so we're left
		-- with aligned data representing either handshakes, idle frames or
		-- actual data. Of these, we handle the handshake protocol here, we discard
		-- idle frames, and we send actual data out to the RXFIFO.
		RXWordIsHandshake_S := WordIsHandshake(RXWordData_DP, RXWordIsK_SP) and RXWordValid_SP = '1';
		RXWordIsIdle_S      := WordIsIdle(RXWordData_DP, RXWordIsK_SP, SATAPortConfigInReg_D.IdleDataPart_D) and RXWordValid_SP = '1';
		RXWordIsData_S      := not RXWordIsHandshake_S and not RXWordIsIdle_S and RXWordValid_SP = '1';

		HandshakeInVersion_D := unsigned(RXWordData_DP(7 downto 0));
		HandshakeInPhase_D   := RXWordData_DP(8);

		-- Statistics and debugging.
		RXDataHandshakeCount_S     <= BooleanToStdLogic(RXWordIsHandshake_S);
		RXDataIdleCount_S          <= BooleanToStdLogic(RXWordIsIdle_S);
		RXDataDataCount_S          <= BooleanToStdLogic(RXWordIsData_S);
		RXDataDroppedCount_S       <= RXFIFOStatus_SI.AlmostFull_S and BooleanToStdLogic(RXWordIsData_S) and HandshakeComplete_SP;
		HandshakeResetCountCount_S <= '0';

		-- Handle handshake protocol.
		-- A handshake is complete when we received at least HANDSHAKE_CONSECUTIVE_COUNT consecutive
		-- handshakes with matching protocol version and any phase, followed by one with phase set
		-- to 1. The transmitter will only ever send out a phase of 1 if it also already saw at least
		-- HANDSHAKE_CONSECUTIVE_COUNT consecutive handshakes.
		-- The following conditions reset the handshake process:
		-- + loss of sync/connection
		-- + non-handshake frame during handshake process
		-- + handshake with wrong protocol version
		-- + handshake with earlier phase than current one
		if RXOnline_S then
			if RXWordIsHandshake_S then
				-- We are online and we got a handshake. Handle it.
				if HandshakeInVersion_D /= PROTOCOL_VERSION or HandshakeInPhase_D < HandshakePhase_DP then
					-- If we get a handshake with wrong protocol version or going back to an older handshake
					-- phase than the last we saw, we reset and restart the handshake.
					HandshakeConsecutiveClear_S <= '1';
					HandshakeResetCountCount_S  <= '1';

					HandshakeComplete_SN <= '0';
					HandshakePhase_DN    <= '0';

					-- Signal version mismatch, so we can check in diagnostic registers.
					if HandshakeInVersion_D /= PROTOCOL_VERSION then
						HandshakeVersionMismatch_SN <= '1';
					else
						HandshakeVersionMismatch_SN <= '0';
					end if;
				else
					-- If everything is in order, we increment the counter.
					HandshakeConsecutiveCount_S <= '1';

					-- There can be no version mismatch at this point.
					HandshakeVersionMismatch_SN <= '0';

					-- And keep track of what we just saw as phase number, for later comparison,
					-- to ensure we don't got back to an older phase (restart in that case).
					HandshakePhase_DN <= HandshakeInPhase_D;

					-- We finally saw both all the needed consecutive handshakes, and we got one
					-- with a phase of 1. We're done!
					if GotConsecutiveHandshake_S and HandshakeInPhase_D then
						HandshakeComplete_SN <= '1';
					end if;
				end if;
			elsif RXWordValid_SP = '1' then
				-- Anything that isn't a handshake resets the counter, restarting the handshake
				-- IF it was in progress. If it was already complete, this has no effect.
				HandshakeConsecutiveClear_S <= not HandshakeComplete_SP;
				HandshakeResetCountCount_S  <= not HandshakeComplete_SP;
			end if;
		else
			-- Require handshake restart on loss of connection/sync.
			HandshakeConsecutiveClear_S <= '1';

			HandshakeComplete_SN        <= '0';
			HandshakePhase_DN           <= '0';
			HandshakeVersionMismatch_SN <= '0';
		end if;

		-- We only pass on data words, IF there is space on the RXFIFO and the handshake phase was successfully completed.
		RXFIFODataReg_D  <= RXWordIsK_SP & RXWordData_DP;
		RXFIFOWriteReg_S <= not RXFIFOStatus_SI.AlmostFull_S and BooleanToStdLogic(RXWordIsData_S) and HandshakeComplete_SP;
	end process rxWordStateMachine;

	rxWordRegisterUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			HandshakeComplete_SP        <= '0';
			HandshakePhase_DP           <= '0';
			HandshakeVersionMismatch_SP <= '0';

			RXFIFOData_DO            <= (others => '0');
			RXFIFOControl_SO.Write_S <= '0';

			SATAPortConfigInReg_D     <= tSATAPortConfigInDefault;
			SATAPortConfigInSyncReg_D <= tSATAPortConfigInDefault;

			SATAPortConfigOut_DO       <= tSATAPortConfigOutDefault;
			SATAPortConfigOutSyncReg_D <= tSATAPortConfigOutDefault;
		elsif rising_edge(Clock_CI) then
			HandshakeComplete_SP        <= HandshakeComplete_SN;
			HandshakePhase_DP           <= HandshakePhase_DN;
			HandshakeVersionMismatch_SP <= HandshakeVersionMismatch_SN;

			RXFIFOData_DO            <= RXFIFODataReg_D;
			RXFIFOControl_SO.Write_S <= RXFIFOWriteReg_S;

			SATAPortConfigInReg_D     <= SATAPortConfigInSyncReg_D;
			SATAPortConfigInSyncReg_D <= SATAPortConfigIn_DI;

			SATAPortConfigOut_DO       <= SATAPortConfigOutSyncReg_D;
			SATAPortConfigOutSyncReg_D <= SATAPortConfigOutReg_D;
		end if;
	end process rxWordRegisterUpdate;
end architecture Behavioral;
