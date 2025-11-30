library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all; -- BITWIDT, SMP_PER_BIT, CLK_PER_SMP

entity rx_tb is
end entity;

architecture simulation of rx_tb is 
    constant CLK_PER_BIT: positive := SYS_CLK_FRQ * 1_000_000 / 100_000; -- assuming 100k baudrate for testbench   
	constant CLK_PER_SMP: positive := CLK_PER_BIT / SMP_PER_BIT;

    constant CLK_PERIOD : time := 20 ns; -- Klokkeperiode (20ns = 50 Mhz)
    constant BIT_CYCLES : natural := SMP_PER_BIT * CLK_PER_SMP; -- Antall klokkesykluser per UART-bit -> 8 samples * antall klokker per sample

    signal rst : std_logic := '0'; -- reset signal
    signal clk : std_logic := '0'; -- Klokkesignal
    signal serial_in : std_logic := '1'; -- UART-linjen -> idle = 1 
    signal data_valid : std_logic; -- Byte ready data
    signal pen: std_logic:= '1'; /* parity enable */
    signal perr: std_logic; /* parity error */
    signal baud_tick: std_logic;
    signal dout: std_logic_vector(BITWIDTH - 1 downto 0); -- received data out
    
    signal tx_busy: std_logic;
    signal tx_write: std_logic;
    signal sendtotxdout: std_logic_vector(BITWIDTH - 1 downto 0);
    signal tx_dout: std_logic;
    signal fifo_full: std_logic;
    signal tf_dout: std_logic_vector(BITWIDTH - 1 downto 0);
    signal tf_empty: std_logic;
    signal rf_empty: std_logic;

    

    -- expected byte
    constant EXP_BYTE : std_logic_vector(0 to BITWIDTH-1):= "11000001";--x"41"; -- 'A' '01000001'

    signal par_bit_temp : std_logic := '0'; -- for testing purposes only
    signal flagtemp : std_logic := '0'; -- for testing purposes only
    signal statustemp : std_logic_vector(7 downto 0):=(others=>'0'); -- for testing purposes only
    signal douttemp : std_logic_vector(BITWIDTH-1 downto 0):=(others=>'0'); -- for testing purposes only
    signal queue_content: std_logic_vector(BITWIDTH - 1 downto 0) := (others => '0');
    begin
        clk <= not clk after CLK_PERIOD/2; -- Generer 50 MHz klokke ved å toggle hver periode/2 (10 ns)
        clkgen: entity work.baud_clock
            port map (
                clk => clk,
                rst => rst,
                baud_tick => baud_tick,
                inc_btn => '0'
            );
        urx: entity work.rx
            port map (
                din => serial_in,
                data_valid => data_valid,
                dout => dout,
		rst => rst,
		baud_tick => baud_tick,
		pen => pen,
        perr => perr,

        flagtemp => flagtemp,
        statustemp => statustemp,
        douttemp => douttemp,
        par_bit_temp => par_bit_temp
            );

        rxfifo: entity work.fifo
            port map (
                clk => clk,
                rst => rst,
                r => '0',
                w => data_valid,
                din => dout,
                dout => open,
                empty => rf_empty,
                full => open,
                rec_byte => queue_content
            );
        
        utx: entity work.utx
            port map (
                byte_in => tf_dout,
                baud_tick => baud_tick,
                pen => pen,
                rst => rst,
                busy => tx_busy,
                serial_out => tx_dout,
                fifo_empty => tf_empty
            );
        
        txfifo: entity work.fifo
            port map (
                clk => clk,
                rst => rst,
                r => tx_busy,
                w => tx_write,
                din => sendtotxdout,
                dout => tf_dout,
                empty => tf_empty,
                full => fifo_full,
                rec_byte => open
            );
        
        sendtotx_inst: entity work.sendtotx
         port map(
            clk => clk,
            dout => sendtotxdout,
            write => tx_write,
            fifo_full => fifo_full,
            send_btn => '1'
        );
        stim: process 
            procedure send_bit(b : std_logic) is -- send a bit on serial_in
            begin
                serial_in <= b;
                for cyc in 1 to BIT_CYCLES loop --  hold bit an entire baud period
                    wait until rising_edge(clk); 
                end loop;
                end procedure;

        procedure send_byte(b : std_logic_vector(0 to BITWIDTH-1)) is 
        begin
            send_bit('0'); --send startbit (0)
            for i in 0 to BITWIDTH-1 loop -- send databits
                send_bit(b(i)); 
            end loop; 
            if pen = '1' then
                send_bit(par(b)); -- send paritybit if activated
            end if;
            send_bit('1'); 
        end procedure; 

        procedure wait_for_data_valid(max_bits : natural; success : out boolean) is
            variable max_cycles : natural := max_bits * BIT_CYCLES + 5; -- margin
        begin
            success := false;
            for n in 1 to max_cycles loop
                wait until rising_edge(clk);
                if data_valid = '1' then
                    success := true;
                    exit;
                end if;
            end loop;
        end procedure;

	variable ok : boolean;

    begin 
        wait for 100 ns; -- initial delay
        wait until rising_edge(clk);
            rst <= '1'; -- release reset (inactive high)
        for k in 1 to 10*BIT_CYCLES loop
            wait until rising_edge(clk);
        end loop;
        

        -- Test 1: Send byte 11000001 and check if it is received correctly
        report "Sender byte 11000001" severity note;
        send_byte(EXP_BYTE);
        wait_for_data_valid(1 + BITWIDTH + 1 + 2, ok); -- start + 8 + stop + margin
	    if ok then
            if dout = EXP_BYTE then -- if received byte matches expected byte
                report "PASS: correct byte received" severity note; 
            else 
                report "FAIL: wrong byte received" severity note;
            end if;
        else 
            report "Fail: Timeout, no data_valid" severity error; 
        end if; 


        -- Test 2: Send byte 01010101 and check if it is received correctly
        report "Sender byte 01010101" severity note;
        send_byte("01010101"); 
        wait_for_data_valid(1 + BITWIDTH + 1 + 2, ok); -- start + 8 + stop + margin
        if ok then 
            if dout = "01010101" then 
                report "PASS: correct byte received (0x55)" severity note; 
            else 
                report "FAIL: wrong byte received" severity note;
            end if;
        else 
            report "Fail: Timeout, no data_valid" severity error;
        end if;

        /*
        -- send hei mathias her!
        send_byte("01101000"); -- h
        send_byte("01100101"); -- e
        send_byte("01101001"); -- i
        send_byte("00100000"); -- space
        send_byte("01101101"); -- m
        send_byte("01100001"); -- a
        send_byte("01110100"); -- t
        send_byte("01101000"); -- h
        send_byte("01101001"); -- i
        send_byte("01100001"); -- a
        send_byte("01110011"); -- s
        send_byte("00100000"); -- space
        send_byte("01101000"); -- h
        send_byte("01100101"); -- e
        send_byte("01110010"); -- r
        send_byte("00100001"); -- !
        wait until data_valid = '1';
        */
        -- Wait a bit before ending the simulation
        for k in 1 to 5 * BIT_CYCLES loop
            wait until rising_edge(clk); 
        end loop;

        report "Testbench ferdig" severity note; 
        std.env.stop;
        wait;
    end process;
end architecture;