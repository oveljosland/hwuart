/* requirements */
-- must support the UART protocol.
	-- 1 start bit.
	-- 8 data bits.
	-- 1 stop bit.
	-- no parity bits.
-- must support baud rate of at least 9600.
-- must be able to store the byte to be transmitted.
-- must indicate with a signal that tx is busy.
-- should support parity control (even, odd, none).
-- should be able to change baud rate when running.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

entity utx is
	port (
		byte_in: in std_logic_vector(BITWIDTH - 1 downto 0);
		baud_tick: in std_logic;
		pen: in std_logic; /* parity enable */
		rst: in std_logic;
		busy: out std_logic:= '0';
		serial_out: out std_logic:= '1';
		fifo_empty: in std_logic
	);
end entity;

architecture rtl of utx is
	signal msg: std_logic_vector(BITWIDTH - 1 downto 0);
	signal bit_idx: natural range 0 to BITWIDTH - 1 := 0;
	signal idx : natural range 0 to (BITWIDTH+3)*SMP_PER_BIT := 0; -- start + data + parity + stop
begin
	send_message: process(baud_tick, byte_in, fifo_empty, idx)
	begin
		if rst = SYSRESET then
			serial_out <= '1'; -- idle state
			busy <= '0';
			idx <= 0;
		elsif rising_edge(baud_tick) then
			if busy = '1' then
				--send bits
				if idx < (BITWIDTH + 3) * SMP_PER_BIT then
					--start bit
					if idx < SMP_PER_BIT then
						serial_out <= '0';
					--data bits
					elsif idx < (BITWIDTH + 1) * SMP_PER_BIT then
						serial_out <= msg((idx - SMP_PER_BIT) / SMP_PER_BIT);
					--parity bit
					elsif idx < (BITWIDTH + 2) * SMP_PER_BIT then
						serial_out <= par(msg);
					--stop bit
					elsif idx < (BITWIDTH + 3) * SMP_PER_BIT-1 then
						serial_out <= '1';
					-- last stop bit sample and tell that we are done
					elsif idx = (BITWIDTH + 3) * SMP_PER_BIT-1 then
						serial_out <= '1';
						busy <= '0';
					end if;
					idx <= idx + 1;
				else
					idx <= 0;
				end if;
			elsif busy = '0' then
				if fifo_empty = '0' then
					msg <= byte_in;
					busy <= '1';
					--send byte
				else 
				end if;
			end if;
		end if;
	end process;
end architecture;