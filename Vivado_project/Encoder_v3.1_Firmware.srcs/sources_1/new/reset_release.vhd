library ieee;
use ieee.std_logic_1164.all;

-- Assert even without a running clock; release only after STAGES clock edges.
entity reset_release is
    generic (STAGES : positive := 4);
    port (clk : in std_logic; arst : in std_logic; rst : out std_logic);
end entity;

architecture rtl of reset_release is
    signal pipe : std_logic_vector(STAGES-1 downto 0) := (others => '1');
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of pipe : signal is "TRUE";
    attribute SHREG_EXTRACT : string;
    attribute SHREG_EXTRACT of pipe : signal is "NO";
begin
    assert STAGES >= 2 report "reset_release requires at least two stages" severity failure;
    process(clk, arst)
    begin
        if arst = '1' then
            pipe <= (others => '1');
        elsif rising_edge(clk) then
            pipe <= pipe(STAGES-2 downto 0) & '0';
        end if;
    end process;
    rst <= pipe(STAGES-1);
end architecture;
