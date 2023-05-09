# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {Top-level signals}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave UUT/top_state
add wave -uns UUT/UART_timer

add wave -divider -height 10 {SRAM signals}
add wave -uns UUT/SRAM_address
add wave -hex UUT/SRAM_write_data
add wave -bin UUT/SRAM_we_n
add wave -hex UUT/SRAM_read_data

#add wave -divider -height 10 {VGA signals}
#add wave -bin UUT/VGA_unit/VGA_HSYNC_O
#add wave -bin UUT/VGA_unit/VGA_VSYNC_O
#add wave -uns UUT/VGA_unit/pixel_X_pos
#add wave -uns UUT/VGA_unit/pixel_Y_pos
#add wave -hex UUT/VGA_unit/VGA_red
#add wave -hex UUT/VGA_unit/VGA_green
#add wave -hex UUT/VGA_unit/VGA_blue

add wave -divider -height 10 {Milestone1 signals}
add wave -dec UUT/M2_unit/M2_state
add wave -dec UUT/M2_unit/S_CT
add wave -dec UUT/M2_unit/write_address_0b
add wave -hex UUT/M2_unit/write_data_b
add wave -dec UUT/M2_unit/read_data_a
add wave -dec UUT/M2_unit/read_data_b
add wave -dec UUT/M2_unit/read_address_0a
add wave -dec UUT/M2_unit/read_address_1a
add wave -dec UUT/M2_unit/write_address_1b
add wave -dec UUT/M2_unit/S
add wave -dec UUT/M2_unit/T
add wave -dec UUT/M2_unit/i
add wave -dec UUT/M2_unit/j
add wave -dec UUT/M2_unit/c0
add wave -dec UUT/M2_unit/c1
add wave -dec UUT/M2_unit/s_prime_0
add wave -dec UUT/M2_unit/s_prime_1
add wave -dec UUT/M2_unit/MULTICS0
add wave -dec UUT/M2_unit/MULTICS1