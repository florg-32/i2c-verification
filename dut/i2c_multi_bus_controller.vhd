library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.math_pkg.all;

entity i2c_multi_bus_controller is
  generic (
    CLK_DIVIDE_G  : integer := 10000;
    NUM_BUSSES_G  : integer := 4
  );
  port (
    clk_i : in std_logic;                                       
    rst_i : in std_logic;
    
    -- Avalon Memory mapped Interface
    avalon_mms_address_i       :   in  std_logic_vector(5 downto 0);
    avalon_mms_readdata_o      :   out std_logic_vector(31 downto 0);
    avalon_mms_writedata_i     :   in  std_logic_vector(31 downto 0);
    avalon_mms_read_i          :   in  std_logic;
    avalon_mms_write_i         :   in  std_logic;
    avalon_mms_byteenable_i    :   in  std_logic_vector(3 downto 0);    
    
    irq_o : out std_logic;
    -- i2c signals
    scl_io : inout std_logic_vector(NUM_BUSSES_G-1 downto 0) := (others => '1');
    sda_io : inout std_logic_vector(NUM_BUSSES_G-1 downto 0)  
  );
end entity i2c_multi_bus_controller;

architecture rtl of i2c_multi_bus_controller is

  function conv_to_boolean(x : integer) return boolean is
    variable result : boolean;
  begin
    if (x = 0) then
      result := false;
    else
      result := true;
    end if;
    
    return result;
  end function conv_to_boolean;
  
  component clock_crosser is
    generic (
      DATAWIDTH_G     : integer := 1
    );
    port (
      clk_i           : in std_logic;  --! Destination Clock to which the input signal gets synchronized
      cc_data_i       : in std_logic_vector(DATAWIDTH_G - 1 downto 0);
      cc_data_o       : out std_logic_vector(DATAWIDTH_G - 1 downto 0)     
    );
  end component clock_crosser;

  component i2c_multi_bus_controller_memory is
    GENERIC (
        DATA_WIDTH_G : integer;
        ADDR_WIDTH_G : integer
    );
    PORT (
      byteen          : IN STD_LOGIC_VECTOR ((DATA_WIDTH_G-1)/8 DOWNTO 0);
      data            : IN STD_LOGIC_VECTOR (DATA_WIDTH_G-1 DOWNTO 0);
      address         : IN STD_LOGIC_VECTOR (ADDR_WIDTH_G-1 DOWNTO 0);
      clock           : IN STD_LOGIC ;
      wren            : IN STD_LOGIC  := '0';
      q               : OUT STD_LOGIC_VECTOR (DATA_WIDTH_G-1 DOWNTO 0)
    );
  end component i2c_multi_bus_controller_memory;

  constant HALF_CLK_DIVIDE_C     : integer := (CLK_DIVIDE_G+1) / 2;
  signal rst_s          : std_logic;

  -- i2c en counter
  signal i2c_en_s        : std_logic;
  signal i2c_en_cnt_s    : unsigned(log2_f(HALF_CLK_DIVIDE_C) downto 0);
  -- i2c core
  type I2C_STATE_TYPE     is (IDLE_ST, START_ST, RX_ST, TX_ST, SACK_ST, MACK_ST, STOP_ST);
  signal i2c_state_s     : I2C_STATE_TYPE;
  signal reg_ctrl_go_s   : std_logic;
  signal i2c_go_s        : std_logic;
  signal sda_s           : std_logic;
  signal scl_s           : std_logic;
  signal scl_i_s         : std_logic;
  signal scl_i_ss        : std_logic;
  signal sda_i_s         : std_logic;
  signal tx_word_s       : std_logic_vector(31 downto 0);
  signal rx_byte_s       : std_logic_vector(7 downto 0);
  signal rx_word_s       : std_logic_vector(31 downto 0);
  signal i2c_wr_s        : std_logic;
  signal bit_cnt_s       : unsigned(3 downto 0);
  signal byte_cnt_s      : unsigned(5 downto 0);
  signal dev_addr_sent_s : std_logic;
  signal reg_addr_sent_s : std_logic;
  signal data_done_s     : std_logic;
  signal ack_done_s      : std_logic;
  signal ack_err_s       : std_logic;
  signal stop_done_s     : std_logic;

  signal scl_i_bouncy_s  : std_logic;
  signal sda_i_bouncy_s  : std_logic;
  
  -- sda hold count
  signal hold_cnt_s      : unsigned(6 downto 0); -- about 600 ns
  signal sda_ss          : std_logic;
  
  -- data memory
  -- 16 words with 32 bit (1 x M512)
  type  memory_t is array (15 downto 0) of std_logic_vector(31 downto 0); 
  signal ram_wr_s      : std_logic;
  signal ram_addr_s    : std_logic_vector(3 downto 0);
  signal ram_data_i_s  : std_logic_vector(31 downto 0);
  signal ram_data_o_s  : std_logic_vector(31 downto 0);
  
  signal ram_i2c_data_o_s : std_logic_vector(31 downto 0);
  signal sda_o_s          : std_logic;
  signal sda_i_cc_s       : std_logic_vector(NUM_BUSSES_G-1 downto 0);
  signal scl_i_cc_s       : std_logic_vector(NUM_BUSSES_G-1 downto 0);
  
  -- register signals
  signal reg_ctrl_s   : std_logic_vector(31 downto 0);
  signal reg_status_s : std_logic_vector(31 downto 0);
  signal reg_enable_s : std_logic_vector(31 downto 0);
  signal i2c_go_ss    : std_logic;
  signal avalon_mms_readdata_s : std_logic_vector(31 downto 0);
  signal ram_byteena_s         : std_logic_vector(3 downto 0);
  
  signal sda_debounce_timer_s : unsigned(2 downto 0);
  signal scl_debounce_timer_s : unsigned(2 downto 0);

  function merge_busses_f(sda_i : std_logic_vector(NUM_BUSSES_G-1 downto 0);
                          control_i :std_logic_vector(NUM_BUSSES_G-1 downto 0)) return std_logic is
  begin
    for i in sda_i'range loop
      if sda_i(i)='0' and control_i(i)='1' then
        return '0';
      end if;
    end loop;
    return '1';
  end function;
  
begin

  irq_o <= reg_status_s(0) and reg_ctrl_s(1);
  rst_s <= rst_i or reg_ctrl_s(0);
  
  scl_cc :  clock_crosser
  generic map(NUM_BUSSES_G)
  port map(
    clk_i      => clk_i,
    cc_data_i  => scl_io,
    cc_data_o  => scl_i_cc_s     
  );
  scl_i_bouncy_s <= merge_busses_f(scl_i_cc_s, reg_enable_s(NUM_BUSSES_G-1 downto 0));

  sda_cc :  clock_crosser
  generic map(NUM_BUSSES_G)
  port map(
    clk_i      => clk_i,
    cc_data_i => sda_io,
    cc_data_o => sda_i_cc_s
  );
  sda_i_bouncy_s <= merge_busses_f(sda_i_cc_s, reg_enable_s(NUM_BUSSES_G-1 downto 0));
  
  debounce_input_p : process(clk_i, rst_s)
  begin
    if rst_s ='1' then
      sda_i_s <= '1';
      scl_i_s <= '1';
      sda_debounce_timer_s <= (others => '1');
      scl_debounce_timer_s <= (others => '1');
    elsif rising_edge(clk_i) then
      sda_debounce_timer_s <= sda_debounce_timer_s - 1;
      scl_debounce_timer_s <= scl_debounce_timer_s - 1;
    
      if sda_i_s /= sda_i_bouncy_s then
        if test_underflow_f(sda_debounce_timer_s) then
          sda_i_s <= sda_i_bouncy_s;
        end if;
      else
        sda_debounce_timer_s <= (others => '1');
      end if;

      if scl_i_s /= scl_i_bouncy_s then
        if test_underflow_f(scl_debounce_timer_s) then
          scl_i_s <= scl_i_bouncy_s;
        end if;
      else
        scl_debounce_timer_s <= (others => '1');
      end if;
      
    end if;
  end process;
  
