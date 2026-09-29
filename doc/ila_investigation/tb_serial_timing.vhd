library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_serial_timing is end;
architecture test of tb_serial_timing is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal req, busy : std_logic := '0';
    signal ch, data : std_logic_vector(7 downto 0);
    signal word : std_logic_vector(15 downto 0) := x"2555";
    signal raw_sc, raw_sy, raw_sd : std_logic;
    signal sc, sy, sd : std_logic := '1';
    signal check_enabled : boolean := false;
    signal frames : natural := 0;
begin
    clk <= not clk after 5 ns;
    data <= word(15 downto 8) when ch=x"80" else word(7 downto 0);
    dut : entity work.DACset generic map(Addr=>x"80") port map(
        CLK=>clk, RST=>rst, ACT=>req, Run=>busy, Ch=>ch, Data=>data,
        DAC_SYNC=>raw_sy, DAC_CLK=>raw_sc, DAC_DIN=>raw_sd);
    -- Match main.vhd's three final output registers.
    process(clk) begin
        if rising_edge(clk) then sc<=raw_sc; sy<=raw_sy; sd<=raw_sd; end if;
    end process;
    process(sc, sy, sd)
        variable last_data, last_sync, last_fall, last_rise : time := 0 ns;
        variable n : natural := 0;
        variable received : std_logic_vector(15 downto 0) := (others=>'0');
    begin
        if check_enabled then
            if sd'event then
                if sy='0' and n>0 then
                    assert now-last_fall >= 60 ns report "data hold cycle spacing reduced" severity failure;
                end if;
                last_data := now;
            end if;
            if falling_edge(sy) then
                last_sync := now; n:=0; received:=(others=>'0');
            elsif rising_edge(sy) then
                assert n=16 report "DAC frame must contain exactly 16 falling edges" severity failure;
                assert received=word report "serial payload mismatch" severity failure;
                assert now-last_fall >= 60 ns report "SYNC deasserted too early" severity failure;
                frames <= frames+1;
            end if;
            if rising_edge(sc) then
                if last_fall>0 ns then
                    assert now-last_fall >= 50 ns report "SCLK low pulse too short" severity failure;
                end if;
                last_rise := now;
            elsif falling_edge(sc) then
                assert now-last_rise >= 50 ns report "SCLK high pulse too short" severity failure;
                if sy='0' then
                    assert now-last_data >= 40 ns report "data setup cycle spacing reduced" severity failure;
                    assert now-last_sync >= 30 ns report "SYNC setup cycle spacing reduced" severity failure;
                    received:=received(14 downto 0)&sd; n:=n+1;
                end if;
                last_fall := now;
            end if;
        end if;
    end process;
    process begin
        wait for 100 ns; rst<='0'; wait for 300 ns; check_enabled<=true;
        for i in 0 to 19 loop
            if i mod 2=0 then word<=x"2555"; else word<=x"1AAA"; end if;
            wait for (i mod 10)*10 ns;
            wait until falling_edge(clk); req<='1';
            wait until falling_edge(clk); req<='0';
            wait until busy='0'; wait for 300 ns;
        end loop;
        assert frames=20 report "Missing frame" severity failure;
        report "PASS: 20 frames; setup data>=40ns SYNC>=30ns, hold data>=60ns, SCLK pulses>=50ns";
        finish;
    end process;
    process begin wait for 100 us; assert false report "Timeout" severity failure; end process;
end;
