\ Quanto segue è un frammento di "jonesforth.f" appartenente alla repository:
\
\ > https://github.com/jdavidberger/pijFORTHos 
\
\ La word S" è essenziale per la manipolazione di stringhe: infatti, S" consente l'instanziazione di stringhe,
\ restituendo l'indirizzo iniziale del primo carattere e la lunghezza della stringa.
\ È risultato essenziale per la word ">LCD-PRINT".

: '"' [ CHAR " ] LITERAL ; \ ASCII del carattere "
: '(' [ CHAR ( ] LITERAL ; \ ASCII del carattere (
: ')' [ CHAR ) ] LITERAL ; \ ASCII del carattere )

\ Consente di creare commenti come ( a -- b )
: ( IMMEDIATE 1 BEGIN KEY DUP '(' = IF DROP 1+ ELSE ')' = IF 1- THEN THEN DUP 0= UNTIL DROP ; 

\ Le seguenti servono ad allineare opportunamente il puntatore HERE:
\ infatti, la word ALIGNED arrotonda "c-addr" a 4 bytes (una word ARM32)
: ALIGNED ( c-addr -- a-addr ) 3 + 3 INVERT AND ;
: ALIGN HERE @ ALIGNED HERE ! ;

\ Inserisce un byte alla fine della word attualmente compilata
: C, HERE @ C! 1 HERE +! ;

\ Descritto in precedenza la sua funzionalità, instanzia una stringa e ritorna il suo indirizzo e lunghezza
: S" IMMEDIATE ( -- addr len )
	STATE @ IF
		' LITS , HERE @ 0 ,
		BEGIN KEY DUP '"'
                <> WHILE C, REPEAT
		DROP DUP HERE @ SWAP - 4- SWAP ! ALIGN
	ELSE
		HERE @
		BEGIN KEY DUP '"'
                <> WHILE OVER C! 1+ REPEAT
		DROP HERE @ - HERE @ SWAP
	THEN
;

\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \

HEX                                 \ da ora in poi ogni numero verrà trattato come esadecimale

3F000000          CONSTANT PERIBASE \ dalla documentazione del BCM2837, montato sull'RPi 3B, l'indirizzo fisico delle perifiche spazza un range da 3F000000 a 3FFFFFFF
PERIBASE 200000 + CONSTANT GPIOBASE \ indirizzo base delle periferiche GPIO: corrisponde, in particolare, al registro GPFSEL0
GPIOBASE 34     + CONSTANT GPLEV0   \ rileva i cambiamenti di tensione in una GPIO, serve per rilevare i cambiamenti di pressione sulla GPIO 17
GPIOBASE 38     + CONSTANT GPLEV1   \ rileva i cambiamenti di tensione in una GPIO, serve per rilevare i cambiamenti di pressione sulla GPIO 17

\ L'input deve essere esadecimale, per semplicità.
\ La funzione è molto semplice: poiché sono dedicate terne di bit per selezionare una funzione
\ a ogni GPIO, e necessario shiftare di tre posizioni (moltiplicando per tre) per ottenere il
\ bit corrispondente al "limite inferiore", LIMITE_INF, ovvero [LIMITE_sup:LIMITE_inf] 
\ nella terna di bit riservata alla GPIO.
\ Per esempio:
\ > per la GPIO 9 si fa uso di GPSFEL0 e dei bit [29:27], e in effetti eseguendo 9 * 3 si
\   ottiene 27: dividendo per 30, si ottiene la corrispondente GPFSEL (0 in questo);
\ > per la GPIO 10 invece, 10 * 3 fa 30 che, diviso 30, produce 1: in effetti, la GPIO 10
\   appartiene a GPFSEL1.
: DETECT-GPFSEL ( pin -- gpfsel_address )
    3 *            \ moltiplico per la tripla di bit, così ottengo il corrispondente limite inferiore
    1E /           \ divido per 30 (sotto il numero massimo di bit non riservati) per ottenere il corrispondente GPFSEL
    4 * GPIOBASE + \ per ottenere il registro, si somma l'offset da GPIOBASE e, poiché ogni registro ha un offset di 4 byte l'un dall'altro, se GPFSEL(X) è diverso da 0, produce un offset aggiuntivo di 4, 8, ..., 20 bytes
;

\ Keyword per utilizzare le AFs del BCM2837 nella word INIT-GPIO
: FSEL-IN   0 ;
: FSEL-OUT  1 ;
: FSEL-ALT0 4 ;
: FSEL-ALT1 5 ;
: FSEL-ALT2 6 ;
: FSEL-ALT3 7 ;
: FSEL-ALT4 3 ;
: FSEL-ALT5 2 ;

\ Una volta individuata la GPFSEL, per scrivere nella terna corrispondente è necessario
\ far uso dell'operatore "30 MOD" per restare in range.
\ Scelta la FSEL-XXX, si scrive nei corrispondenti bit
: SET-FSEL ( pin fsel_mode -- )
    SWAP          \ trovo più intutivo scrivere il pin per primo e successivamente la modalità, perciò uso lo SWAP
    DUP >R        \ il pin servirà per calcolare il limite inferiore della terna di bit: lo metto nel return stack
    DETECT-GPFSEL \ si individua la GPFSEL, lo stack è [fsel_mode, GPFSEL]
    DUP @         \ mi serve due volte per fetcharne il valore attuale, sullo stack per ora c'è [fsel_mode, GPFSEL, GPFSEL@]
    ROT ROT       \ ruoto, quindi [GPFSEL, GPFSEL@, fsel-mode], per poi ruotare ancora (secondo ROT) ottenendo [GPFSEL@, fsel_mode, GPFSEL]
    R>            \ recupero "pin", lo stack è [GPFSEL@, fsel_mode, GPFSEL, pin]
    SWAP >R       \ Con uno SWAP metto GPFSEL sul TOS e con >R lo porto momentaneamente nel return stack: lo stack ora è [GPFSEL@, fsel_mode, pin]
    3 * 1E MOD    \ questo valore equivale al LIMITE_inf della terna, ed equivale al numero di shift da effettuare: lo stack è [GPFSEL@, fsel_mode, LIMITE_inf]
    LSHIFT        \ fsel-mode LIMITE_inf LSHIFT eseguirà uno shift di fsel-mode (che può essere 000, 001, ..., 111) di LIMITE_inf bit a sinistra, ottenendo [GPFSEL@, fsel_mode_to_word] 
    OR            \ in questo modo posso fare l'OR tra GPFSEL@ e fsel_mode_to_word
    R> !          \ recupero GPFSEL dallo stack e scrivo il valore di OR: l'operazione finale è GPFSEL @ fsel_mode_to_word OR GPFSEL !
;

\ Poiché vi sono due GPSET, di cui GPSET0 che fa uso di tutti e 32 i bit, bisogna solo verificare
\ se i 32 bit vengono "sforati" mediante divisione intera, per ottenere il corrispondente registro
: DETECT-GPSET ( pin -- gpset_address )
    20 /                \ divido per 32 per vedere se appartiene al primo o secondo GPSET
    4 * GPIOBASE + 1C + \ calcola l'offset rispetto alla GPIOBASE: GPSET0 dista 1C, mentre GPSET1 1C + 4
;

\ Esegue uno shift su un singolo bit 1 di N posizioni, in base all'input datogli:
\ utile per quei registri come GPSET, GPCLR o GPLEV 
: >WORD ( N -- word )
    1      \ [N, 1], shifta 1 di N bit a sinistra
    SWAP   \ [1, N], si fa lo swap in quanto nello stack ci sono [N, 1] ma per usare LSHIFT devono essere [1, N]
    LSHIFT \ 1 N LSHIFT, verranno eseguiti N shift sinistri sul numero "1"
;

\ Per settare una GPIO on tramite GPSET: considerando che ci sono due registri (il primo utilizza tutti i bit,
\ il secondo solo quelli [21:0]) è possibile, a partire da un input DECIMAL di un numbero N,
\ eseguire N shift sinistri a partire da un bit "1":
\ per esempio, per settare ON la GPIO 3, si faranno 3 shift sinistri per 1: SHIFT(0001, 3) = 1000 (il bit [3] è ON)
: ON ( pin -- )
    DUP
    DETECT-GPSET \ ritorna il registro corrispondente, nello stack ci sono [pin, GPSET]
    SWAP         \ [GPSET, pin]
    20 MOD       \ che sia GPSET0 o GPSET1, il bit ha la stessa posizione: "pin" diventa un numero N, che determina il numero di shift
    >WORD        \ a questo punto lo stack è [GPSET, pin_to_32_bit_word] 
    SWAP         \ ora [pin_to_32_bit_word, GPSET], pronto allo store
    !            \ abilito il corrispondente pin: il risultato sarà un istruzione del tipo "pin_to_32_bit_word GPSET !" 
;

: DETECT-GPCLR ( pin -- gpclr_address )
    20 /
    4 * GPIOBASE + 28 + \ calcola l'offset rispetto alla GPIOBASE: GPCLR0 dista 28, mentre GPCLR1 28 + 4
;

\ È l'analogo di ON per settare una GPIO off
: OFF ( pin -- )
    DUP
    DETECT-GPCLR
    SWAP
    20 MOD
    >WORD
    SWAP
    !  
;

: DETECT-GPLEV ( pin -- gpclev_address )
    20 /
    4 * GPIOBASE + 34 + \ calcola l'offset rispetto alla GPIOBASE: GPLEV0 dista 34, mentre GPLEV1 34 + 4
;

: INIT-GPIO ( -- )
    11 FSEL-IN  SET-FSEL \ pulsante, GPIO 17
    0D FSEL-OUT SET-FSEL \ buzzer, GPIO 13
    15 FSEL-OUT SET-FSEL \ led rosso, GPIO 21
    1A FSEL-OUT SET-FSEL \ led giallo, GPIO 26
    13 FSEL-OUT SET-FSEL \ led verde, GPIO 19
;

\ Provoca un delay
: DELAY ( delay -- )
    BEGIN 1 - DUP 0 = UNTIL DROP
;

\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \

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

\ Nel datasheet suggerisce che è possibile trasferire direttamente un byte
\ dividendelo antecedentemente in due nibble (4 bit) a cui vanno associati a loro volta un
\ due nibble di configurazione costruitu SEMPRE nel seguente modo:
\
\         D7   D7   D5   D4   (B)ack(L)igth (EN)able (R)ead/(W)rite (R)egister (S)elect
\         D7   D6   D5   D4   [BL            EN       RW             RS]
\
\ Dunque, il byte deve essere scomposto in due nibble: il MSB nibble (superiore) e il LSB nibble (inferiore):
\
\         MSB nibble: D7 D6 D5 D4 BL EN RW RS
\         MSB nibble: D3 D2 D1 D0 BL EN RW RS
\
\ Per denotare che sta avvenendo un trasferimento, RW = 0 (cioè "write"),
\ mentre per indicare che l'attuale input è un comando e non un semplice dato, RS = 0.
\ Dunque, per un qualunque byte B = [MS_Nibble || LS_Nibble], poiché il trasferimento
\ avviente a "colpi" di nibble a volta (4 bit alla volta), se si suppone essere un comando (RS = 0)
\ allora il trasferimento del byte [MS_Nibble || LS_Nibble] avverrebbe nel seguente modo:
\
\         MS_Nibble || 1 1 0 0 -> MS_Nibble || 1 0 0 0 -> LS_Nibble || 1 1 0 0 -> LS_Nibble || 1 0 0 0
\
\ Ovvero, ogni nibble si trasmette due volte concatenandolo SEMPRE a nibble di configurazione:
\
\         1 1 0 0: BL = 1, EN = 1, RW = 0, RS = 0/1
\         1 0 0 0: BL = 1, EN = 0, RW = 0, RS = 0/1
\
\ Il motivo per E = 1 e poi E = 0 è perché - secondo il datasheet - segnala che da quel momento avverrà il campionamento dei dati D7-D4.
\ Il fatto che RS sia 0 o 1 dipende dal fatto che si stia trasmettendo un dato o un comando. 
\ Quindi per la corretta implentazione, è necessario ritrasmettere il nibble con esso concatentazio:
\
\         0xC e poi 0x8, nel caso in cui sia un comando
\         0xD e poi 0x9, nel caso in cui sia un dato

: BYTE>LOWER-NIBBLE ( byte -- lower_nibble ) 0F AND ;

\ Divide il byte XXXXYYYY in YYYY XXXX (il MSB nibble lo mette sullo stack)
: DIVIDE-BYTE ( byte -- lower_nibble upper_nibble )
    DUP
    BYTE>LOWER-NIBBLE  \ si ottiene tramite la maschera 0F i primi 4 bit
    SWAP               \ si swappa col byte al di sotto,
    04 RSHIFT          \ si rshifta il byte che, per sicurezza, si maschera comunque
    BYTE>LOWER-NIBBLE           
;

\ Questa funzione in input riceve un bit di flag, che ci dirà se il byte da trasmettere è un comando o un dato
\ e restituirà i due nibble di configurazione. Questo "config_bit" è una scelta progettuale che ci
\ consente di scegliere se mandare un comando un dato all'LCD1602.
: GET-CONFIG-NIBBLES ( config_bit -- 1st_config_nibble 2nd_config_nibble )
    1 = IF   \ se si vuole trasmettere un comando...
        0C   \ 1100 primo nibble di configurazione a RS = 0
        08   \ 1000 secondo nibble di configurazione a RS = 0
    ELSE     \ se si vuole trasmettere un dato...
        0D   \ 1101 primo nibble di configurazione a RS = 1
        09   \ 1001 secondo nibble di configurazione a RS = 1
    THEN
;

\ Concatena un data_nibble di input col primo nibble di configurazione e, successivamente, ripete l'operazione col secondo nibble di configurazione.
\ In input riceve i due nibble di configurazione e il nibble da trasmettere, che dovrà ricombinare per avere i due byte pronti secondo standard;
\ lo stack iniziale sarà dunque [110X, 100X, XXXX], e l'output sarà [XXXX 100X, XXXX 110X] (si osservi che il primo nibble di configurazione debba essere nel TOS).
: CONCATENATE ( 1st_config_nibble 2nd_config_nibble data_nibble -- 1st_nibble_to_byte 2nd_nibble_to_byte )
    4 LSHIFT DUP \ il nibble - shiftato per trasformarlo in un byte - viene duplicato perché deve essere ritrasmesso con il secondo nibble di configurazione: lo stack è [110X, 100X, XXXX 0000, XXXX 0000]
    ROT OR       \ ROT porta "100X" (ottenuto da "GET-CONFIG-NIBBLES") nel TOS, il risultato sarà [110X, XXXX 0000, XXXX 0000, 100X], e con OR si ottiene [110X, XXXX 0000, XXXX 100X]
    -ROT OR      \ similmente, -ROT porta il TOS nel fondo, il risultato sarà [XXXX 100X, 110X, XXXX 0000] e si esegue l'OR: il risultato finale sarà [XXXX 100X, XXXX 110X]
;

\ La word riceve in input un nibble e un bit di flag che verrà passato a GET-CONFIG-NIBBLES:
\ non vi è output perché il nibble viene trasmesso tramite I2C 
: NIBBLE>I2C ( nibble configuration_bit -- )
    GET-CONFIG-NIBBLES \ il bit di flag viene passato a GET-CONFIG-NIBBLES per ricevere i nibble di configurazione:
    ROT                \ nello stack ci saranno [nibble, 110X, 100X] e, con ROT, si mette nel TOS il nibble;    
    CONCATENATE        \ CONCATENATE riceve in input [110X, 100X, nibble], ritornando due byte (due coppie di nibble, pronti alla trasmissione)
    >I2C 1000 DELAY    
    >I2C 1000 DELAY
;

\ Il nono bit viene utilizzato come flag per denotare se si stia
\ trasmettendo un dato o un comando; attualmente ci serve "conservarlo" per un secondo momento.
: >LCD ( input -- )  
    DUP              \ duplico in quanto del byte devo estrarre il nono bit di comando (config_bit)
    100 AND 8 RSHIFT \ estraggo il nono bit per vedere se è settato a 1 (è un comando) o a 0 (è un dato)
    DUP >R >R        \ il modo più semplice per conservarlo è facendo uso dello stack di ritorno: l'elemento nel TOS, mediante ">R", lo si inserisce in un altro stack e lo si recupera mediante ">R"; in questo caso, si sta duplicando il bit e lo si sta conservando due volte nello stack per poterlo "recuperare due volte"
    DIVIDE-BYTE      \ divide il byte nei due nibble
    R> NIBBLE>I2C    \ si manda il MSB nibble
    R> NIBBLE>I2C    \ si manda il LSB nibble
;

\ Dalla word S" si ottiene l'indirizzo di partenza della stringa e la sua lunghezza:
\ come in ogni linguaggio, la stringa è trattata come un array con delle celle.
: >LCD-PRINT ( address length -- )
    OVER +       \ OVER[address, length] = [address, length, address] per poi sommare i due elementi in TOS ottenendo [address, last_char_address]: infatti, sommando all'indirizzo di base "address" la lunghezza dell'array, ottengo l'indrizzo di fine stringa; raggiunto quell'indirizzo, concludo il loop
    SWAP         \ si swappano ottenendo [last_char_address, address] perché dovrò fetchare i caratteri dell'attuale indirizzo
    BEGIN        \ continua a stampare caratteri fin quando non si raggiunge l'indirizzo "last_char_address"
        DUP      \ esegui il DUP sulla cella per...
        C@ >LCD  \ (1) consumarne il carattere con C@ che esegue il char-fetch presente nell'indirizzo c-addr e lo si stampa con >LCD e (2) per eseguire il confronto con 2DUP
        1+       \ post-incremento all'indirizzo della cella per passare alla prossima
    2DUP = UNTIL \ 2DUP(address last_char_address) = (current_char_address last_char_address current_char_address last_char_address), e si paragonano (current_char_address last_char_address): se sono uguali, arresta il ciclo (si è raggiunto la fine)
    2DROP
;

\ Questa inizializzazione è IMPORTANTE perché si setta l'LCD1602 in modalità 4 bit
\ (invece di 8, si usano dunque i nibble) e si disabilitano i cursori
\ (l'LCD1602, quando viene acceso, abilta i cursori sulla prima riga).
: INIT-LCD 102 >LCD 10C >LCD ;

\ Comando per pulire il display
: CLEAR-DISPLAY 101 >LCD ;

\ = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = \

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
