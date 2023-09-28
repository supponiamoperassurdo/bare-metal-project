
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
