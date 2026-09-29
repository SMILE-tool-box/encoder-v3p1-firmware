# External 50 MHz on TRG_IN[0]: logical DIP bit 6 = 1 (pin low).
set_case_analysis 1 [get_nets {dip_sw_data[6]}]
create_clock -period 20.000 -name ExtClk -waveform {0.000 10.000} [get_ports {TRG_IN[0]}]
