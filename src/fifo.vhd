library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.BITWIDTH;
use work.pkg.SYSRESET;

entity fifo is
	port (
		clk: in std_logic;
		rst: in std_logic;
		r: in std_logic;
		w: in std_logic;
		din: in std_logic_vector(BITWIDTH - 1 downto 0);
		dout: out std_logic_vector(BITWIDTH - 1 downto 0);
		full: out std_logic;
        empty: out std_logic:= '1';


		--test signals
		rec_byte: out std_logic_vector(BITWIDTH - 1 downto 0) := (others => '0')
	);
end entity;

architecture rtl of fifo is
	constant LEN: positive := 2 ** 7;
	type array_t is array (0 to LEN-1) of std_logic_vector(BITWIDTH-1 downto 0);
	signal queue: array_t;
	signal rp, wp: integer := 0;
	signal i: natural := 0;
	signal r_d, w_d: std_logic := '0'; -- delayed read and write signals
begin

rw: process(clk, rst)
begin
    if rst = SYSRESET then
        rp <= 0;
        wp <= 0;
        i <= 0;
        r_d <= '0';
        w_d <= '0';
    elsif rising_edge(clk) then
        r_d <= r;
        w_d <= w;

        if w = '1' and w_d = '0' and i < LEN then
            queue(wp) <= din;
            wp <= (wp + 1) mod LEN;
            i <= i + 1;
        end if;

        if r = '1' and r_d = '0' and i > 0 then
            dout <= queue(rp);
            rp <= (rp + 1) mod LEN;
            i <= i - 1;
        end if;
    end if;
end process;

-- Pipeline the status flags
status: process(clk, rst) begin
    if rst = SYSRESET then
        empty <= '1';
        full <= '0';
    elsif rising_edge(clk) then
        if i = 0 then
            empty <= '1';
        else
            empty <= '0';
        end if;
        
        if i = LEN then
            full <= '1';
        else
            full <= '0';
        end if;
    end if;
end process;
end architecture;