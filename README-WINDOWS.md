# Gestione Preventivi - Il Tornitore / Windows

## File da copiare nel repository GitHub

1. `assets/app_icon.ico` -> nella cartella `assets/`
2. `.github/workflows/build-windows.yml` -> nella cartella `.github/workflows/`

Il workflow:
- crea il supporto Windows Flutter;
- installa le dipendenze;
- sostituisce l'icona Windows;
- imposta il nome prodotto;
- esegue `flutter build windows --release`;
- crea `Gestione-Preventivi-Il-Tornitore-Windows-x64.zip`;
- lo pubblica negli Artifacts di GitHub Actions.

Dopo il commit, aprire GitHub > Actions > Build Preventivi Windows.
L'artifact sarà disponibile nella pagina della build completata.
