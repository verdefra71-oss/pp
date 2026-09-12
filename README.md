# Gestione Familiare

Prima versione Flutter dell'app di gestione del bilancio familiare.

## Funzioni
- Dashboard mensile con entrate, uscite, saldo e budget.
- Entrate: stipendio, pensione, lavori extra, rimborsi e altre entrate.
- Spese: bollette, mutuo/affitto, auto, alimentari, casa, scuola, vacanze, regali e categorie personalizzabili.
- Conti separati per banca, carta e contanti.
- Movimenti con modifica ed eliminazione.
- Budget mensili per categoria.
- Report mensile e annuale.
- Spese ricorrenti per le principali bollette.
- Importazione manuale di movimenti bancari in formato CSV (data, descrizione, importo, conto).
- Sezione predisposta per sincronizzazione Open Banking: la connessione bancaria reale richiede un provider autorizzato e le credenziali/configurazioni del conto; non vengono mai richieste o salvate password bancarie nell'app.
- Backup locale esportabile come JSON tramite condivisione del testo.

## Avvio
1. Installare Flutter stabile.
2. `flutter pub get`
3. `flutter run`

Il progetto evita `intl` e `initializeDateFormatting`, così non presenta il precedente errore `LocaleDataException`.
