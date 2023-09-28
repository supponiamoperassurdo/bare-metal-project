
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
