library ieee;
use ieee.std_logic_1164.all;
use work.FIFORecords.all;
use work.SATAPortConfigRecords.all;

entity SATAPortIO is
	port(
		RefClockPos_CI       : in  std_logic;
		RefClockNeg_CI       : in  std_logic;
		SATADataInPos_DI     : in  std_logic;
		SATADataInNeg_DI     : in  std_logic;
		SATADataOutPos_DO    : out std_logic;
		SATADataOutNeg_DO    : out std_logic;

		Reset_RI             : in  std_logic; -- Global asynchronous reset.

		TXFIFOWrClock_CI     : in  std_logic;
		TXFIFOWrReset_RI     : in  std_logic;
		TXFIFOData_DI        : in  std_logic_vector(35 downto 0);
		TXFIFOStatus_SO      : out tFromFifoWriteSide;
		TXFIFOControl_SI     : in  tToFifoWriteSide;

		RXFIFORdClock_CI     : in  std_logic;
		RXFIFORdReset_RI     : in  std_logic;
		RXFIFOData_DO        : out std_logic_vector(35 downto 0);
		RXFIFOStatus_SO      : out tFromFifoReadSide;
		RXFIFOControl_SI     : in  tToFifoReadSide;

		-- Configuration input and output.
		SATAPortConfigIn_DI  : in  tSATAPortConfigIn;
		SATAPortConfigOut_DO : out tSATAPortConfigOut);
end SATAPortIO;

architecture Structural of SATAPortIO is
	-- Lattice IPExpress generated PCS component.
	component sata_port_controller
		port(
			refclkp             : in  std_logic;
			refclkn             : in  std_logic;
			hdinp_ch3           : in  std_logic;
			hdinn_ch3           : in  std_logic;
			rxiclk_ch3          : in  std_logic;
			txiclk_ch3          : in  std_logic;
			txdata_ch3          : in  std_logic_vector(7 downto 0);
			tx_k_ch3            : in  std_logic;
			tx_force_disp_ch3   : in  std_logic;
			tx_disp_sel_ch3     : in  std_logic;
			sb_felb_ch3_c       : in  std_logic;
			sb_felb_rst_ch3_c   : in  std_logic;
			word_align_en_ch3_c : in  std_logic;
			tx_pwrup_ch3_c      : in  std_logic;
			rx_pwrup_ch3_c      : in  std_logic;
			tx_div2_mode_ch3_c  : in  std_logic;
			rx_div2_mode_ch3_c  : in  std_logic;
			tx_serdes_rst_c     : in  std_logic;
			rst_n               : in  std_logic;
			serdes_rst_qd_c     : in  std_logic;
			hdoutp_ch3          : out std_logic;
			hdoutn_ch3          : out std_logic;
			rx_full_clk_ch3     : out std_logic;
			rx_half_clk_ch3     : out std_logic;
			tx_full_clk_ch3     : out std_logic;
			tx_half_clk_ch3     : out std_logic;
			rxdata_ch3          : out std_logic_vector(7 downto 0);
			rx_k_ch3            : out std_logic;
			rx_disp_err_ch3     : out std_logic;
			rx_cv_err_ch3       : out std_logic;
			rx_los_low_ch3_s    : out std_logic;
			ctc_urun_ch3_s      : out std_logic;
			ctc_orun_ch3_s      : out std_logic;
			ctc_ins_ch3_s       : out std_logic;
			ctc_del_ch3_s       : out std_logic;
			rx_cdr_lol_ch3_s    : out std_logic;
			tx_pll_lol_qd_s     : out std_logic;
			refclk2fpga         : out std_logic);
	end component;

	-- PCS signals.
	signal PCSTXClock_C, PCSTXReset_R                                                               : std_logic;
	signal PCSTXData_D, PCSRXData_D                                                                 : std_logic_vector(7 downto 0);
	signal PCSTXIsK_S, PCSRXIsK_S                                                                   : std_logic;
	signal PCSDisparityError_S, PCSCodeViolationError_S                                             : std_logic;
	signal PCSLossOfSignal_A, PCSLossOfSignalSync_S                                                 : std_logic;
	signal PCSEnableWordAlign_S                                                                     : std_logic;
	signal PCSClockToleranceCompensationUnderrun_A, PCSClockToleranceCompensationUnderrunSync_S     : std_logic;
	signal PCSClockToleranceCompensationOverrun_A, PCSClockToleranceCompensationOverrunSync_S       : std_logic;
	signal PCSClockToleranceCompensationSKInserted_A, PCSClockToleranceCompensationSKInsertedSync_S : std_logic;
	signal PCSClockToleranceCompensationSKDeleted_A, PCSClockToleranceCompensationSKDeletedSync_S   : std_logic;
	signal PCSLossOfRXCDRLock_A, PCSLossOfRXCDRLockSync_S                                           : std_logic;
	signal PCSLossOfTXPLLLock_A, PCSLossOfTXPLLLockSync_S                                           : std_logic;

	-- Configuration constants and signals.
	constant PCS_IO_DATA_SIZE  : integer := 36; -- 32 data bit plus 4 isK bits.
	constant PCS_IO_DATA_DEPTH : integer := 512;

	signal PCSPower_S : std_logic;      -- Enable power to RX/TX sides.

	-- RX/TX FIFO signals.
	signal TXFIFODataOut_D, RXFIFODataIn_D        : std_logic_vector(PCS_IO_DATA_SIZE - 1 downto 0);
	signal TXFIFOControlIn_S, RXFIFOControlIn_S   : tToFifo;
	signal TXFIFOControlOut_S, RXFIFOControlOut_S : tFromFifo;