--------------------------------------------------------------------------------
-- I2C State machine enable signal 
--------------------------------------------------------------------------------
  i2c_en_p : process(clk_i, rst_s)
  begin
    if rst_s = '1' then
      i2c_en_cnt_s <= to_unsigned(HALF_CLK_DIVIDE_C-2,log2_f(HALF_CLK_DIVIDE_C)+1);
    elsif rising_edge(clk_i) then
    
      if scl_s = scl_i_s and i2c_en_cnt_s(i2c_en_cnt_s'left) = '0' then
        i2c_en_cnt_s <= i2c_en_cnt_s - 1;
      else
        i2c_en_cnt_s <= to_unsigned(HALF_CLK_DIVIDE_C-2,log2_f(HALF_CLK_DIVIDE_C)+1);
      end if;
      
    end if;
  end process i2c_en_p;
    
  i2c_en_s     <= i2c_en_cnt_s(i2c_en_cnt_s'left);

--------------------------------------------------------------------------------
-- I2C State machine
--------------------------------------------------------------------------------

  i2c_sm_p : process(clk_i, rst_s)
  begin
    if rst_s = '1' then
      i2c_state_s     <= IDLE_ST;
      i2c_go_s        <= '0';
      reg_ctrl_go_s   <= '0';
      sda_s           <= '1';
      scl_s           <= '1';
      rx_byte_s       <= (others => '0');
      rx_word_s       <= (others => '0');
      tx_word_s       <= (others => '0');
      bit_cnt_s       <= to_unsigned(6, 4);
      byte_cnt_s      <= (others => '0');
      scl_i_ss        <= '0';
      dev_addr_sent_s <= '0';
      reg_addr_sent_s <= '0';
      data_done_s     <= '0';
      ack_done_s      <= '0';
      ack_err_s       <= '0';
      stop_done_s     <= '0';
    elsif rising_edge(clk_i) then
    
      scl_i_ss  <= scl_i_s;
      ack_err_s <= '0';
      i2c_wr_s  <= '0';
    
      if i2c_en_s = '1' then
        scl_s <= not scl_s;
        if i2c_state_s = IDLE_ST or i2c_state_s = START_ST then
          scl_s <= scl_s;
        end if;
      end if;
      
      if reg_ctrl_s(31) = '0' then
        reg_ctrl_go_s <= '0';
      elsif i2c_en_s = '1' then
        reg_ctrl_go_s <= '1';
      end if;
        
      case i2c_state_s is
        when IDLE_ST => 
          ack_done_s <= '0';
          dev_addr_sent_s <= '0';
          reg_addr_sent_s <= '0';
          data_done_s     <= '0';
          i2c_go_s <= '0';
          stop_done_s <= '0';
          scl_s <= '1';
          sda_s <= '1';
          byte_cnt_s(5 downto 0) <= (others => '0'); 
          if reg_ctrl_s(31) = '1' and reg_ctrl_go_s = '0' and i2c_en_s = '1' then
            i2c_go_s <= '1';
            i2c_state_s <= START_ST;
          end if;
          
        when START_ST =>
          if i2c_en_s = '1' then
            if scl_i_s = '1' and sda_s = '1' then
              sda_s <= '0';
              if reg_ctrl_s(4) = '1' and dev_addr_sent_s = '0' and reg_addr_sent_s = '1' then
                dev_addr_sent_s <= '1';
              end if;
            elsif scl_i_s = '1' and sda_s = '0' then
              scl_s <= '0';
            elsif scl_i_s = '0' and sda_s = '1' then
              scl_s <= '1';
            end if;
          end if;
          
          -- falling edge of the scl input
          if scl_i_s = '0' and scl_i_ss = '1' and sda_i_s = '0' then
            bit_cnt_s   <= to_unsigned(6, 4);
            i2c_state_s <= TX_ST;
            sda_s <= reg_ctrl_s(11);
            tx_word_s(31 downto 24) <= reg_ctrl_s(10 downto 5) & "00"; -- set the RWN bit to '0'
            -- start the RX after the register was written to the I2C slave
            if reg_addr_sent_s = '1' then
              tx_word_s(25) <= reg_ctrl_s(4);
            end if;
          end if;
          
        when TX_ST =>
          
          if scl_i_s = '0' and scl_i_ss = '1' then
            sda_s     <= tx_word_s(31);
            tx_word_s <= tx_word_s(30 downto 0) & '0';
            bit_cnt_s <= bit_cnt_s - 1;
            
            if bit_cnt_s(bit_cnt_s'left) = '1' then
              i2c_state_s <= SACK_ST;
              ack_done_s  <= '0';
              sda_s       <= '1';
              tx_word_s   <= tx_word_s;
            end if;
          end if;
               
        when RX_ST =>
          if scl_i_s = '1' and scl_i_ss = '0' then
            rx_byte_s <= rx_byte_s(6 downto 0) & sda_i_s;
            if bit_cnt_s(bit_cnt_s'left) = '0' then
              bit_cnt_s <= bit_cnt_s - 1;
            end if;
          elsif scl_i_s = '0' and scl_i_ss = '1' then
            if bit_cnt_s(bit_cnt_s'left) = '1' then
              i2c_state_s <= MACK_ST;
              -- do not ack the last byte
              if byte_cnt_s = unsigned(reg_ctrl_s(29 downto 24)) then
                sda_s <= '1';
              else
                sda_s <= '0';
              end if;
              case byte_cnt_s(1 downto 0) is
                when "01"   => rx_word_s(15 downto  8) <= rx_byte_s;
                when "10"   => rx_word_s(23 downto 16) <= rx_byte_s;
                when "11"   => rx_word_s(31 downto 24) <= rx_byte_s;
                when others => rx_word_s( 7 downto  0) <= rx_byte_s;
              end case;
              i2c_wr_s <= '1';
            end if;
          end if;

        when SACK_ST =>
          if scl_i_s = '1' and scl_i_ss = '0' and sda_i_s = '0' then 
            ack_done_s <= '1';
          elsif scl_i_s = '1' and scl_i_ss = '0' and sda_i_s = '1' then
            ack_err_s <= '1';
            i2c_state_s <= STOP_ST;
          elsif scl_i_s = '0' and scl_i_ss = '1' and ack_done_s = '1' then
            ack_done_s <= '0';
            -- send register address
            if reg_addr_sent_s = '0' then -- start
              reg_addr_sent_s <= '1';
              i2c_state_s <= TX_ST;
              sda_s <= reg_ctrl_s(23);
              tx_word_s(31 downto 24) <= reg_ctrl_s(22 downto 16) & '0';
              bit_cnt_s   <= to_unsigned(6, 4);
            -- send data
            elsif reg_ctrl_s(4) = '0' then
              i2c_state_s <= TX_ST;
              if byte_cnt_s(1 downto 0) = 0 then
                sda_s <= ram_i2c_data_o_s(31);
                tx_word_s <= ram_i2c_data_o_s(30 downto 0) & '0';
              else
                sda_s <= tx_word_s(31);
                tx_word_s <= tx_word_s(30 downto 0) & '0';
              end if;
              bit_cnt_s   <= to_unsigned(6, 4);
              if byte_cnt_s = unsigned(reg_ctrl_s(29 downto 24)) then
                if data_done_s = '0' then
                  data_done_s <= '1';
                else
                  i2c_state_s <= STOP_ST;
                  sda_s       <= '0';
                end if;
              else
                byte_cnt_s <= byte_cnt_s + 1;
              end if;
            -- receive data
            else
              -- for read procedures, after the register address was written,
              -- the device ID has to be written again to start the read.
              if dev_addr_sent_s = '0' then
                i2c_state_s <= START_ST;
              else
                i2c_state_s <= RX_ST;
                bit_cnt_s   <= to_unsigned(7, 4);
              end if;
              
            end if;
          end if;
        
        when MACK_ST =>
          if scl_i_s = '0' and scl_i_ss = '1' then
            
            if byte_cnt_s = unsigned(reg_ctrl_s(29 downto 24)) then
              i2c_state_s <= STOP_ST;
              sda_s <= '0';
            else
              byte_cnt_s <= byte_cnt_s + 1;
              i2c_state_s <= RX_ST;
              bit_cnt_s   <= to_unsigned(7, 4);
              sda_s <= '1';
            end if;
          end if;
        
        when STOP_ST => 
          
          if scl_i_s = '1' and scl_i_ss = '0' then
            stop_done_s <= '1';
          end if;
          if i2c_en_s = '1' and stop_done_s = '1' then
            sda_s <= '1';
            i2c_state_s <= IDLE_ST;
          end if;
          
          if stop_done_s = '1' then
            scl_s <= '1';
          end if;
      
      end case;
      
      if reg_ctrl_s(31) = '0' then
        i2c_state_s <= IDLE_ST;
      end if;
    end if;
  end process i2c_sm_p; 
  
  sda_gen : for i in sda_io'range generate
    sda_io(i) <= '0' when sda_o_s = '0' and reg_enable_s(i) = '1' else 'Z';
    scl_io(i) <= '0' when scl_s   = '0' and reg_enable_s(i) = '1' else 'Z';
  end generate;
  
  hold_cnt_p : process(clk_i, rst_s)
  begin
    if rst_s = '1' then
      hold_cnt_s    <= (others => '1');
      hold_cnt_s(0) <= '0';
      sda_ss        <= '0';
      sda_o_s       <= '1';
    elsif rising_edge(clk_i) then
      sda_ss <= sda_s;
      
      if sda_ss /= sda_s then
        hold_cnt_s <= (others => '1');
        hold_cnt_s(hold_cnt_s'left) <= '0';
      end if;
      
      if hold_cnt_s(hold_cnt_s'left) = '0' then
        hold_cnt_s <= hold_cnt_s - 1;
      elsif hold_cnt_s(0) = '1' then
        hold_cnt_s(0) <= '0';
        -- delay the sda signal for longer T_hold
        sda_o_s <= sda_s;
      end if;
          
    end if;
  end process hold_cnt_p;
  
--------------------------------------------------------------------------------
-- I2C memory
--------------------------------------------------------------------------------
  memory_inst : i2c_multi_bus_controller_memory 
    GENERIC MAP (
        DATA_WIDTH_G => 32,
        ADDR_WIDTH_G => 4
    )
    PORT MAP (
      byteen       => ram_byteena_s,
      data         => ram_data_i_s,
      address      => ram_addr_s,
      clock        => clk_i,
      wren         => ram_wr_s,
      q            => ram_data_o_s
    );


  ram_addr_s <= std_logic_vector(byte_cnt_s(5 downto 2)) when reg_ctrl_go_s = '1' 
        else avalon_mms_address_i(3 downto 0);
  
  ram_wr_s <= i2c_wr_s when reg_ctrl_go_s = '1' else avalon_mms_write_i when avalon_mms_address_i(5 downto 4) /= "00" else '0';
  
  avalon_mms_readdata_o <= ram_data_o_s when avalon_mms_address_i(5 downto 4) /= "00"
                           else avalon_mms_readdata_s;
                    
  ram_data_i_s <= rx_word_s when reg_ctrl_go_s = '1' else avalon_mms_writedata_i;

  ram_byteena_s <= "1111" when reg_ctrl_go_s = '1' else avalon_mms_byteenable_i;

  ram_i2c_data_o_s( 7 downto  0) <= ram_data_o_s(31 downto 24);
  ram_i2c_data_o_s(15 downto  8) <= ram_data_o_s(23 downto 16);
  ram_i2c_data_o_s(23 downto 16) <= ram_data_o_s(15 downto  8);
  ram_i2c_data_o_s(31 downto 24) <= ram_data_o_s( 7 downto  0);
     
--------------------------------------------------------------------------------
-- BUS READ WRITE
--------------------------------------------------------------------------------

  register_write_access : process(clk_i, rst_s)
  begin
    if (rst_s = '1') then
      reg_ctrl_s <= (others => '0');
      reg_status_s <= (others => '0');      
      i2c_go_ss  <= '0';
      reg_enable_s <= (0 => '1', others => '0');
    elsif rising_edge(clk_i) then
      i2c_go_ss <= i2c_go_s;
      -- Avalon bus write access to the registers
      if (avalon_mms_write_i = '1') then            
        case to_integer(unsigned(avalon_mms_address_i)) is
          when 0 =>
            for i in 0 to 3 loop
              if (avalon_mms_byteenable_i(i) = '1') then
                reg_ctrl_s((i+1)*8 -1 downto i*8) <= avalon_mms_writedata_i((i+1)*8 -1 downto i*8);
              end if;
            end loop;          
          when 1 =>
            for i in 0 to 3 loop
              if (avalon_mms_byteenable_i(i) = '1') then
                reg_status_s((i+1)*8 -1 downto i*8) <= avalon_mms_writedata_i((i+1)*8 -1 downto i*8);
              end if;
            end loop;          
          when 2 =>
            for i in 0 to 3 loop
              if (avalon_mms_byteenable_i(i) = '1') then
                reg_enable_s((i+1)*8 -1 downto i*8) <= avalon_mms_writedata_i((i+1)*8 -1 downto i*8);
              end if;
            end loop;
            if NUM_BUSSES_G=1 then
              reg_enable_s <= (0 => '1', others => '0'); -- if only 1 bus then reg_enable_s is static
            end if;
          when others =>      
            
        end case;
      end if;
      
      if reg_ctrl_s(0) = '1' then
        reg_ctrl_s(0) <= '0';
      end if;
      
      if i2c_go_s = '0' and i2c_go_ss = '1' then
        reg_ctrl_s(31) <= '0';
        reg_status_s(0)  <= '1'; -- interrupt
      end if;
      
      if ack_err_s = '1' then
        reg_status_s(1) <= '1';
      end if;
      
      -- set unused bits to '0'
      reg_ctrl_s(30)                       <= '0';
      reg_ctrl_s(15 downto 13)             <= (others => '0');
      reg_enable_s(31 downto NUM_BUSSES_G) <= (others => '0');
      reg_status_s(31 downto 2)            <= (others => '0');
    end if;
  end process;


  register_read_access : process(clk_i, rst_s)
  begin
    if (rst_s = '1') then
      avalon_mms_readdata_s <= (others => '0');
    elsif rising_edge(clk_i) then
    
      -- Avalon bus read  access to the registers
      if (avalon_mms_read_i = '1') then            
        case to_integer(unsigned(avalon_mms_address_i)) is
          when 0 =>
            avalon_mms_readdata_s <= reg_ctrl_s;
          when 1 =>
            avalon_mms_readdata_s <= reg_status_s;
          when 2 =>
            avalon_mms_readdata_s <= reg_enable_s;
          when others =>
            avalon_mms_readdata_s <= X"DEADBEEF";
        end case;
      end if;
    end if;
  end process;  
  
  
end architecture rtl;
