# forth-project
Tutto ciò che serve da sapere è documentato in ``/docs``.

<br/>

Il progetto implementa un semaforo pedonale (fuori dalla leggi dell'ingegneria stradale)
che mostra come Forth (più correttamente, l'ambiente pijFORTHos) sia capace di manipolare
con semplicità i registri di un Raspberry Pi 3B per pilotare un qualunque dispositivo collegato a una sua GPIO.
A livello hardware, si è fatto uso di:

* tre led, per rosso/giallo/verde;
* un buzzer (per i tipici semafori per non vedenti);
* uno schermo LCD per mostrare l'uso dell'I2C.

