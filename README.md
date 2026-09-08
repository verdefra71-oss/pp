# Balloon Designer 🎈

Prima versione Flutter di un'app per balloon artist.

## Funzioni MVP
- Caricamento immagine da galleria o fotocamera
- Analisi locale dell'immagine
- Raggruppamento colori e stima della superficie
- Stima iniziale del numero di palloncini
- Dimensione finale in centimetri
- Modifica manuale della quantità per sezione
- Salvataggio locale dei progetti
- Esportazione/condivisione PDF

## Avvio
```bash
flutter pub get
flutter analyze
flutter run
```

## Build APK
```bash
flutter build apk --release
```

## Limite importante della V1
L'analisi è un algoritmo locale MVP: non riconosce ancora in modo semantico
personaggi, arti, contorni o forme specifiche. La V2 può integrare una
segmentazione AI/visione artificiale e trasformare ogni area in una sezione
di costruzione più precisa.

## Prossime funzioni consigliate
1. Editor grafico delle sezioni sulla foto.
2. Griglia e numerazione dei palloncini.
3. Libreria dei tipi di palloncino e delle misure.
4. Calcolo basato su altezza/larghezza e densità configurabile.
5. Riconoscimento AI di parti della figura.
6. Template per archi, colonne, mosaici e sculture.
