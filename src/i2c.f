
PERIBASE 804000 + CONSTANT BSC1             \ Broadcom Serial Controller 1, interfaccia dedicata alla comunicazione I2C; scegliamo il BSC1 perché di interfacce BSC vi sono, per esempio, il BSC2 dedicato all'HDMI
BSC1     0      + CONSTANT CONTROL          \ Control, utilizzato per la gestione di interrupt, pulizia del FIFO, definizione di operazione di R/W e di inizializzazione (settando a 1 il bit 15) di trasferimento
BSC1     4      + CONSTANT STATUS           \ Status, per registrare lo stato delle attività, gli errori e le richieste di interruzione
BSC1     8      + CONSTANT DLEN             \ Data Length, definisce il numero di byte di dati da trasmettere o ricevere nel trasferimento I2C (1 DLEN = 1 byte)
BSC1     C      + CONSTANT SLAVE-ADDRESS    \ Slave Address, specifica l'indirizzo slave e il tipo di ciclo
BSC1     10     + CONSTANT FIFO             \ Lista FIFO contententi i dati e utilizzato per accedere al FIFO
27                CONSTANT PCF8574T-ADDRESS \ dalla documentazione dell'LCD1602, l'indirizzo I2C del suo driver - il PCF8574T - è 0x27 

\ Control register (C)
: SEND         8080 CONTROL @ OR CONTROL ! ; \ bit[7] = 1 abilita un trasferimento, bit[0] = 0 per indicare che il è il master a trasmettere pacchetti allo slave (LCD1602), e il bit[15] = 1 per denotare che il BCS è abilitato
: CLEAR-FIFO   10   CONTROL @ OR CONTROL ! ; \ si settano i bit[5:4] = X1 oppure 1X per pulire la FIFO e consentire la scrittura di nuovi dati

\ Status register (S)
: RESET-STATUS 302 STATUS @ OR STATUS ! ; \ dalla documentazione, si può vedere che settando i bit[9:8, 1] = 1 si "resetta" lo stato dello slave e (con il bit[1] = 1) si considera il trasferimento completato

\ FIFO register (FIFO)
: WRITE-FIFO FIFO ! ;

\ Data length register (DLEN)
: SET-DLEN DLEN ! ;

\ Slave address (A)
: SET-SLAVE-ADDRESS SLAVE-ADDRESS ! ; \ setta l'indirizzo dello slave con quello del chip PCF8574T, il driver I2C dell'LCD1602 

\ Trasmette un byte di dati alla volta al PCF8574T: prima resetta il registro S, pulisce la FIFO dai precedenti dati, setta il numero di byte a 1, scrive nella FIFO il valore presente nello stack e infine, lo manda con SEND
: >I2C ( byte -- )
    RESET-STATUS
    CLEAR-FIFO
    1 SET-DLEN
    WRITE-FIFO
    SEND
;

\ Si abilitato GPIO 2 e GPIO 3 in modalità "alternative function 0" per consentire l'uso dell'I2C:
\ a pagina 102 del datasheet del BCM2837 si può vedere che la AF0 della GPIO 2 e GPIO 3 
\ li rendono pin la trasmissione I2C, rispettivamente SDA1 e SCL1;
\ infine, si setta l'indirizzo dello slave PCF8574T. 
: INIT-I2C ( -- )
    02 FSEL-ALT0 SET-FSEL
    03 FSEL-ALT0 SET-FSEL
    PCF8574T-ADDRESS SET-SLAVE-ADDRESS
;

\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \
