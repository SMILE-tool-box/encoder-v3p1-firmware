-- vhdl-linter-disable not-declared type-resolved component
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2025/04/17 13:50:25
-- Design Name: 
-- Module Name: LURecover - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_unsigned.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LURecover is
    generic (   lu_time_normal  : in    std_logic_vector (31 downto 0);
                off_time_normal : in    std_logic_vector (31 downto 0);
                on_time_normal  : in    std_logic_vector (31 downto 0);
                lu_time_debug   : in    std_logic_vector (31 downto 0);
                off_time_debug  : in    std_logic_vector (31 downto 0);
                on_time_debug   : in    std_logic_vector (31 downto 0)  );
    Port    (   clk             : in    std_logic;
                rst             : in    std_logic;
                hit_flag        : in    std_logic;
                enable          : in    std_logic;
                time_debug      : in    std_logic;
                dac_run         : in    std_logic;
                ap_on           : out   std_logic;
                dac_ctrl        : out   std_logic;
                recover_busy    : out   std_logic   );
end LURecover;

architecture Behavioral of LURecover is
    component ila_LURecover
    port (
        clk     : in std_logic;
        probe0  : in std_logic_vector (0 downto 0);
        probe1  : in std_logic_vector (0 downto 0);
        probe2  : in std_logic_vector (0 downto 0);
        probe3  : in std_logic_vector (0 downto 0);
        probe4  : in std_logic_vector (0 downto 0);
        probe5  : in std_logic_vector (31 downto 0);
        probe6  : in std_logic_vector (0 downto 0);
        probe7  : in std_logic_vector (31 downto 0);
        probe8  : in std_logic_vector (0 downto 0);
        probe9  : in std_logic_vector (0 downto 0);
        probe10 : in std_logic_vector (31 downto 0);
        probe11 : in std_logic_vector (0 downto 0);
        probe12 : in std_logic_vector (0 downto 0);
        probe13 : in std_logic_vector (0 downto 0);
        probe14 : in std_logic_vector (0 downto 0);
        probe15 : in std_logic_vector (0 downto 0);
        probe16 : in std_logic_vector (2 downto 0)
    );
    end component;

    signal      hit_check       : std_logic;
    signal      lu_judge        : std_logic;
    signal      ap_ctrl         : std_logic;
    signal      dac_flag        : std_logic;
    signal      reg_dac         : std_logic;
    signal      reg_ap_on       : std_logic;
    signal      reg_dac_ctrl    : std_logic;
    signal      lu_debug_state  : std_logic_vector (2 downto 0);
    signal      lu_time_cnt     : std_logic_vector (31 downto 0);
    signal      ap_off_wait     : std_logic_vector (31 downto 0);
    signal      ap_on_wait      : std_logic_vector (31 downto 0);
begin

recover_busy    <= lu_judge;
ap_on           <= reg_ap_on;
dac_ctrl        <= reg_dac_ctrl;

process(clk, rst)
begin
    if rst='1' then
        hit_check           <= '0';
        reg_ap_on            <= '1';
        reg_dac             <= '0';
        reg_dac_ctrl         <= '0';
    elsif clk'event and clk='1' then
        hit_check           <= hit_flag and enable;
        reg_ap_on            <= ap_ctrl;
        reg_dac             <= dac_run;
        reg_dac_ctrl         <= dac_flag;
    end if;
end process;

process(clk, rst)
begin
    if rst='1' then
        lu_judge            <= '0';
    elsif clk'event and clk='1' then
        if dac_run='0' and reg_dac='1' then
            lu_judge        <= '0';
        elsif lu_time_cnt=x"00000000" then
            lu_judge        <= '1';
        end if;
    end if;
end process;

process(clk, rst)
begin
    if rst='1' then
        ap_ctrl             <= '1';
    elsif clk'event and clk='1' then
        if lu_judge='1' then
            if ap_off_wait=x"00000000" then
                ap_ctrl     <= '1';
            else
                ap_ctrl     <= '0';
            end if;
        else
            ap_ctrl         <= '1';
        end if;
    end if;
end process;

process(clk, rst)
begin
    if rst='1' then
        dac_flag            <= '0';
    elsif clk'event and clk='1' then
        if ap_on_wait=x"00000000" and dac_run='0' then
            dac_flag        <= '1';
        else
            dac_flag        <= '0';
        end if;
    end if;
end process;

process(clk, rst)
begin
    if rst='1' then
        lu_time_cnt         <= (others => '1');
    elsif clk'event and clk='1' then
        if hit_check='1' then
            if lu_time_cnt=x"00000000" then
                lu_time_cnt <= x"00000000";
            else
                lu_time_cnt <= lu_time_cnt - 1;
            end if;
        else
            if time_debug='1' then
                lu_time_cnt <= lu_time_debug;
            else
                lu_time_cnt <= lu_time_normal;
            end if;
        end if;
    end if;
end process;

process (clk, rst)
begin
    if rst='1' then
        ap_off_wait         <= (others => '1');
    elsif clk'event and clk='1' then
        if lu_judge='1' then
            if ap_off_wait=x"00000000" then
                ap_off_wait <= x"00000000";
            else
                ap_off_wait <= ap_off_wait - 1;
            end if;
        else
            if time_debug='1' then
                ap_off_wait <= off_time_debug;
            else
                ap_off_wait <= off_time_normal;
            end if;
        end if;
    end if;
end process;

process (clk, rst)
begin
    if rst='1' then
        ap_on_wait          <= (others => '1');
    elsif clk'event and clk='1' then
        if lu_judge='1' and ap_ctrl='1' then
            if ap_on_wait=x"00000000" then
                ap_on_wait  <= x"00000000";
            else
                ap_on_wait  <= ap_on_wait - 1;
            end if;
        else
            if time_debug='1' then
                ap_on_wait  <= on_time_debug;
            else
                ap_on_wait  <= on_time_normal;
            end if;
        end if;
    end if;
end process;

process (lu_judge, hit_check, ap_off_wait, ap_on_wait, dac_run, reg_dac)
begin
    if lu_judge='0' then
        if hit_check='1' then
            lu_debug_state <= "001"; -- HIT_QUALIFY
        else
            lu_debug_state <= "000"; -- IDLE
        end if;
    elsif reg_dac='1' and dac_run='0' then
        lu_debug_state     <= "110"; -- DAC_COMPLETE
    elsif ap_off_wait/=x"00000000" then
        lu_debug_state     <= "010"; -- POWER_OFF_WAIT
    elsif ap_on_wait/=x"00000000" then
        lu_debug_state     <= "011"; -- POWER_ON_WAIT
    elsif dac_run='0' then
        lu_debug_state     <= "100"; -- DAC_REQUEST
    elsif dac_run='1' then
        lu_debug_state     <= "101"; -- DAC_RUNNING
    else
        lu_debug_state     <= "111"; -- INVALID
    end if;
end process;

LURecover_ILA : ila_LURecover
port map (
    clk        => clk,
    probe0(0)  => rst,
    probe1(0)  => hit_flag,
    probe2(0)  => enable,
    probe3(0)  => time_debug,
    probe4(0)  => hit_check,
    probe5     => lu_time_cnt,
    probe6(0)  => lu_judge,
    probe7     => ap_off_wait,
    probe8(0)  => ap_ctrl,
    probe9(0)  => reg_ap_on,
    probe10    => ap_on_wait,
    probe11(0) => dac_flag,
    probe12(0) => reg_dac_ctrl,
    probe13(0) => dac_run,
    probe14(0) => reg_dac,
    probe15(0) => lu_judge,
    probe16    => lu_debug_state
);

end Behavioral;
