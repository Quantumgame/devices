library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package Functions is
	function BooleanToStdLogic(BOOL : boolean) return std_logic;

	function SelectInteger(BOOL : boolean; IF_TRUE, IF_FALSE : integer) return integer;

	function SelectReal(BOOL : boolean; IF_TRUE, IF_FALSE : real) return real;
end package Functions;

package body Functions is
	function BooleanToStdLogic(BOOL : boolean) return std_logic is
	begin
		if BOOL then
			return '1';
		else
			return '0';
		end if;
	end function BooleanToStdLogic;

	function SelectInteger(BOOL : boolean; IF_TRUE, IF_FALSE : integer) return integer is
	begin
		if BOOL then
			return (IF_TRUE);
		else
			return (IF_FALSE);
		end if;
	end function SelectInteger;

	function SelectReal(BOOL : boolean; IF_TRUE, IF_FALSE : real) return real is
	begin
		if BOOL then
			return (IF_TRUE);
		else
			return (IF_FALSE);
		end if;
	end function SelectReal;
end package body Functions;
