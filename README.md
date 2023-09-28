# forth-project
Tutto ciò che serve da sapere è documentato in ``/docs``.

<br/>

Il progetto implementa un semaforo pedonale (fuori dalla leggi dell'ingegneria stradale)
che mostra come Forth (più correttamente, l'ambiente pijFORTHos) sia capace di manipolare
con semplicità i registri di un Raspberry Pi 3B per pilotare un qualunque dispositivo collegato a una sua GPIO.
A livello hardware, si è fatto uso di:

* una macchina target, il Raspberry 3 (la variante del modello è irrilevante);
* un adattatore UART-USB, che verrà collegato alle GPIO 14 (TXD) e GPIO 15 (RXD) della macchina target;
* tre led, per rosso/giallo/verde;
* un buzzer (per i tipici semafori per non vedenti);
* uno schermo LCD per mostrare l'uso dell'I2C.

Per il corretto setup del sistema, è necessario:

* caricare il contenuto di ``/boot`` in una microSD formattata in formato FAT32;
* in config.txt, decommentare la linea ``enable_uart=1`` per consentire la comunicazione UART;

Per comunicare tra host e macchina target, è necessario eseguire le seguenti linee di codice su un sistema Unix-based:

    $ sudo apt install minicom picocom -y
    $ picocom --b 115200 /dev/ttyUSB0 --send "ascii-xfr -sv -l100 -c10" --imap delbs

Fatto ciò, è possibile inizializzare la comunicazione. Il terminale ``picocom`` si presenterà con ``Terminal ready``:
da quel momento si accenderà la macchina target e, per caricare il file .f, si userà la combinazione di tasti
``picocom`` ``[C-a] [C-s]`` (ovvero CTRL+A seguito da CTRL+S).
