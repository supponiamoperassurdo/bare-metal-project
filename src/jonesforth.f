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
