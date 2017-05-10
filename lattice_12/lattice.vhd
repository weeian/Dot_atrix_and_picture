
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity lattice is
	port
	(
		clkin,resetin:in std_logic;--时钟，复位信号输入
		cloumn:out std_logic_vector(7 downto 0);--8列
		row:out std_logic_vector(7 downto 0)--8行
		--
	);
end lattice;

architecture behave of lattice is
	component gen_div is--分频元件调用声明
	generic(div_param:integer:=2);--默认是4分频
	port
	(
		clk:in std_logic;
		bclk:out std_logic;
		reset:in std_logic
	);
	end component;
	
----
type data_88 is array(0 to 7) of std_logic_vector(7 downto 0) ;
constant led_data:data_88:=(X"7F",X"FF",X"DF",X"FF",X"F7",X"FF",X"FD",X"FF");
signal clk_cnt:std_logic;
signal cnt:std_logic_vector(2 downto 0);
----
begin
----
gen_100k: --分频产生100k脉冲
		gen_div generic map(30000)--6000分频的,产生800Hz脉冲
		port map--分频元件例化
		(
			clk=>clkin,
			reset=>resetin,
			bclk=>clk_cnt
		);
---
gen_clk_div:
     process(clk_cnt,resetin)
	  begin
	  if resetin='0' then
	    cnt<="000";
		else
		 if rising_edge(clk_cnt) then
		 cnt<=cnt+'1';
		 end if;
		end if;
	end process;

---	
  display:
  
    process(cnt,resetin)
	 begin
	  case  cnt is
	    when "000"=> cloumn<="00000000";row<=led_data(0);
		 when "001"=> cloumn<="11111111";row<=led_data(1);
		 when "010"=> cloumn<="00000000";row<=led_data(2);
		 when "011"=> cloumn<="11111111";row<=led_data(3);
		 when "100"=> cloumn<="00000000";row<=led_data(4);
		 when "101"=> cloumn<="11111111";row<=led_data(5);
		 when "110"=> cloumn<="00000000";row<=led_data(6);
		 when "111"=> cloumn<="11111111";row<=led_data(7);
		 when others=>null;
		 
	end case;
	  
	end process;
	
end architecture;

