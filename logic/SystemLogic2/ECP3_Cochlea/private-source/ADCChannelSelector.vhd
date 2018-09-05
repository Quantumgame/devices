library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ADCConfigRecords.all;
use work.Settings.MAX_ADC_CH_NUM;

-- Selects the firs availavle channel from  up to 4 AD7691 ADCs connected in nCS mode with common SDO
entity ADCChannelSelector is
	generic(
		CHAN_NUMBER     : integer);
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;

		-- Configuration input
		ChanEnabled_DI  : in  std_logic_vector(CHAN_NUMBER - 1 downto 0);
		DeselectAll_SI  : in  std_logic;
		
		-- Channel select outputs
		ChanSelected_DO : out unsigned(1 downto 0);
		ChanBitMask_SO  : out std_logic_vector(MAX_ADC_CH_NUM - 1 downto 0);
		AllChanOff_SO   : out std_logic);
end entity ADCChannelSelector;

architecture Behavioral of ADCChannelSelector is
	signal ChanSelected_D : unsigned(1 downto 0);
	signal ChanBitMask_S  : std_logic_vector(CHAN_NUMBER - 1 downto 0);
	signal AllChanOff_S   : std_logic;
begin
	assert (CHAN_NUMBER > 0 and CHAN_NUMBER <= 4) report "CHAN_NUMBER should be from 1 to 4." severity FAILURE;

	selNumberOfChan: if CHAN_NUMBER = 1 generate
	begin
		channelSelect1 : process(ChanEnabled_DI)
		begin
			ChanSelected_D <= "00";
			ChanBitMask_S(0) <= ChanEnabled_DI(0);
			AllChanOff_S <= not ChanEnabled_DI(0);
		end process channelSelect1;
	elsif CHAN_NUMBER = 2 generate
	begin
		channelSelect2 : process(ChanEnabled_DI)
		begin
			ChanSelected_D <= "00";
			ChanBitMask_S <= (others => '0');
			AllChanOff_S <= '0';
			if ChanEnabled_DI(0) = '1' then
				ChanSelected_D <= "00";
				ChanBitMask_S(0) <= '1';
			elsif ChanEnabled_DI(1) = '1' then
				ChanSelected_D <= "01";
				ChanBitMask_S(1) <= '1';
			else
				AllChanOff_S <= '1';
			end if;
		end process channelSelect2;
	elsif CHAN_NUMBER = 3 generate
	begin
		channelSelect3 : process(ChanEnabled_DI)
		begin
			ChanSelected_D <= "00";
			ChanBitMask_S <= (others => '0');
			AllChanOff_S <= '0';
			if ChanEnabled_DI(0) = '1' then
				ChanSelected_D <= "00";
				ChanBitMask_S(0) <= '1';
			elsif ChanEnabled_DI(1) = '1' then
				ChanSelected_D <= "01";
				ChanBitMask_S(1) <= '1';
			elsif ChanEnabled_DI(2) = '1' then
				ChanSelected_D <= "10";
				ChanBitMask_S(2) <= '1';
			else
				AllChanOff_S <= '1';
			end if;
		end process channelSelect3;
	elsif CHAN_NUMBER = 4 generate
	begin
		channelSelect4 : process(ChanEnabled_DI)
		begin
			ChanSelected_D <= "00";
			ChanBitMask_S <= (others => '0');
			AllChanOff_S <= '0';
			if ChanEnabled_DI(0) = '1' then
				ChanSelected_D <= "00";
				ChanBitMask_S(0) <= '1';
			elsif ChanEnabled_DI(1) = '1' then
				ChanSelected_D <= "01";
				ChanBitMask_S(1) <= '1';
			elsif ChanEnabled_DI(2) = '1' then
				ChanSelected_D <= "10";
				ChanBitMask_S(2) <= '1';
			elsif ChanEnabled_DI(3) = '1' then
				ChanSelected_D <= "11";
				ChanBitMask_S(3) <= '1';
			else
				AllChanOff_S <= '1';
			end if;
		end process channelSelect4;
	end generate;

	registerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			ChanSelected_DO <= "00";
			ChanBitMask_SO <= (others => '0');
			AllChanOff_SO <= '1';
		elsif rising_edge(Clock_CI) then
			ChanSelected_DO <= ChanSelected_D;
			if DeselectAll_SI = '0' then
				ChanBitMask_SO(CHAN_NUMBER-1 downto 0) <= ChanBitMask_S;
				ChanBitMask_SO(3 downto CHAN_NUMBER) <= (others => '0');
			else
				ChanBitMask_SO <= (others => '0');
			end if;
			AllChanOff_SO <= AllChanOff_S;
		end if;
	end process registerUpdate;

end architecture Behavioral;