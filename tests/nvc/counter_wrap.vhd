library ieee;
use ieee.std_logic_1164.all;

-- Wraps `counter_reg` from a separate `vhdl_library`. Exercises the
-- transitive-deps walk in `collect_hdl_sources` — cocotb must stage
-- BOTH counter_wrap.vhd AND its dep counter_reg.vhd for elaboration
-- to succeed under nvc.
entity counter_wrap is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        enable : in  std_logic;
        count  : out std_logic_vector(7 downto 0)
    );
end entity counter_wrap;

architecture rtl of counter_wrap is
begin
    u_counter_reg : entity work.counter_reg
        port map (
            clk    => clk,
            rst    => rst,
            enable => enable,
            count  => count
        );
end architecture rtl;
