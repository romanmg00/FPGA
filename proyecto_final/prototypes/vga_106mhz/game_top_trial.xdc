## Reloj de la tarjeta para game_top_trial, que no tiene un Wizard que lo defina.
## Los pines siguen en ../../game_top.xdc.
create_clock -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk]
## Solo define el reloj de la tarjeta. clk_juego sigue sin reloj definido: en la sintesis
## de prueba quedan 18 registros en no_clock. Es un experimento, sin cierre de timing.
