library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

entity baud_clock is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        inc_btn    : in  std_logic;  -- button to increase baud
        baud_tick  : out std_logic;
		baud_change: out std_logic := '0'; -- for display
		baudrate : out integer range 0 to 9 := 0
    );
end entity;
---- filepath: c:\Users\mathi\bielsys\innvevd\uart\uart\src\clk.vhd
-- ...existing code...
architecture rtl of baud_clock is
    -- small lookup table for divider values (adjust to your actual SYS clock & oversample)
    type div_table_t is array (0 to 9) of natural;
    constant DIV_TABLE : div_table_t := (
        62, 31, 21, 16, 13, 10, 9, 8, 7, 6  -- precomputed divider values
    );

    type baud_table_t is array (0 to 9) of natural;
    constant BAUD_TABLE : baud_table_t := (
        100_000, 200_000, 300_000, 400_000, 500_000,
        600_000, 700_000, 800_000, 900_000, 1_000_000
    );

    signal baud_idx      : natural range 0 to 9 := 0;
    signal DIV           : natural range 0 to 1000 := DIV_TABLE(0);
    signal counter       : natural range 0 to 1000 := 0;
    signal clk_out       : std_logic := '0';

    signal btn_sync1     : std_logic := '0';
    signal btn_sync2     : std_logic := '0';
    signal btn_prev      : std_logic := '0';
    signal btn_clean     : std_logic := '0';
    signal debounce_cnt  : natural range 0 to 500_000 := 0;
    signal baud_change_pulse : std_logic := '0';
begin

    btn_proc: process(clk, rst)
        variable next_idx : natural range 0 to 9 := 0;
    begin
        if rst = SYSRESET then
            btn_sync1        <= '0';
            btn_sync2        <= '0';
            btn_prev         <= '0';
            debounce_cnt     <= 0;
            btn_clean        <= '0';
            baud_change_pulse<= '0';
            baud_idx         <= 0;
            DIV              <= DIV_TABLE(0);
        elsif rising_edge(clk) then
            btn_sync1 <= inc_btn;
            btn_sync2 <= btn_sync1;

            if btn_sync2 = '1' then
                if debounce_cnt < 500_000 then
                    debounce_cnt <= debounce_cnt + 1;
                    btn_clean <= '0';
                else
                    btn_clean <= '1';
                end if;
            else
                debounce_cnt <= 0;
                btn_clean <= '0';
            end if;

            -- Register DIV update to break combinatorial path
            if btn_clean = '1' and btn_prev = '0' then
                if baud_idx = 9 then
                    next_idx := 0;
                else
                    next_idx := baud_idx + 1;
                end if;
                baud_idx <= next_idx;
                -- DIV update now happens in registered logic
            end if;
            
            -- Separate DIV assignment to ensure it's registered
            DIV <= DIV_TABLE(baud_idx);
            
            btn_prev <= btn_clean;
            
            -- Pulse generation
            if btn_clean = '1' and btn_prev = '0' then
                baud_change_pulse <= '1';
            else
                baud_change_pulse <= '0';
            end if;
        end if;
    end process;

    -- generate periodic tick (single-cycle pulse)
    gen: process(clk, rst)
    begin
        if rst = SYSRESET then
            counter <= 0;
            clk_out <= '0';
        elsif rising_edge(clk) then
            if counter >= DIV then
                counter <= 0;
                clk_out <= '1';
            else
                counter <= counter + 1;
                clk_out <= '0';
            end if;
        end if;
    end process;

    baud_tick   <= clk_out;
    baud_change <= baud_change_pulse;
    baudrate    <= integer(baud_idx);

end architecture;
-- ...existing code...