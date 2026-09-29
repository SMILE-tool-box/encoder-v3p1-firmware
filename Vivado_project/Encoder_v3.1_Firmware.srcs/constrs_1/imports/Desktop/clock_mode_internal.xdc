# Internal 50 MHz: logical DIP bit 6 = 0 (pin DIP_SW_IN[6] high).
set_case_analysis 0 [get_nets {dip_sw_data[6]}]
set_false_path -from [get_ports {TRG_IN[0]}] -to [get_pins Osc_MUX/I1]
