
: BUZZER 0D ; \ GPIO 13

\ Provoca un'oscillazione nel buzzer; lo si può rendere variabile, in base alla fase del semaforo
: BUZZER-NOISE ( delay -- )
    DUP \ duplico in modo da usarlo una volta dopo BUZZER ON, e un'altra volta dopo BUZZER OFF
    BUZZER ON
    DELAY
    BUZZER OFF
    DELAY
;

\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \
