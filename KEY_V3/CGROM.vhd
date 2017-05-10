--实现功能：
--矩阵键盘控制模块
--LCD显示
--点阵图片显示
--表现形式：通过按键切换图片和LCD的文字，每张图片对应一段英文


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity CGROM is
	port
	(
	   --按键定义部分
		clkin,resetin:in std_logic;--时钟，复位信号输入
		row_key:out std_logic_vector(1 downto 0);--行数据
		line_key:in std_logic_vector(1 downto 0);--列数据
		--矩阵部分
		line:out std_logic_vector(7 downto 0);--点阵列
		row:out std_logic_vector(7 downto 0);--点阵行
		--LCD显示部分
		lcd_data:inout std_logic_vector(7 downto 0);--lcd数据总线
		lcd_e,lcd_rw,lcd_rs:out std_logic--lcd控制信号
		--
	);
end CGROM;

architecture behave of CGROM is
	component gen_div is--分频元件调用声明
	generic(div_param:integer:=2);--默认是4分频
	port
	(
		clk:in std_logic;
		bclk:out std_logic;
		resetb:in std_logic
	);
	end component;
	
	
----
--此处定义按键状态
type key_state is (check_down,off_twitter,re_check_down,check_line_by_line,get_key_value);--按键状态
signal key_matris_state:key_state:=check_down;--定义一个按键检查状态
signal clk_1k:std_logic;--1k时钟，T=1ms  这个信号作为三个模块共用的信号


--type state定义的数据段：
---        设置功能函数，设置显示开关，设置模式，清屏，设置第一行地址，设置第二行地址，显示第一行字符，显示第二行字符
type state is (set_Func,set_DispSwitch,set_EntryMd,clr_Disp,set_DDAd1,set_DDAd2,Display1,Display2,over);
type data_array is array(0 to 13) of std_logic_vector(7 downto 0);

---LCD字库
constant data1:data_array:=(X"20",X"45",X"78",X"70",
							X"65",X"63",X"74",X"69",
							X"6E",X"67",X"20",X"61",
							X"20",X"20");--"Expecting a "
constant data2:data_array:=(X"20",X"20",X"57",X"6F",
							X"6D",X"61",X"6E",X"20",
							X"20",X"20",X"20",X"20",
							X"20",X"20");--"Woman"
constant data3:data_array:=(X"20",X"57",X"75",X"74",X"68",
							X"65",X"72",X"69",X"6E",
							X"67",X"20",X"20",X"20",
							X"20");--"Wuthering"
constant data4:data_array:=(X"20",X"20",X"48",X"65",X"69",
							X"67",X"68",X"74",X"73",
							X"20",X"20",X"20",X"20",
							X"20");--"Heights"
constant data5:data_array:=(X"45",X"76",X"65",X"72",
							X"79",X"6F",X"6E",X"65",
							X"20",X"69",X"73",X"20",
							X"6D",X"65");--"Everyone is me!"
constant data6:data_array:=(X"20",X"20",X"20",X"20",
							X"20",X"20",X"20",X"20",
							X"20",X"20",X"20",X"20",
							X"20",X"20");--"空白"
							
signal lcd_state:state:=clr_Disp;--初始为"清屏"状态

-----
type data_88 is array(0 to 7) of std_logic_vector(7 downto 0);--8*8矩阵
----图片点阵库
constant led_data1:data_88:=(X"F7",X"C1",X"C1",X"80",X"80",X"C1",X"C1",X"C1");--"塔"
constant led_data2:data_88:=(X"FF",X"FF",X"C1",X"80",X"C1",X"C1",X"C1",X"FF");--"house"
constant led_data3:data_88:=(X"E3",X"E3",X"E3",X"F7",X"80",X"EB",X"EB",X"EB");--"人"

signal clk_cnt:std_logic;--800Hz
signal cnt:std_logic_vector(2 downto 0);--对clk_cnt计数，产生8个状态


signal row_tmp:std_logic_vector(1 downto 0);
----   
begin
---
row_key<=row_tmp;--行键
----
gen_1k: --分频产生1k脉冲
		gen_div generic map(240)--480分频的,产生100k脉冲
		port map--分频元件例化
		(
			clk=>clkin,
			resetb=>not resetin,
			bclk=>clk_1k
		);
	
	
---
gen_cnt_1k:--cnt循环计数,产生八个状态
	process(clk_1k,resetin)
	begin
	if resetin='0' then
		cnt<="000";
	else
		if rising_edge(clk_1k) then
			cnt<=cnt+'1';
		end if;
	end if;
	end process;
---
---
---
---主程序开始--------

check_key_matrix:
	process(clk_1k,resetin,row_tmp,line_key,cnt)
	
------------------------定义需要的变量--------------------------
	variable cnt_key:integer range 0 to 127:=0;
	variable state:integer range 0 to 4  :=0;--记录按键键值
	--LCD显示部分
	variable delay_cnt:integer range 0 to 255:=0;--延时计数器
	variable char_cnt:integer range 0 to 15:=0;--字符计数器
	
	
	
------------------------主程序逻辑部分-----------------------
	begin
	 if resetin='0' then--复位
	   key_matris_state<=check_down;
		row_tmp<="11";
		lcd_state<=clr_Disp;
		delay_cnt:=0;
		char_cnt:=0;
		lcd_e<='0';
	else
		if rising_edge(clk_1k) then
-- ----------------------------------------------
 
				case key_matris_state is
					when check_down=>
						cnt_key:=cnt_key+1;
						case cnt_key is
							when 1=> row_tmp<="00";
							when 2=>
								if line_key /="11" then--有零值，有键按下
									key_matris_state<=off_twitter;--准备去抖动
									cnt_key:=0;
								else
									key_matris_state<=check_down;
									cnt_key:=0;
								end if;
							when others=> null;
						end case;
					when off_twitter=>--延时10ms,消抖
						cnt_key:=cnt_key+1;
						if cnt_key>=10 then
							key_matris_state<=re_check_down;--再判断
							cnt_key:=0;
						end if;
					when re_check_down=>--消抖后再次判断
						cnt_key:=cnt_key+1;
						case cnt_key is
							when 1=> row_tmp<="00";
							when 2=>
								if line_key /="11" then--有零值，有键按下
									key_matris_state<=check_line_by_line;--准备逐行扫描
									cnt_key:=0;
								else
									key_matris_state<=check_down;--无键按下，重新开始判断
									cnt_key:=0;
								end if;
							when others=> null;
						end case;
					when check_line_by_line=>--逐行扫描
						cnt_key:=cnt_key+1;
						case cnt_key is
							when 1=>
								row_tmp<="10";--置其中一行为0
							when 2=>
								if line_key /="11" then
									key_matris_state<=get_key_value;
									cnt_key:=0;
								end if;
							when 3=>
								row_tmp<="01";--置其中一行为0
							when 4 =>
								if line_key /="11" then
									key_matris_state<=get_key_value;
									cnt_key:=0;
								end if;
							when others=>null;
						end case;
						
					when get_key_value=>
						case row_tmp is
							when "10"=>          
								case line_key is
									when "10" =>
										state :=1;
									when "01" =>
										state :=2;
									when others=>null;
								end case;
							when "01" =>
								case line_key is
									when "10" =>
										state :=3;
									when "01" =>
										state :=4;
									when others=>null;
								end case;
							 when others=>null;
							end case;
								key_matris_state<=check_down;
					when others=>key_matris_state<=check_down;
				end case;
			
--------------------------------------key1部分---------------------
							
							  if state=1 then   --Tower
							          case cnt is
									    when "000"=> row<="11111110";line<=led_data1(0);--从上往下扫描
		                         when "001"=> row<="11111101";line<=led_data1(1);
	                       	    when "010"=> row<="11111011";line<=led_data1(2);
		                         when "011"=> row<="11110111";line<=led_data1(3);
		                         when "100"=> row<="11101111";line<=led_data1(4);
		                         when "101"=> row<="11011111";line<=led_data1(5);
		                         when "110"=> row<="10111111";line<=led_data1(6);
		                         when "111"=> row<="01111111";line<=led_data1(7);
									    when others=> null;
	                          end case;			
					           
								  ------LCD逻辑部分--------显示：Expecting a Woman
									
				                    case lcd_state is
			                     	 
										  when clr_Disp=>--刚开始时就需要清屏幕
					                     delay_cnt:=delay_cnt+1;
				            	         if delay_cnt<=2 then
						                   lcd_rs<='0';
						                   lcd_rw<='0';
						                   lcd_e<='1';
					                     elsif delay_cnt<=4 then
						                   lcd_data<=X"01";
					                     elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                     elsif delay_cnt>=200 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_Func;
					                     end if;
				                    when set_Func=>--功能设置
				                     	delay_cnt:=delay_cnt+1;
					                    if delay_cnt<=2 then
					                  	lcd_rs<='0';--指令
						                  lcd_rw<='0';--写
						                  lcd_e<='1';
					                    elsif delay_cnt<=4 then
						                   lcd_data<=X"38";--DL=1,8位，N=1,2行,F=0,5*7字体
					                    elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                    elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_EntryMd;
					                      end if;
				                   when set_EntryMd=>--设置输入模式
					                  delay_cnt:=delay_cnt+1;
					                  if delay_cnt<=2 then
						                  lcd_rs<='0';
						                  lcd_rw<='0';
						                  lcd_e<='1';
					                  elsif delay_cnt<=4 then
						                  lcd_data<=X"06";--I/D=1,自增，S=0,显示不移动
					                  elsif delay_cnt<=6 then
						                  lcd_e<='0';--下降沿产生
					                  elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                  delay_cnt:=0;
						                  lcd_state<=set_DispSwitch;
					                  end if;
				                 when set_DispSwitch=>--设置显示开关
					                   delay_cnt:=delay_cnt+1;
					                  if delay_cnt<=2 then
						                   lcd_rs<='0';
						                   lcd_rw<='0';
						                   lcd_e<='1';
					                  elsif delay_cnt<=4 then
						                   lcd_data<=X"0C";--D=1,显示开，C=0光标关闭,B=0,光标所在字符不闪烁
					                  elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                  elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_DDAd1;
					                  end if;
				                when set_DDAd1=>--设置成DDRAM第一行的地址首地址为0x81
					                  delay_cnt:=delay_cnt+1;
					                 if delay_cnt<=2 then
						                 lcd_rs<='0';
						                 lcd_rw<='0';
						                 lcd_e<='1';
					                 elsif delay_cnt<=4 then
						                 lcd_data<=X"81";
					                 elsif delay_cnt<=6 then
						                 lcd_e<='0';--下降沿产生
					                 elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                 delay_cnt:=0;
						                 lcd_state<=Display1;
						                 char_cnt:=0;--清字符计数器
					                 end if;
				               when Display1=>--向第一行DDRAM写数据
					                if char_cnt<14 then --显示"Expecting a" 
						                delay_cnt:=delay_cnt+1;
						             if delay_cnt<=2 then
							             lcd_rs<='1';--数据
							             lcd_rw<='0';--写
							             lcd_e<='1';
						             elsif delay_cnt<=4 then
							             lcd_data<=data1(char_cnt);
						             elsif delay_cnt<=6 then
							             lcd_e<='0';--下降沿产生
						             elsif delay_cnt>=100 then--等待>40us时间,使数据写入完毕
							             delay_cnt:=0;
							             lcd_state<=Display1;
							             char_cnt:=char_cnt+1;--字符计数器自增
						             end if;
					              else
						               delay_cnt:=0;
						               lcd_state<=set_DDAd2;
						               char_cnt:=0;
					                end if;	
				            when set_DDAd2=>--设置DDRAM第二行的地址首地址为0xc2
						                delay_cnt:=delay_cnt+1;
						                if delay_cnt<=2 then
							                lcd_rs<='0';
							                lcd_rw<='0';
							                lcd_e<='1';
						               elsif delay_cnt<=4 then
							                lcd_data<=X"C2";
						               elsif delay_cnt<=6 then
							                lcd_e<='0';--下降沿产生
						               elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
							                delay_cnt:=0;
							                lcd_state<=Display2;
							                char_cnt:=0;
						               end if;
				            when Display2=>--向第二行DDRAM写数据
					             if char_cnt<11 then --显示"Woman" 
						             delay_cnt:=delay_cnt+1;
						          if delay_cnt<=2 then
							          lcd_rs<='1';--数据
							          lcd_rw<='0';--写
							          lcd_e<='1';
						          elsif delay_cnt<=4 then
							          lcd_data<=data2(char_cnt);
						          elsif delay_cnt<=6 then
							          lcd_e<='0';--下降沿产生
						          elsif delay_cnt>=100 then--等待>40us时间,使数据写入完毕
							          delay_cnt:=0;
							          lcd_state<=Display2;
							          char_cnt:=char_cnt+1;
						          end if;
					           else
						          delay_cnt:=0;
						          lcd_state<=clr_Disp;
						          char_cnt:=0;
					            end if;
				           when over=>				
					                    null;
			          end case;	
         			

