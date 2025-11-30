library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

entity display is
	port (
		clk: in std_logic;
		rst: in std_logic;
		char: in std_logic_vector(BITWIDTH - 1 downto 0);
		fifo_empty: in std_logic;
		baud_change: in std_logic;
		baud_rate: in integer range 0 to 9;
		seg0, seg1, seg2, seg3, seg4, seg5: out std_logic_vector(6 downto 0);
		read_fifo: out std_logic := '0'
	);
end entity;

architecture rtl of display is
	signal delay_counter: natural range 0 to 10000000 := 0;
	signal baud_change_delay: std_logic:= '0' ;

function char_to_sevenseg(c : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable a : integer;
begin
    -- ASCII ’0’..’9’
    if c >= x"30" and c <= x"39" then
        a := to_integer(unsigned(c)) - 48;

    -- ASCII ’A’..’F’
    elsif c >= x"41" and c <= x"46" then
        a := to_integer(unsigned(c)) - 55;

    -- ASCII ’a’..’f’
    elsif c >= x"61" and c <= x"66" then
        a := to_integer(unsigned(c)) - 87;

    else
        a := 16;  -- invalid
    end if;

    case a is
        when 0  => return "1000000"; -- 0
        when 1  => return "1111001"; -- 1
        when 2  => return "0100100"; -- 2
        when 3  => return "0110000"; -- 3
        when 4  => return "0011001"; -- 4
        when 5  => return "0010010"; -- 5
        when 6  => return "0000010"; -- 6
        when 7  => return "1111000"; -- 7
        when 8  => return "0000000"; -- 8
        when 9  => return "0010000"; -- 9
        when 10 => return "0001000"; -- A
        when 11 => return "0000011"; -- b
        when 12 => return "1000110"; -- C
        when 13 => return "0100001"; -- d
        when 14 => return "0000110"; -- E
        when 15 => return "0001110"; -- F
        when others => return "1111111"; -- blank/error
    end case;
end function;

begin
	process (fifo_empty, clk, char) is
	begin

		
		if rst = SYSRESET then
			/*
			seg0 <= (others => '1');
			seg1 <= (others => '1');
			seg2 <= (others => '1');
			seg3 <= (others => '1');
			seg4 <= (others => '1');
			seg5 <= (others => '0');
			read_fifo <= '0';
			*/
			seg0 <= "1000000";
			seg1 <= "1111001";
			seg2 <= "0100100";
			seg3 <= char_to_sevenseg("01000101"); -- skriv E
			seg4 <= "0011001";
			seg5 <= "0010010";
			read_fifo <= '0';
		elsif rising_edge(clk) then
		delay_counter <= delay_counter + 1;
		read_fifo <= '0';
		if baud_change = '1' then
			baud_change_delay <= '1';
		end if;
		if delay_counter = 0 then
				
			if baud_change_delay = '1' then
			baud_change_delay <= '0';
			seg0 <= "1000000";
			seg1 <= "1000000";
			seg2 <= "1000000";
			seg3 <= "1000000";
				if baud_rate = 0 then
					seg4 <= "1111001";
					seg5 <= "1000000";
				elsif baud_rate = 1 then
					seg4 <= "0100100";
					seg5 <= "1000000";
				elsif baud_rate = 2 then
					seg4 <= "0110000";
					seg5 <= "1000000";
				elsif baud_rate = 3 then
					seg4 <= "0011001";
					seg5 <= "1000000";
				elsif baud_rate = 4 then
					seg4 <= "0010010";
					seg5 <= "1000000";
				elsif baud_rate = 5 then
					seg4 <= "0000010";
					seg5 <= "1000000";
				elsif baud_rate = 6 then
					seg4 <= "1111000";
					seg5 <= "1000000";
				elsif baud_rate = 7 then
					seg4 <= "0000000";
					seg5 <= "1000000";
				elsif baud_rate = 8 then
					seg4 <= "0010000";
					seg5 <= "1000000";
				elsif baud_rate = 9 then
					seg4 <= "1000000";
					seg5 <= "1111001";
				end if;
				-- display baud rate on seg5..seg0
			elsif fifo_empty = '0' then -- if fifo not empty add character and shift
				read_fifo <= '1';
				seg0 <= char_to_sevenseg(char);
				seg1 <= seg0;
				seg2 <= seg1;
				seg3 <= seg2;
				seg4 <= seg3;
				seg5 <= seg4;
			else
				seg0 <= "0010000";--char_to_sevenseg(char);
				seg1 <= seg0;
				seg2 <= seg1;
				seg3 <= seg2;
				seg4 <= seg3;
				seg5 <= seg4;
				read_fifo <= '0';
			end if;
		end if;
		end if;
	end process;

end architecture;