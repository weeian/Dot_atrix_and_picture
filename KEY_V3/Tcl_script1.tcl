#���ڲ�ʹ�õĹܽŴ���--������̬
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
#��ɾ�����йܽŷ���
remove_all_instance_assignments -name *


#gloabl clk and reset
set_location_assignment PIN_16 -to clkin
set_location_assignment PIN_17 -to resetin 

#set_location_assignment PIN_1 -to kbdata
#set_location_assignment PIN_2 -to kbclk

#set_location_assignment PIN_16 -to hsync
#set_location_assignment PIN_15 -to vsync


#set_location_assignment PIN_19 -to r
#set_location_assignment PIN_18 -to g
#set_location_assignment PIN_17 -to b

set_location_assignment PIN_94 -to lcd_data[0]
set_location_assignment PIN_85 -to lcd_data[1]
set_location_assignment PIN_83 -to lcd_data[2]
set_location_assignment PIN_79 -to lcd_data[3]
set_location_assignment PIN_77 -to lcd_data[4]
set_location_assignment PIN_75 -to lcd_data[5]
set_location_assignment PIN_73 -to lcd_data[6]
set_location_assignment PIN_72 -to lcd_data[7]

set_location_assignment PIN_97 -to lcd_e
set_location_assignment PIN_99 -to lcd_rw
set_location_assignment PIN_100 -to lcd_rs





