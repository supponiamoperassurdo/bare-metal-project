
VARIABLE LED-COUNTER 0 LED-COUNTER !          \ contatore per il semaforo: rosso (0), giallo (1), verde (2)
VARIABLE ?PUSHED 0 ?PUSHED !                  \ flag che percepisce la pressione pulsante; l'hardware lavora a logica negativa (0 V quando viene pressato)
VARIABLE DELAY-VARIABLE 1000 DELAY-VARIABLE ! \ costante di delay su cui si baseranno gli altri ritardi; si può modificare per alterare i ritardi

: SET-DELAY-VARIABLE DELAY-VARIABLE ! ;

\ Utilizzato per controllare lo stato del semaforo
: CHECK-LED-COUNTER ( -- )
    LED-COUNTER @ 2 =   \ se si è arrivati al terzo LED (luce verde)...
    IF
        0 LED-COUNTER ! \ reset del LED-COUNTER
    ELSE    
        LED-COUNTER @ 1 + LED-COUNTER ! \ post-incremento
    THEN
;

: RED    15 ; \ GPIO 21
: YELLOW 1A ; \ GPIO 26
: GREEN  13 ; \ GPIO 19

\ Sulla base del LED-COUNTER, LED assumerà un diverso valore
: TRAFFIC-LIGHT ( -- led_pin )
    LED-COUNTER @ 0 = \ se il semaforo è al primo passo (cioè al rosso)...
    IF RED    THEN
    LED-COUNTER @ 1 = \ se il semaforo è al secondo passo (cioè il giallo)...
    IF YELLOW THEN
    LED-COUNTER @ 2 = \ se il semaforo è al terzo passo (cioè il verde)...
    IF GREEN  THEN 
;

: SET-BUTTON   1 ?PUSHED ! ; \ word utilizzata per settare lo stato del bottone a "yes"
: RESET-BUTTON 0 ?PUSHED ! ; \ word utilizzata per resettare lo stato del bottone a "no"

: PUSH-BUTTON ( -- )
    BEGIN
        GPLEV0 @ 11 >WORD AND 0 = \ se il 17esimo bit (cioè la GPIO 17, dov'è collegato il pulsante) è pari a 0 (logica negativa, cioè il bottone è stato pressato e passa da 3.3 V a 0 V)
        IF
            SET-BUTTON            \ entra nell'IF e setta "?PUSHED" a true
        THEN                
    ?PUSHED @ 1 = UNTIL           \ se è stato pressato ("1" equivale a "yes") allora esci dal busy while
;

\ Quantità di delay che determina quanto acceso resterà il LED, a seconda del colore:
\ prima si passa il valore di LED-COUNTER e, in base a esso, aumenta o diminuisce il delay.
: DELAY-IN ( -- delay )
    LED-COUNTER @ 0 =
    IF
        DELAY-VARIABLE @ 100 *
    THEN
    LED-COUNTER @ 1 =
    IF
        DELAY-VARIABLE @ 75 *
    THEN
    LED-COUNTER @ 2 =
    IF
        DELAY-VARIABLE @ 110 *
    THEN
;

\ Quantità di delay che determina quanto spento resterà il LED, a seconda del colore.
\ Li ho voluti separare in casistiche differenti per cambiarli eventualmente
\ per come meglio si preferisce.
: DELAY-OUT ( -- delay )
    LED-COUNTER @ 0 =
    IF
        DELAY-VARIABLE @ 25 *
    THEN
    LED-COUNTER @ 1 =
    IF
        DELAY-VARIABLE @ 25 *
    THEN
    LED-COUNTER @ 2 =
    IF
        DELAY-VARIABLE @ 25 *
    THEN
;

: >LCD-PRINT-HELPS ( -- )
    LED-COUNTER @ 0 = \ se il semaforo è rosso...
    IF
        S" FERMO!" >LCD-PRINT
    THEN 
    LED-COUNTER @ 1 = \ se il semaforo è giallo...
    IF
        S" ASPETTA..." >LCD-PRINT
    THEN 
    LED-COUNTER @ 2 = \ se il semaforo è verde...
    IF
        S" PROCEDI :)" >LCD-PRINT
    THEN 
;

: GREEN-LED-WARNING ( -- ) \ il verde inizia a lampeggiare per avvertire i pedoni di accelerare il passo, e allo stesso modo il buzzer diventa più rumoroso
    LED-COUNTER @ 2 =      \ se il semaforo è verde...
    IF
        5 BEGIN
            DELAY-VARIABLE @ 20 * BUZZER-NOISE \ il delay è più grande, quindi il pedone può passare tranquillamente
        1 - DUP 0 = UNTIL DROP
        5 BEGIN
            TRAFFIC-LIGHT ON
            DELAY-VARIABLE @ 10 * DELAY
            DELAY-VARIABLE @ 5  * BUZZER-NOISE  \ il delay è più basso, quindi il verde sta per finire
            TRAFFIC-LIGHT OFF
            DELAY-VARIABLE @ 10 * DELAY
            DELAY-VARIABLE @ 5  * BUZZER-NOISE
        1 - DUP 0 = UNTIL DROP
    THEN
;

: BLINK ( -- )        \ fa lampeggiare un singolo LED
    CLEAR-DISPLAY     \ è necessario per pulire il display dalla scritta "FERMO!" iniziale
    TRAFFIC-LIGHT ON  \ in base al passo di LED-COUNTER, verrà abilitato un determinato pin
    >LCD-PRINT-HELPS 
    GREEN-LED-WARNING \ il verde lampeggia, per avvertire il pedone, e abilita il buzzer per i non vedenti, che avrà due tipi di oscillazioni: una più lenta per la prima metà del tempo, è una più veloce
    DELAY-IN DELAY
    TRAFFIC-LIGHT OFF \ in base al passo di LED-COUNTER, verrà disabilitato un determinato pin
    DELAY-OUT DELAY
    CLEAR-DISPLAY
    CHECK-LED-COUNTER \ con esso teniamo conto di quale LED accendere
;

: BLINK-TRAFFIC-LIGHT ( -- ) \ fa lampeggiare tutti e tre i LED facendo uso di BLINK
    BEGIN
        LED-COUNTER @        \ metto nello stack il valore fetchato di LED-COUNTER - PRIMA di aggiornarsi - per capire se a questo passo si è arrivati al semaforo verde
        BLINK
    2 = UNTIL                \ se si è arrivati al semaforo verde (LED-COUNTER = 2) arresta il ciclo
;

: PEDESTRIAN-CALL ( -- ) \ esegue una singola chiamata pedonale
    PUSH-BUTTON          \ PUSH-BUTTON fa partire il busy while, aspettando che ?PUSHED venga settato a 1 
    ?PUSHED @ 1 =        \ non appena si esce dal busy while di PUSH-BUTTON, si entra nell'IF per fare la richiesta pedonale
    IF 
        RESET-BUTTON     \ lo si resetta in modo che si possa ripremere per la successiva chiamata pedonale  
        BLINK-TRAFFIC-LIGHT
    THEN
;

: INIT-TRAFFIC-LIGHT ( -- ) \ inizializza il semaforo a ogni ciclo in START, settandolo a rosso e "FERMO!"
    RED ON                  \ accensione di default del semaforo rosso 
    S" FERMO!" >LCD-PRINT   \ accensione di default della scritta "FERMO!" 
;

\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \
