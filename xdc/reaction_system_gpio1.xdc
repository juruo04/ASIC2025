## reaction_system_top GPIO1 pin constraints (BANK33 plan)
## NOTE: verify board revision/silk-screen. V1.0 may have swapped key labels.

## Clock and buttons
set_property PACKAGE_PIN M19 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name clk_50m [get_ports clk]

## Board decision: KEY1=react, KEY2=start
set_property PACKAGE_PIN K21 [get_ports btn_start_raw]
set_property IOSTANDARD LVCMOS33 [get_ports btn_start_raw]

set_property PACKAGE_PIN J20 [get_ports btn_react_raw]
set_property IOSTANDARD LVCMOS33 [get_ports btn_react_raw]

## External reset key on GPIO1 (active-low): press -> 0, release -> 1.
## Wiring suggestion: Y19 to key, key short to GND when pressed.
set_property PACKAGE_PIN Y19 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PULLUP true [get_ports rst_n]

## 7-segment segment lines (polarity is controlled in RTL by SEG_ON_LEVEL/DIG_ON_LEVEL)
## Sequential wiring rule used here:
## GPIO list (T22,V22,Y20,AA22,AA21,AB20,AB19,AB21,AB22,W21,W22,U22)
## maps to LED pins (1..12, counter-clockwise) one-by-one.
## GK3461AS function pins: 1=E 2=D 3=DP 4=C 5=G 6=DIG4 7=B 8=DIG3 9=DIG2 10=F 11=A 12=DIG1
## User-confirmed segment mapping (2026-06-27): A=11 B=7 C=4 D=2 E=1 F=10 G=5 DP=3.
## With one-by-one wiring, this becomes:
## seg_e->T22 seg_d->V22 seg_dp->Y20 seg_c->AA22 seg_g->AA21
## dig4->AB20 seg_b->AB19 dig3->AB21 dig2->AB22 seg_f->Y21 seg_a->W22 dig1->U22

set_property PACKAGE_PIN T22 [get_ports seg_e]
set_property IOSTANDARD LVCMOS33 [get_ports seg_e]

set_property PACKAGE_PIN V22 [get_ports seg_d]
set_property IOSTANDARD LVCMOS33 [get_ports seg_d]

set_property PACKAGE_PIN Y20 [get_ports seg_dp]
set_property IOSTANDARD LVCMOS33 [get_ports seg_dp]

# set_property PACKAGE_PIN AA22 [get_ports seg_c]
# set_property IOSTANDARD LVCMOS33 [get_ports seg_c]

set_property PACKAGE_PIN AA13 [get_ports seg_c]
set_property IOSTANDARD LVCMOS33 [get_ports seg_c]

set_property PACKAGE_PIN AA21 [get_ports seg_g]
set_property IOSTANDARD LVCMOS33 [get_ports seg_g]

set_property PACKAGE_PIN AB19 [get_ports seg_b]
set_property IOSTANDARD LVCMOS33 [get_ports seg_b]

set_property PACKAGE_PIN Y21 [get_ports seg_f]
set_property IOSTANDARD LVCMOS33 [get_ports seg_f]

set_property PACKAGE_PIN W22 [get_ports seg_a]
set_property IOSTANDARD LVCMOS33 [get_ports seg_a]

## 7-segment digit selects
set_property PACKAGE_PIN U22 [get_ports dig1]
set_property IOSTANDARD LVCMOS33 [get_ports dig1]

set_property PACKAGE_PIN Y13 [get_ports dig2]
set_property IOSTANDARD LVCMOS33 [get_ports dig2]

set_property PACKAGE_PIN AB14 [get_ports dig3]
set_property IOSTANDARD LVCMOS33 [get_ports dig3]

# set_property PACKAGE_PIN AB22 [get_ports dig2]
# set_property IOSTANDARD LVCMOS33 [get_ports dig2]

# set_property PACKAGE_PIN AB21 [get_ports dig3]
# set_property IOSTANDARD LVCMOS33 [get_ports dig3]

set_property PACKAGE_PIN AB20 [get_ports dig4]
set_property IOSTANDARD LVCMOS33 [get_ports dig4]

## Passive buzzer control through transistor module.
## Board behavior indicates active-low drive: idle/off level is high, buzz level is low/PWM.
# set_property PACKAGE_PIN W13 [get_ports buzzer]
# set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
set_property PACKAGE_PIN V15 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
