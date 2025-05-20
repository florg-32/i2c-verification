
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

 entity clock_crosser is
  generic(
    DATAWIDTH_G : integer := 1;
    BUS_SYNC_G  : boolean := FALSE
  );
  port(
    clk_i             : in  std_logic;  --! Destination Clock to which the input signal gets synchronized
    cc_data_i         : in  std_logic_vector(DATAWIDTH_G - 1 downto 0);
    cc_data_o         : out std_logic_vector(DATAWIDTH_G - 1 downto 0);
    cc_data_changed_o : out std_logic                                    -- !!!BUS_SYNC_G = TRUE only!!! signal a new value 
  );
 end clock_crosser;
 
architecture rtl of clock_crosser is
 
  attribute ALTERA_ATTRIBUTE : string;     
  attribute ALTERA_ATTRIBUTE OF RTL : ARCHITECTURE IS "-name SDC_STATEMENT ""set_false_path -from * -to *clock_crosser_cross_data1_s* "";"&
                                                            "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS;" &
                                                            "-name DONT_MERGE_REGISTER ON;" &
                                                            "-name ALLOW_SHIFT_REGISTER_MERGING_ACROSS_HIERARCHIES OFF;" &
                                                            "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";

  signal clock_crosser_cross_data1_s : std_logic_vector(DATAWIDTH_G - 1 downto 0);
  signal clock_crosser_cross_data2_s : std_logic_vector(DATAWIDTH_G - 1 downto 0);
  signal data_s                      : std_logic_vector(DATAWIDTH_G - 1 downto 0);
  signal data_changed_s              : std_logic;
 
begin
 
   
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      clock_crosser_cross_data1_s <= cc_data_i;
      clock_crosser_cross_data2_s <= clock_crosser_cross_data1_s;
      data_s                      <= clock_crosser_cross_data2_s;
      if BUS_SYNC_G = FALSE then
        cc_data_o         <= clock_crosser_cross_data1_s;
        cc_data_changed_o <= '0';
      elsif data_s = clock_crosser_cross_data2_s then
        cc_data_o         <= data_s;
        cc_data_changed_o <= data_changed_s;
        data_changed_s    <= '0';
      else
        cc_data_changed_o <= '0';
        data_changed_s    <= '1';
      end if;
    end if;
  end process;
 
end rtl;
