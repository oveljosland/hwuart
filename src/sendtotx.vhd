library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;
entity sendtotx is
    port (
        clk: in std_logic;
        dout: out std_logic_vector(BITWIDTH - 1 downto 0);
        write: out std_logic := '0';
        fifo_full: in std_logic;
        send_btn: in std_logic
    );
end entity;
architecture rtl of sendtotx is
    type queue is array (0 to 15) of std_logic_vector(BITWIDTH - 1 downto 0);
	signal message : queue := (
    x"48", -- H
    x"45", -- E
    x"4C", -- L
    x"4C", -- L
    x"4F", -- O
    x"20", -- space
    x"57", -- W
    x"4F", -- O
    x"52", -- R
    x"4C", -- L
    x"44", -- D
    x"20", -- space
    x"31", -- 1
    x"32", -- 2
    x"33", -- 3
    x"21"  -- !
);
    signal i : integer range 0 to 15 := 0;
    signal delay : std_logic := '0';
begin
    process(fifo_full, clk)

    begin
    if rising_edge(clk) then
        if send_btn = '1' then
            if fifo_full = '0' and delay = '0' then
                delay <= '1';
                dout <= message(i);
                write <= '1';
                if i = 15 then
                    i <= 0;
                else
                    i <= i + 1;
                end if;
            else
                delay <= '0';
                write <= '0';
            end if;
        end if;
    end if;
    end process;
end architecture;