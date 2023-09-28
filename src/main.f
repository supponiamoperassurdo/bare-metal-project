
: START ( -- )             \ avvia il semaforo pedonale, rendendolo un vero e proprio semaforo in attesa della chiamata
    BEGIN 
        INIT-TRAFFIC-LIGHT \ inizializza il semaforo pedonale
        PEDESTRIAN-CALL    \ busy while in attesa della pressione del pulsante secondo la definzione della word PEDESTRIAN-CALL
    0 UNTIL
;

INIT-GPIO
INIT-I2C
INIT-LCD



\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \
\ = = = = = = = = = = Giuseppe Scibetta, Embedded Systems 2022/2023 = = = = = = = = = = \
\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \
