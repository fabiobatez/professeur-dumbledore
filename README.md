# Professeur Dumbledore 

Cette app mobile vous aide à prononcer correctement au moins 8 formules magiques, en utilisant la reconnaissance vocale du téléphone et un petit moteur de similarité pour évaluer la prononciation.

## Fonctionnalités

- Reconnaissance vocale (`speech_to_text`) sur Android/iOS.
- Feedback vocal (`flutter_tts`) en français.
- Découverte des formules dans `assets/spells.json` (modifiables).
- Fallback Web: champ de saisie (utile pour tester l’UI sans micro).
- Script de génération de dataset audio (voir `tools/generate_dataset.py`).

## Démarrage rapide

1. Activez le mode développeur de Windows (nécessaire pour les symlinks de plugins):
   `start ms-settings:developers`
2. Installez Android Studio (SDK + Platform Tools) et lancez `flutter doctor`.
3. Récupérez les dépendances: `flutter pub get`.
4. Lancer sur un appareil Android connecté (USB avec débogage activé):
   `flutter run -d <deviceId>` ou simplement `flutter run`.

> Autorisez la permission micro quand l’app vous la demande.

## Compiler un APK pour votre téléphone (Android)

- Commande: `flutter build apk --release`
- APK généré: `build/app/outputs/apk/release/app-release.apk`
- Copiez-le sur le téléphone et installez-le (autoriser les sources inconnues si nécessaire).

## iOS

- Nécessite macOS et Xcode pour signer et compiler. Sur Windows, ciblez Android.

## Générer un dataset audio (optionnel)

- Installez les dépendances: `pip install gTTS pydub` et installez FFmpeg.
- Lancez: `python tools/generate_dataset.py`
- Les fichiers `.wav` seront créés dans `dataset/generated/` avec bruits/variations de vitesse.

## Personnalisation des sorts

- Éditez `assets/spells.json`, puis: `flutter pub get` et relancez l’app.
- Le moteur de correspondance utilise une distance de Levenshtein pour gérer fautes et variations.

## Notes

- Sur Web, la reconnaissance vocale n’est pas activée; utilisez le champ de saisie pour tester l’UI.
- Sur Android réel, `speech_to_text` utilise les services du système, pouvant fonctionner hors-ligne selon les packs installés.