begin
	PCSPower_S <= '1';                  -- Keep power always on.

	-- Connect PCS core (SATA port).
	sataPort : component sata_port_controller
		port map(
			refclkp             => RefClockPos_CI,
			refclkn             => RefClockNeg_CI,
			hdinp_ch3           => SATADataInPos_DI,
			hdinn_ch3           => SATADataInNeg_DI,
			hdoutp_ch3          => SATADataOutPos_DO,
			hdoutn_ch3          => SATADataOutNeg_DO,
			rxiclk_ch3          => PCSTXClock_C, -- Use TX PLL clock for FPGA RX FIFO interfaces.
			txiclk_ch3          => PCSTXClock_C, -- Use TX PLL clock for FPGA TX FIFO interfaces.
			rx_full_clk_ch3     => open,
			rx_half_clk_ch3     => open,
			tx_full_clk_ch3     => PCSTXClock_C, -- TX PLL clock, for FPGA core logic.
			tx_half_clk_ch3     => open,
			txdata_ch3          => PCSTXData_D,
			tx_k_ch3            => PCSTXIsK_S,
			tx_force_disp_ch3   => '0', -- Don't force PCS to use user-supplied disparity values.
			tx_disp_sel_ch3     => '0', -- User-supplied disparity value (disabled above).
			rxdata_ch3          => PCSRXData_D,
			rx_k_ch3            => PCSRXIsK_S,
			rx_disp_err_ch3     => PCSDisparityError_S,
			rx_cv_err_ch3       => PCSCodeViolationError_S,
			sb_felb_ch3_c       => '0', -- Disable Parallel Loopback
			sb_felb_rst_ch3_c   => '0', -- Don't reset Parallel Lookpack FIFO
			word_align_en_ch3_c => PCSEnableWordAlign_S,
			tx_pwrup_ch3_c      => PCSPower_S, -- Power up TX-side.
			rx_pwrup_ch3_c      => PCSPower_S, -- Power up RX-side.
			rx_los_low_ch3_s    => PCSLossOfSignal_A, -- '1' signal is lost, '0' signal found
			ctc_urun_ch3_s      => PCSClockToleranceCompensationUnderrun_A, -- '1' if CTC FIFO underruns.
			ctc_orun_ch3_s      => PCSClockToleranceCompensationOverrun_A, -- '1' if CTC FIFO overruns.
			ctc_ins_ch3_s       => PCSClockToleranceCompensationSKInserted_A, -- '1' if Skip Character inserted by CTC.
			ctc_del_ch3_s       => PCSClockToleranceCompensationSKDeleted_A, -- '1' if Skip Character deleted by CTC.
			rx_cdr_lol_ch3_s    => PCSLossOfRXCDRLock_A, -- '1' loss of lock, '0' lock maintained
			tx_div2_mode_ch3_c  => '0', -- Full rate mode.
			rx_div2_mode_ch3_c  => '0', -- Full rate mode.
			tx_serdes_rst_c     => PCSTXReset_R,
			tx_pll_lol_qd_s     => PCSLossOfTXPLLLock_A, -- '1' loss of lock, '0' lock maintained
			refclk2fpga         => open, -- Reference clock (150MHz external) to FPGA link.
			rst_n               => not PCSTXReset_R,
			serdes_rst_qd_c     => PCSTXReset_R);

	syncSataPortStatusToTXClock : entity work.SATAPortStatusClockSynchronizer
		port map(
			PCSTXClock_CI                                  => PCSTXClock_C,
			Reset_RI                                       => Reset_RI,
			ResetSync_RO                                   => PCSTXReset_R,
			PCSLossOfSignal_SI                             => PCSLossOfSignal_A,
			PCSLossOfSignalSync_SO                         => PCSLossOfSignalSync_S,
			PCSClockToleranceCompensationUnderrun_SI       => PCSClockToleranceCompensationUnderrun_A,
			PCSClockToleranceCompensationUnderrunSync_SO   => PCSClockToleranceCompensationUnderrunSync_S,
			PCSClockToleranceCompensationOverrun_SI        => PCSClockToleranceCompensationOverrun_A,
			PCSClockToleranceCompensationOverrunSync_SO    => PCSClockToleranceCompensationOverrunSync_S,
			PCSClockToleranceCompensationSKInserted_SI     => PCSClockToleranceCompensationSKInserted_A,
			PCSClockToleranceCompensationSKInsertedSync_SO => PCSClockToleranceCompensationSKInsertedSync_S,
			PCSClockToleranceCompensationSKDeleted_SI      => PCSClockToleranceCompensationSKDeleted_A,
			PCSClockToleranceCompensationSKDeletedSync_SO  => PCSClockToleranceCompensationSKDeletedSync_S,
			PCSLossOfRXCDRLock_SI                          => PCSLossOfRXCDRLock_A,
			PCSLossOfRXCDRLockSync_SO                      => PCSLossOfRXCDRLockSync_S,
			PCSLossOfTXPLLLock_SI                          => PCSLossOfTXPLLLock_A,
			PCSLossOfTXPLLLockSync_SO                      => PCSLossOfTXPLLLockSync_S);

	txFIFO : entity work.FIFODualClock
		generic map(
			DATA_WIDTH        => PCS_IO_DATA_SIZE,
			DATA_DEPTH        => PCS_IO_DATA_DEPTH,
			ALMOST_EMPTY_FLAG => 2,
			ALMOST_FULL_FLAG  => 2)
		port map(
			WrClock_CI     => TXFIFOWrClock_CI,
			WrReset_RI     => TXFIFOWrReset_RI,
			RdClock_CI     => PCSTXClock_C,
			RdReset_RI     => PCSTXReset_R,
			FifoControl_SI => TXFIFOControlIn_S,
			FifoControl_SO => TXFIFOControlOut_S,
			FifoData_DI    => TXFIFOData_DI,
			FifoData_DO    => TXFIFODataOut_D);

	TXFIFOControlIn_S.WriteSide <= TXFIFOControl_SI;
	TXFIFOStatus_SO             <= TXFIFOControlOut_S.WriteSide;

	rxFIFO : entity work.FIFODualClock
		generic map(
			DATA_WIDTH        => PCS_IO_DATA_SIZE,
			DATA_DEPTH        => PCS_IO_DATA_DEPTH,
			ALMOST_EMPTY_FLAG => 2,
			ALMOST_FULL_FLAG  => 2)
		port map(
			WrClock_CI     => PCSTXClock_C,
			WrReset_RI     => PCSTXReset_R,
			RdClock_CI     => RXFIFORdClock_CI,
			RdReset_RI     => RXFIFORdReset_RI,
			FifoControl_SI => RXFIFOControlIn_S,
			FifoControl_SO => RXFIFOControlOut_S,
			FifoData_DI    => RXFIFODataIn_D,
			FifoData_DO    => RXFIFOData_DO);

	RXFIFOControlIn_S.ReadSide <= RXFIFOControl_SI;
	RXFIFOStatus_SO            <= RXFIFOControlOut_S.ReadSide;

	sataPortStateMachine : entity work.SATAPortStateMachine
		port map(
			Clock_CI                                   => PCSTXClock_C,
			Reset_RI                                   => PCSTXReset_R,
			PCSTXData_DO                               => PCSTXData_D,
			PCSTXIsK_SO                                => PCSTXIsK_S,
			PCSRXData_DI                               => PCSRXData_D,
			PCSRXIsK_SI                                => PCSRXIsK_S,
			PCSDisparityError_SI                       => PCSDisparityError_S,
			PCSCodeViolationError_SI                   => PCSCodeViolationError_S,
			PCSLossOfSignal_SI                         => PCSLossOfSignalSync_S,
			PCSEnableWordAlign_SO                      => PCSEnableWordAlign_S,
			PCSClockToleranceCompensationUnderrun_SI   => PCSClockToleranceCompensationUnderrunSync_S,
			PCSClockToleranceCompensationOverrun_SI    => PCSClockToleranceCompensationOverrunSync_S,
			PCSClockToleranceCompensationSKInserted_SI => PCSClockToleranceCompensationSKInsertedSync_S,
			PCSClockToleranceCompensationSKDeleted_SI  => PCSClockToleranceCompensationSKDeletedSync_S,
			PCSLossOfRXCDRLock_SI                      => PCSLossOfRXCDRLockSync_S,
			PCSLossOfTXPLLLock_SI                      => PCSLossOfTXPLLLockSync_S,
			TXFIFOData_DI                              => TXFIFODataOut_D,
			TXFIFOStatus_SI                            => TXFIFOControlOut_S.ReadSide,
			TXFIFOControl_SO                           => TXFIFOControlIn_S.ReadSide,
			RXFIFOData_DO                              => RXFIFODataIn_D,
			RXFIFOStatus_SI                            => RXFIFOControlOut_S.WriteSide,
			RXFIFOControl_SO                           => RXFIFOControlIn_S.WriteSide,
			SATAPortConfigIn_DI                        => SATAPortConfigIn_DI,
			SATAPortConfigOut_DO                       => SATAPortConfigOut_DO);
end architecture Structural;