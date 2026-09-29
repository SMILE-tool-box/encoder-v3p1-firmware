-- Diagnostic regression: the production RBCP_REG and DACset are unmodified.
-- A two-cycle synchronous RAM models the configured registered BRAM output.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity blk_mem_gen_0 is
  port (clka, rsta: in std_logic;
        wea: in std_logic_vector(0 downto 0);
        addra, dina: in std_logic_vector(7 downto 0);
        douta: out std_logic_vector(7 downto 0);
        rsta_busy: out std_logic);
end;
architecture model of blk_mem_gen_0 is
  type ram_t is array(0 to 255) of std_logic_vector(7 downto 0);
  signal mem: ram_t := (others => x"00");
  signal q: std_logic_vector(7 downto 0) := x"00";
begin
  rsta_busy <= rsta;
  process(clka)
  begin
    if rising_edge(clka) then
      if wea(0) = '1' then mem(to_integer(unsigned(addra))) <= dina; end if;
      if rsta = '1' then
        q <= x"00"; douta <= x"00";
      else
        q <= mem(to_integer(unsigned(addra))); douta <= q;
      end if;
    end if;
  end process;
end;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_rbcp_dac is end;
architecture test of tb_rbcp_dac is
  signal c100: std_logic := '0';
  signal c200: std_logic := '1';
  signal rst: std_logic := '1';
  signal act, we, re, ack, req, busy: std_logic := '0';
  signal addr: std_logic_vector(31 downto 0) := x"00000000";
  signal wd, rd, ch, data: std_logic_vector(7 downto 0) := x"00";
  signal sc, sy, sd: std_logic;
  signal serial_word: std_logic_vector(15 downto 0) := x"0000";
  signal bits: natural := 0;
begin
  c100 <= not c100 after 5 ns;
  -- Rising edges coincide; both clocks come from the same PLL in hardware.
  c200 <= not c200 after 2.5 ns;
  regs: entity work.RBCP_REG port map (
    clock=>c200, reset=>rst, rbcp_act=>act, rbcp_addr=>addr,
    rbcp_wd=>wd, rbcp_we=>we, rbcp_re=>re, rbcp_ack=>ack, rbcp_rd=>rd,
    DAC_ack=>open, DAC_ctrl=>'0', DAC_Ch=>x"00", DAC_Data=>open,
    Vth_ack=>req, Vth_ctrl=>busy, Vth_Ch=>ch, Vth_Data=>data,
    ADC_BIAS_ack=>open, ADC_BIAS_ctrl=>'0', ADC_BIAS_Ch=>x"00", ADC_BIAS_Data=>open,
    AP_ON=>open, LatchUp_Detect=>open, LatchUp_RecoverBusy=>'0', LU_TimeDebug=>open);
  dac: entity work.DACset generic map(Addr=>x"80") port map (
    CLK=>c100, RST=>rst, ACT=>req, Run=>busy, Ch=>ch, Data=>data,
    DAC_SYNC=>sy, DAC_CLK=>sc, DAC_DIN=>sd);
  process(sc, sy)
  begin
    if sy='1' then
      bits <= 0;
    elsif falling_edge(sc) then
      serial_word <= serial_word(14 downto 0) & sd;
      bits <= bits + 1;
    end if;
  end process;
  process
    procedure write_reg(a: natural; d: std_logic_vector(7 downto 0);
                        tail: time := 20 ns; settle: time := 50 ns) is
    begin
      wait until falling_edge(c200);
      addr <= std_logic_vector(to_unsigned(a,32)); wd<=d; act<='1';
      wait for 20 ns; we<='1'; wait for 20 ns; we<='0';
      wait until ack='1';
      wait for tail;
      wait until falling_edge(c200); act<='0';
      wait for settle;
    end procedure;
    variable baseline: std_logic_vector(15 downto 0);
  begin
    wait for 100 ns; rst<='0'; wait for 100 ns;
    write_reg(16#80#,x"12"); write_reg(16#81#,x"34");
    write_reg(16#F0#,x"01");
    wait until sy='0'; wait until sy='1';
    baseline := serial_word;
    report "BASELINE serial word=" & to_hstring(baseline);
    assert baseline=x"1234" report "Baseline failed; diagnostic invalid" severity failure;
    wait for 1000 ns;
    -- Keeping rbcp_act high during the DAC read window steals the memory port.
    write_reg(16#F0#,x"01",400 ns);
    wait until sy='1';
    report "RBCP overlap serial word=" & to_hstring(serial_word);
    assert serial_word/=baseline report "Expected overlap corruption was not reproduced" severity failure;
    wait for 1000 ns;
    write_reg(16#F0#,x"01",20 ns,0 ns);
    if ch/=x"80" then wait until ch=x"80"; end if;
    -- A separate, single-byte LU counter read during the high-byte fetch.
    wait until falling_edge(c200);
    addr<=x"000000F8"; act<='1';
    wait for 20 ns; re<='1'; wait for 5 ns; re<='0';
    wait until ack='1'; wait for 20 ns;
    wait until falling_edge(c200); act<='0';
    wait until sy='0'; wait until sy='1';
    report "F8 polling overlap serial word=" & to_hstring(serial_word);
    assert serial_word/=baseline report "Expected polling corruption was not reproduced" severity failure;
    report "PASS: reproduced DAC payload corruption with production RTL, no ILA";
    finish;
  end process;
  process begin wait for 20 us; assert false report "Timeout" severity failure; end process;
end;
