library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

/* control/top module */

/* requirements */
-- print ascii code to seven-segment display.
-- flash led when a character is received.
-- loopback: send received character back immediately.
-- should send predetermined character with a button press.
-- can send a predetermined string of at least eight characters.
-- can adjust baud rate while running (100 kb/s – 1 Mb/s in 100 kb/s steps).


entity top is
	port ( /* TODO: decide which ports to consider */
		clk: in std_logic; /* SYS_CLK_FRQ defined in pkg */
		rst: in std_logic; /* SYSRESET defined in pkg */
		pen: in std_logic; /* parity enable */ 
		inc_btn: in std_logic; /* button to increase baud rate */

		rx: in std_logic := '0'; 
		tx: out std_logic := '0';

		HEX0: out std_logic_vector(6 downto 0) := (others => '0');
		HEX1: out std_logic_vector(6 downto 0) := (others => '0');
		HEX2: out std_logic_vector(6 downto 0) := (others => '0');
		HEX3: out std_logic_vector(6 downto 0) := (others => '0');
		HEX4: out std_logic_vector(6 downto 0) := (others => '0');
		HEX5: out std_logic_vector(6 downto 0) := (others => '0')
	);
end entity;

architecture rtl of top is
	signal rx_dv: std_logic;
	signal tx_dv: std_logic;

	signal baud_tick: std_logic;
	signal baud_change: std_logic;
	signal baudrate: integer range 0 to 9 := 0;
 
	/* rx io */
	signal perr: std_logic;
	signal rx_dout: std_logic_vector(BITWIDTH - 1 downto 0);
	/* tx io */
	signal tx_din: std_logic_vector(BITWIDTH - 1 downto 0);
	signal tx_busy: std_logic;

	
	/* rx fifo */
	signal rf_din: std_logic_vector(BITWIDTH - 1 downto 0);
	signal rf_dout: std_logic_vector(BITWIDTH - 1 downto 0);
	signal rf_write, rf_read: std_logic := '0'; /* r/w enable */
	signal rf_empty, rf_full: std_logic; /* stauts flags */

	/* tx fifo */
	signal tf_empty, tf_full: std_logic;
	signal tf_read, tf_write: std_logic := '0';
	signal tf_din: std_logic_vector(BITWIDTH - 1 downto 0);
	/* test: rx --> display */
	signal test_rx_dout: std_logic_vector(BITWIDTH - 1 downto 0);

begin
	baud_clock: entity work.baud_clock
		port map (
			clk => clk,
			rst => rst,
			baud_tick => baud_tick,
			inc_btn => inc_btn,
			baud_change => baud_change,
			baudrate => baudrate
		);

	rx_module: entity work.rx
		port map (
			rst => rst,
			din => rx,
			baud_tick => baud_tick,
			data_valid => rx_dv,
			dout => rx_dout,
			pen => pen,
			perr => perr
		);

	rx_fifo: entity work.fifo
		port map (
			clk => clk,
			rst => rst,
			r => rf_read,
			w => rx_dv,
			din => rx_dout,
			dout => rf_dout,
			empty => rf_empty,
			full => open
		);
	display: entity work.display
		port map (
			char => rf_dout,
			fifo_empty => rf_empty,
			read_fifo => rf_read,
			seg0 => HEX0,
			seg1 => HEX1,
			seg2 => HEX2,
			seg3 => HEX3,
			seg4 => HEX4,
			seg5 => HEX5,
			clk => clk,
			rst => rst,
			baud_change => baud_change,
			baud_rate => baudrate
		);
	tx_module: entity work.utx
		port map (
			byte_in => tx_din,
			baud_tick => baud_tick,
			pen => pen,
			busy => tx_busy,
			serial_out => tx,
			fifo_empty => tf_empty,
			rst => rst
		);
	
	tx_fifo: entity work.fifo
		port map (
			clk => clk,
			rst => rst,
			r => tx_busy,
			w => tf_write,
			din => tf_din,
			dout => tx_din,
			empty => tf_empty,
			full => tf_full
		);

	sendtotx_inst: entity work.sendtotx
		port map (
			clk => clk,
			dout => tf_din,
			fifo_full => tf_full,
			write => tf_write
		);
	/* put some characters on the display */
	display_test: process(clk, rst)
		type string is array(0 to 15) of std_logic_vector(7 downto 0);

		constant chars: string := ( /* hexadecimal */
		/* '0'..'9' */
		x"30", x"31", x"32", x"33", x"34", x"35", x"36", x"37", x"38", x"39",
		/* 'A'..'F' */
		x"41", x"42", x"43", x"44", x"45", x"46"
		);
		variable i: natural := 0;
		variable d: natural := 0;
	begin
		if rst = '0' then
			test_rx_dout <= (others => '0');
			i := 0;
		elsif rising_edge(clk) then
			if d = 50_000_000 / 5 then
				test_rx_dout <= chars(i);
				i := (i +1) mod 16;
				d := 0;
			else
				d := d +1;
			end if;
		end if;
	end process;

end architecture;
