library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity tb_reset_release is end;
architecture test of tb_reset_release is
    signal clk : std_logic := '0';
    signal run_clock : boolean := true;
    signal arst : std_logic := '1';
    signal rst : std_logic;
begin
    process begin
        wait for 5 ns;
        if run_clock then clk <= not clk; else clk <= '0'; end if;
    end process;
    dut : entity work.reset_release port map(clk, arst, rst);
    process
        procedure check_release is
        begin
            for i in 1 to 4 loop
                wait until rising_edge(clk); wait for 1 ns;
                if i < 4 then
                    assert rst='1' report "reset released too early" severity failure;
                else
                    assert rst='0' report "reset did not release after four edges" severity failure;
                end if;
            end loop;
        end procedure;
    begin
        wait for 12 ns; arst <= '0'; check_release;
        wait for 2 ns; arst <= '1'; wait for 1 ns;
        assert rst='1' report "assertion must not wait for a clock" severity failure;
        run_clock <= false; wait for 20 ns; arst <= '0'; wait for 30 ns;
        assert rst='1' report "reset released with stopped clock" severity failure;
        run_clock <= true; check_release;
        report "PASS: asynchronous assertion, synchronous release, stopped clock and relock";
        finish;
    end process;
    process begin wait for 1 us; assert false report "Timeout" severity failure; end process;
end;
