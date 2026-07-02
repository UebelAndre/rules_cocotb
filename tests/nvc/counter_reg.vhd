library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_reg is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        enable : in  std_logic;
        count  : out std_logic_vector(7 downto 0)
    );
end entity counter_reg;

architecture rtl of counter_reg is
    signal count_r : unsigned(7 downto 0) := (others => '0');
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count_r <= (others => '0');
            elsif enable = '1' then
                count_r <= count_r + 1;
            end if;
        end if;
    end process;

    count <= std_logic_vector(count_r);
end architecture rtl;
