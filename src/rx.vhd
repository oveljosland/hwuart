/* requirements */
-- must support the UART protocol.
	-- 1 start bit.
	-- 8 data_in bits.
	-- 1 stop bit.
--x must support baud rate of at least 9600.
--x must be able to store at least one received data_out.
--x must use 8x oversampling on the rx signal, and sample the middle of the
--  bit period to determine the value.
--x must indicate when data_in is received and ready to be used (data_in valid).
--x can do majority decision based on 5 samples in the middle of the bit period.
--x can have a 16 data_out FIFO to store bytes, delete new data_in when full.
-- should support parity control (even, odd, none).
-- should be able to change baud rate when running.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

entity rx is
	port (
		rst: in std_logic; /* reset defined in pkg.vhd */
		din: in std_logic; /* data_in in */
		pen: in std_logic; /* parity enable */
		baud_tick: in std_logic;
		data_valid: out std_logic;
		dout: out std_logic_vector(BITWIDTH - 1 downto 0); /* data out */
		perr: out std_logic; /* parity error */

		--test variables
		flagtemp: out std_logic := '0'; --flag variable
		statustemp: out std_logic_vector(7 downto 0):=(others=>'0'); -- for testing purposes only
		douttemp: out std_logic_vector(BITWIDTH-1 downto 0):=(others=>'0');
		par_bit_temp: out std_logic := '0'  -- for testing purposes only
	);
end entity;

architecture rtl of rx is
	
	constant MAJVOTES: positive := 5;
	
	/* voting window */
	constant LO: integer := SMP_PER_BIT / 2 - MAJVOTES / 2 - 1; -- -1 to account for 0 indexing 
	constant HI: integer := SMP_PER_BIT / 2 + MAJVOTES / 2 - 1;

	signal s: state := idle;

	signal data_out: std_logic_vector(BITWIDTH-1 downto 0):=(others=>'0');
	signal smp_idx: natural range 0 to SMP_PER_BIT - 1 := 0;
	signal bit_idx: natural range 0 to BITWIDTH - 1 := 0;
	signal maj_cnt: natural range 0 to MAJVOTES := 0;
	signal par_bit: std_logic := '0';



begin

	/* control:  control receiver states */
	control: process(baud_tick, rst, din) is
		/* flush: clear registers */
		procedure flush is begin
			smp_idx <= 0;
			bit_idx <= 0;
			maj_cnt <= 0;
		end procedure;
	begin
		if rst = SYSRESET then
			s <= flush;
		elsif rising_edge(baud_tick) then
			data_valid <= '0'; /* default */
			case s is
				when idle =>
					if din = '0' then /* line low */
						smp_idx <= 1; -- already sampled first bit
						maj_cnt <= 0;
						s <= startbit;
					end if;

				when startbit =>
					if smp_idx >= LO and smp_idx <= HI then
						if din = '1' and maj_cnt < MAJVOTES then
							maj_cnt <= maj_cnt + 1;
						end if;
					end if;
					if smp_idx < SMP_PER_BIT - 1 then
						smp_idx <= smp_idx + 1;
					else /* done sampling */
						if maj_cnt >= (MAJVOTES + 1) / 2 then
							/* false start: majority high */
							s <= idle;
						else
							smp_idx <= 0;
							maj_cnt <= 0;
							bit_idx <= 0;
							s <= databit;
						end if;
					end if;
				when databit =>
						/* count ones in voting window */
					if smp_idx >= LO and smp_idx <= HI then
						if din = '1' and maj_cnt < MAJVOTES then
							maj_cnt <= maj_cnt + 1;
						end if;
					end if;

					if smp_idx < SMP_PER_BIT - 1 then
						smp_idx <= smp_idx + 1;
					else /* done sampling */
						smp_idx <= 0;
						/* decide value by majority */
						if maj_cnt >= (MAJVOTES + 1) / 2 then
							data_out <= '1' & data_out(BITWIDTH - 1 downto 1);
						else
							data_out <= '0' & data_out(BITWIDTH - 1 downto 1);
						end if;
						maj_cnt <= 0;
						if bit_idx < BITWIDTH - 1 then
							bit_idx <= bit_idx + 1;
							s <= databit;
						else
							s <= paritybit;
						end if;
					end if;

				when paritybit =>
					if smp_idx >= LO and smp_idx <= HI then
						if din = '1' and maj_cnt < MAJVOTES then 
							maj_cnt <= maj_cnt + 1;
						end if;
					/* check bit after voting window */
					elsif smp_idx = HI + 1 then
						/* decide by majority */
						if maj_cnt >= (MAJVOTES + 1) / 2 then 
							par_bit <= '1';
						else
							par_bit <= '0';
						end if;
					end if;
					if smp_idx < SMP_PER_BIT - 1 then
						smp_idx <= smp_idx + 1;
					else /* done sampling */
						smp_idx <= 0;
						maj_cnt <= 0;
						if  par_bit /= par(data_out) and pen = '1' then
							perr <= '1';
						else
							perr <= '0';
						end if;
						s <= stopbit;
					end if;

				when stopbit =>
					if smp_idx < SMP_PER_BIT - 1 then
						smp_idx <= smp_idx + 1;
					else /* done sampling */
						if maj_cnt >= (MAJVOTES + 1) / 2 then
							/* stop bit must be high */
							s <= flush; /* framing error, discard data */
						else
							smp_idx <= 0;
							dout <= data_out; /* put data out */
							data_valid <= '1';
							s <= idle;
						end if;
					end if;

				/* flush registers and return to idle */
				when flush => 
					flush;
					s <= idle;
			end case;
		end if;
	end process;


	process(s, data_out, par_bit) is
	begin
		-- for testing purposes only
		douttemp <= data_out;
		par_bit_temp <= par_bit;
		if s = idle then
			statustemp <= "00000001";
		elsif s = startbit then
			statustemp <= "00000010";
		elsif s = databit then
			statustemp <= "00000100";
		elsif s = paritybit then
			statustemp <= "00001000";
		elsif s = stopbit then
			statustemp <= "00010000";
		elsif s = flush then
			statustemp <= "00100000";
		else
			statustemp <= "11111111";
		end if;
	end process;
end architecture;