# 
# WRITE CDC Waivers
# cmd: write_waivers -force /builds/tron-qualified-20261029-233200-2009520/crossing-waivers.xdc
current_instance -quiet
create_waiver -type CDC -id {CDC-1} -user "alan" -desc "Qualified req/ack: rsp_code held until the next command and used only when the synchronized ack matches cmd_seq[0] (game_core resolve); protocol evidence crossing/handshake_tb.sv" -from [get_pins -of_objects [get_cells -hier -regexp {.*u_fast/rsp_code_p[12]_reg\[[0-9]\]}] -filter {REF_PIN_NAME == C}] -to [get_pins -of_objects [get_cells -hier -regexp {.*u_game/(phase_reg\[[0-9]\]|u_score/result_reg\[[0-9]\])}] -filter {REF_PIN_NAME == D}] -timestamp "Thu Oct 29 20:35:22 GMT 2026" ;#1
# 
current_instance -quiet
