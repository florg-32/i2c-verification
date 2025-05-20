
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity i2c_multi_bus_controller_memory is
  GENERIC
    (
      DATA_WIDTH_G : integer := 32;
      ADDR_WIDTH_G : integer := 4
    );
  PORT
    (
      byteen		: IN STD_LOGIC_VECTOR ((DATA_WIDTH_G-1)/8 DOWNTO 0);
      data		: IN STD_LOGIC_VECTOR (DATA_WIDTH_G-1 DOWNTO 0);
      address		: IN STD_LOGIC_VECTOR (ADDR_WIDTH_G-1 DOWNTO 0);
      clock  		: IN STD_LOGIC ;
      wren		: IN STD_LOGIC  := '0';
      q                 : OUT STD_LOGIC_VECTOR (DATA_WIDTH_G-1 DOWNTO 0)
      );
end entity i2c_multi_bus_controller_memory;

architecture rtl of i2c_multi_bus_controller_memory is

        -- Build a 2-D array type for the RAM
        subtype word_t is std_logic_vector((DATA_WIDTH_G-1) downto 0);
        type memory_t is array(2**ADDR_WIDTH_G-1 downto 0) of word_t;

        -- Declare the RAM signal.
        signal ram : memory_t;
        signal q_local : word_t;

begin

  process(clock)
  begin
    if(rising_edge(clock)) then

      for i in 0 to ((DATA_WIDTH_G/8)-1) loop
        if(wren = '1' and byteen(i) = '1') then
          ram(to_integer(unsigned(address)))(8*i+7 downto 8*i) <= data(8*i+7 downto 8*i);
        end if;
        q <= ram(to_integer(unsigned(address)));
      end loop;

    end if;
  end process;


end architecture rtl;