--------------------------key2部分---------------------------------------
							
							   elsif state=2 then --House
							        case cnt is
									   when "000"=> row<="11111110";line<=led_data2(0);--从上往下扫描
		                        when "001"=> row<="11111101";line<=led_data2(1);
	                       	   when "010"=> row<="11111011";line<=led_data2(2);
		                        when "011"=> row<="11110111";line<=led_data2(3);
		                        when "100"=> row<="11101111";line<=led_data2(4);
		                        when "101"=> row<="11011111";line<=led_data2(5);
		                        when "110"=> row<="10111111";line<=led_data2(6);
		                        when "111"=> row<="01111111";line<=led_data2(7);
									   when others=> null;
									end case;
									
							---------LCD逻辑部分---------显示：Wuthering Heights	
																				 
									     case lcd_state is
			                     	 
										  when clr_Disp=>--刚开始时就需要清屏幕
					                     delay_cnt:=delay_cnt+1;
				            	         if delay_cnt<=2 then
						                   lcd_rs<='0';
						                   lcd_rw<='0';
						                   lcd_e<='1';
					                     elsif delay_cnt<=4 then
						                   lcd_data<=X"01";
					                     elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                     elsif delay_cnt>=200 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_Func;
					                     end if;
				                    when set_Func=>--功能设置
				                     	delay_cnt:=delay_cnt+1;
					                    if delay_cnt<=2 then
					                  	lcd_rs<='0';--指令
						                  lcd_rw<='0';--写
						                  lcd_e<='1';
					                    elsif delay_cnt<=4 then
						                   lcd_data<=X"38";--DL=1,8位，N=1,2行,F=0,5*7字体
					                    elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                    elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_EntryMd;
					                      end if;
				                   when set_EntryMd=>--设置输入模式
					                  delay_cnt:=delay_cnt+1;
					                  if delay_cnt<=2 then
						                  lcd_rs<='0';
						                  lcd_rw<='0';
						                  lcd_e<='1';
					                  elsif delay_cnt<=4 then
						                  lcd_data<=X"06";--I/D=1,自增，S=0,显示不移动
					                  elsif delay_cnt<=6 then
						                  lcd_e<='0';--下降沿产生
					                  elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                  delay_cnt:=0;
						                  lcd_state<=set_DispSwitch;
					                  end if;
				                 when set_DispSwitch=>--设置显示开关
					                   delay_cnt:=delay_cnt+1;
					                  if delay_cnt<=2 then
						                   lcd_rs<='0';
						                   lcd_rw<='0';
						                   lcd_e<='1';
					                  elsif delay_cnt<=4 then
						                   lcd_data<=X"0C";--D=1,显示开，C=0光标关闭,B=0,光标所在字符不闪烁
					                  elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                  elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_DDAd1;
					                  end if;
				                when set_DDAd1=>--设置成DDRAM第一行的地址首地址为0x81
					                  delay_cnt:=delay_cnt+1;
					                 if delay_cnt<=2 then
						                 lcd_rs<='0';
						                 lcd_rw<='0';
						                 lcd_e<='1';
					                 elsif delay_cnt<=4 then
						                 lcd_data<=X"81";
					                 elsif delay_cnt<=6 then
						                 lcd_e<='0';--下降沿产生
					                 elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                 delay_cnt:=0;
						                 lcd_state<=Display1;
						                 char_cnt:=0;--清字符计数器
					                 end if;
				               when Display1=>--向第一行DDRAM写数据
					                if char_cnt<14 then --显示"Wuthering " 
						                delay_cnt:=delay_cnt+1;
						             if delay_cnt<=2 then
							             lcd_rs<='1';--数据
							             lcd_rw<='0';--写
							             lcd_e<='1';
						             elsif delay_cnt<=4 then
							             lcd_data<=data3(char_cnt);
						             elsif delay_cnt<=6 then
							             lcd_e<='0';--下降沿产生
						             elsif delay_cnt>=100 then--等待>40us时间,使数据写入完毕
							             delay_cnt:=0;
							             lcd_state<=Display1;
							             char_cnt:=char_cnt+1;--字符计数器自增
						             end if;
					              else
						               delay_cnt:=0;
						               lcd_state<=set_DDAd2;
						               char_cnt:=0;
					                end if;	
				            when set_DDAd2=>--设置DDRAM第二行的地址首地址为0xc2
						                delay_cnt:=delay_cnt+1;
						                if delay_cnt<=2 then
							                lcd_rs<='0';
							                lcd_rw<='0';
							                lcd_e<='1';
						               elsif delay_cnt<=4 then
							                lcd_data<=X"C2";
						               elsif delay_cnt<=6 then
							                lcd_e<='0';--下降沿产生
						               elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
							                delay_cnt:=0;
							                lcd_state<=Display2;
							                char_cnt:=0;
						               end if;
				            when Display2=>--向第二行DDRAM写数据
					             if char_cnt<11 then --显示"Heights " 
						             delay_cnt:=delay_cnt+1;
						          if delay_cnt<=2 then
							          lcd_rs<='1';--数据
							          lcd_rw<='0';--写
							          lcd_e<='1';
						          elsif delay_cnt<=4 then
							          lcd_data<=data4(char_cnt);
						          elsif delay_cnt<=6 then
							          lcd_e<='0';--下降沿产生
						          elsif delay_cnt>=100 then--等待>40us时间,使数据写入完毕
							          delay_cnt:=0;
							          lcd_state<=Display2;
							          char_cnt:=char_cnt+1;
						          end if;
					           else
						          delay_cnt:=0;
						          lcd_state<=clr_Disp;
						          char_cnt:=0;
					            end if;
				           when over=>				
					                    null;
			          end case;	
				
