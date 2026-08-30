# Preventivi

App Flutter per la gestione di clienti, prodotti/servizi, preventivi, IVA, rate, PDF, backup e notifiche.

## Android

Il workflow `.github/workflows/build-apk.yml` crea l'APK release e lo pubblica come artifact `Preventivi-APK`.

## iOS

Il workflow `.github/workflows/build-ios.yml` mantiene la build iOS firmata e l'upload su App Store Connect quando i Secret Apple sono configurati.

## Windows

Il workflow `.github/workflows/build-windows.yml` prepara automaticamente il supporto Windows, installa le dipendenze, esegue l'analisi Dart e crea la build release Windows.

Artifact generati:

- `Preventivi-Windows` — ZIP pronto da estrarre ed eseguire.
- `Preventivi-Windows-Release` — cartella completa della release Windows.

### Database Windows

Su Android/iOS l'app continua a usare il database nativo `sqflite`. Su Windows viene usato SQLite tramite `sqflite_common_ffi`, mantenendo lo stesso schema e le stesse funzioni dell'app.

### Dati Windows

Il database viene salvato nella cartella documenti dell'app, sotto `databases`, mentre il backup automatico resta nella cartella `backup` dei documenti dell'app.

### Notifiche Windows

La configurazione Windows usa le notifiche locali di Windows. Le notifiche programmate dipendono dal supporto del sistema e dal packaging dell'app; per una distribuzione Windows più completa si può successivamente aggiungere un pacchetto MSIX.
