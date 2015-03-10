library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.EventCodes.all;
use work.FIFORecords.all;
use work.ApproachSensitivityConfigRecords.all;


entity ApproachCellStateMachine is

	generic (Counter_Size : Integer;
			 UpdateUnit:  Integer);
	
    port(
		Clock_CI                 : in  std_logic;
		Reset_RI                 : in  std_logic;
		
		DVSEvent_I				 : in  std_logic;
		
		DVSAEREvent_Code		 		 : in  std_logic_vector( EVENT_WIDTH-1 downto 0); 
		
		AC_Fire_O     					 : out  array (2 downto 0 , 2 downto 0) of std_logic;
		
		
		);
		
		
end entity ApproachCellStateMachine;

			
begin
	
	
	EventDecoder : entity work.EventDecoder
	
		generic map(
			SIZE => DecayCounter_Size)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => '1',
			DataLimit_DI => unsigned (DecayCounter_Size - 1 downto 0),
			Overflow_SO  => Decay_Enable,  --- what to do with the Overflow Alert? 
			Data_DO      => open );
			
			
	Generate_ApproachCells :
		for k in 0 to 2 generate
			for m in 0 to 2 generate
				AC: entity work.AC port map 
				( 
					Clock_CI     => Clock_CI,
					Reset_RI     => Reset_RI,
					DVSEventInthisAC_I     => DVSEvent_I(k,m),
					EventXAddrInthisAC_I    => EventXAddr(k,m),
					EventYAddrInthisAC_I => EventYAddr(k,m),
					EventPolarity_I  => EventPolarity,  --- what to do with the Overflow Alert? 
					thisAC_Fire_O    => AC_Fire_O(k,m));