----------------------------key3部分--------------------------------
		 
							elsif state=3 then  --Single
							   
							     case cnt is
									   when "000"=> row<="11111110";line<=led_data3(0);--从上往下扫描
		                        when "001"=> row<="11111101";line<=led_data3(1);
	                       	   when "010"=> row<="11111011";line<=led_data3(2);
		                        when "011"=> row<="11110111";line<=led_data3(3);
		                        when "100"=> row<="11101111";line<=led_data3(4);
		                        when "101"=> row<="11011111";line<=led_data3(5);
		                        when "110"=> row<="10111111";line<=led_data3(6);
		                        when "111"=> row<="01111111";line<=led_data3(7);
									   when others=> null;
									end case;
									
						-------LCD逻辑部分---------显示：Everyone is me
									
						          case lcd_state is
			                     	 
										  when clr_Disp=>--刚开始时就需要清屏幕
					                     delay_cnt:=delay_cnt+1;
				            	         if delay_cnt<=2 then
						                   lcd_rs<='0';
						                   lcd_rw<='0';
						                   lcd_e<='1';
					                     elsif delay_cnt<=4 then
						                   lcd_data<=X"01";
					                     elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                     elsif delay_cnt>=200 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_Func;
					                     end if;
				                    when set_Func=>--功能设置
				                     	delay_cnt:=delay_cnt+1;
					                    if delay_cnt<=2 then
					                  	lcd_rs<='0';--指令
						                  lcd_rw<='0';--写
						                  lcd_e<='1';
					                    elsif delay_cnt<=4 then
						                   lcd_data<=X"38";--DL=1,8位，N=1,2行,F=0,5*7字体
					                    elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                    elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_EntryMd;
					                      end if;
				                   when set_EntryMd=>--设置输入模式
					                  delay_cnt:=delay_cnt+1;
					                  if delay_cnt<=2 then
						                  lcd_rs<='0';
						                  lcd_rw<='0';
						                  lcd_e<='1';
					                  elsif delay_cnt<=4 then
						                  lcd_data<=X"06";--I/D=1,自增，S=0,显示不移动
					                  elsif delay_cnt<=6 then
						                  lcd_e<='0';--下降沿产生
					                  elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                  delay_cnt:=0;
						                  lcd_state<=set_DispSwitch;
					                  end if;
				                 when set_DispSwitch=>--设置显示开关
					                   delay_cnt:=delay_cnt+1;
					                  if delay_cnt<=2 then
						                   lcd_rs<='0';
						                   lcd_rw<='0';
						                   lcd_e<='1';
					                  elsif delay_cnt<=4 then
						                   lcd_data<=X"0C";--D=1,显示开，C=0光标关闭,B=0,光标所在字符不闪烁
					                  elsif delay_cnt<=6 then
						                   lcd_e<='0';--下降沿产生
					                  elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                   delay_cnt:=0;
						                   lcd_state<=set_DDAd1;
					                  end if;
				                when set_DDAd1=>--设置成DDRAM第一行的地址首地址为0x81
					                  delay_cnt:=delay_cnt+1;
					                 if delay_cnt<=2 then
						                 lcd_rs<='0';
						                 lcd_rw<='0';
						                 lcd_e<='1';
					                 elsif delay_cnt<=4 then
						                 lcd_data<=X"81";
					                 elsif delay_cnt<=6 then
						                 lcd_e<='0';--下降沿产生
					                 elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
						                 delay_cnt:=0;
						                 lcd_state<=Display1;
						                 char_cnt:=0;--清字符计数器
					                 end if;
				               when Display1=>--向第一行DDRAM写数据
					                if char_cnt<14 then --显示"Everyone is me " 
						                delay_cnt:=delay_cnt+1;
						             if delay_cnt<=2 then
							             lcd_rs<='1';--数据
							             lcd_rw<='0';--写
							             lcd_e<='1';
						             elsif delay_cnt<=4 then
							             lcd_data<=data5(char_cnt);
						             elsif delay_cnt<=6 then
							             lcd_e<='0';--下降沿产生
						             elsif delay_cnt>=100 then--等待>40us时间,使数据写入完毕
							             delay_cnt:=0;
							             lcd_state<=Display1;
							             char_cnt:=char_cnt+1;--字符计数器自增
						             end if;
					              else
						               delay_cnt:=0;
						               lcd_state<=set_DDAd2;
						               char_cnt:=0;
					                end if;	
				            when set_DDAd2=>--设置DDRAM第二行的地址首地址为0xc2
						                delay_cnt:=delay_cnt+1;
						                if delay_cnt<=2 then
							                lcd_rs<='0';
							                lcd_rw<='0';
							                lcd_e<='1';
						               elsif delay_cnt<=4 then
							                lcd_data<=X"C2";
						               elsif delay_cnt<=6 then
							                lcd_e<='0';--下降沿产生
						               elsif delay_cnt>=100 then--等待>40us时间,使指令写入完毕
							                delay_cnt:=0;
							                lcd_state<=Display2;
							                char_cnt:=0;
						               end if;
				            when Display2=>--向第二行DDRAM写数据
					             if char_cnt<11 then --显示"    " 
						             delay_cnt:=delay_cnt+1;
						          if delay_cnt<=2 then
							          lcd_rs<='1';--数据
							          lcd_rw<='0';--写
							          lcd_e<='1';
						          elsif delay_cnt<=4 then
							          lcd_data<=data6(char_cnt);
						          elsif delay_cnt<=6 then
							          lcd_e<='0';--下降沿产生
						          elsif delay_cnt>=100 then--等待>40us时间,使数据写入完毕
							          delay_cnt:=0;
							          lcd_state<=Display2;
							          char_cnt:=char_cnt+1;
						          end if;
					           else
						          delay_cnt:=0;
						          lcd_state<=clr_Disp;
						          char_cnt:=0;
					            end if;
				           when over=>				
					                    null;
			          end case;	
								
------------------------------按键部分结束--------------------------
						
				end if;
			end if;
		end if;
	end process;	
end behave;