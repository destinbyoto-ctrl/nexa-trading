# NEXA — Chambres de trading IA

Application mobile Flutter de trading crypto assisté par IA sur Binance spot.
Design « chambres » : chaque fonctionnalité vit dans sa propre salle, avec un
scanner radar animé en pièce centrale.

## Architecture

```
lib/
├── main.dart                # Entrée, thème sombre néon, écran de boot
├── core/
│   ├── models.dart          # PairScan, Position, TradeSettings
│   ├── binance_api.dart     # REST public + ordres signés HMAC (mode réel)
│   ├── engine.dart          # Moteur de scoring IA multipaires (0-100)
│   ├── portfolio.dart       # Positions, TP/SL, journal, persistance
│   └── app_state.dart       # Orchestrateur : WebSocket live, cycle 30 s
└── ui/
    ├── hub_screen.dart      # Le hall : portes des chambres
    ├── scan_room.dart       # Radar animé + classement des paires
    ├── trade_room.dart      # Positions ouvertes, P&L live
    ├── journal_room.dart    # Historique + statistiques
    ├── settings_room.dart   # Objectifs, risques, clés API
    └── widgets.dart         # Cartes lumineuses, barres, puces
```

## Le moteur

1. Sélectionne les **24 paires USDT les plus liquides** (volume 24 h).
2. Note chaque paire 0-100 : momentum 2 h (15 m), tendance EMA 9/21 sur 15 m
   confirmée en 1 h, pic de volume, RSI 14 en zone saine.
3. Un signal au-dessus du seuil (défaut 68) ouvre une position **calibrée pour
   viser un gain fixe par entrée (défaut +5 $)** : TP = 1,6×ATR borné 1,2-4,5 %,
   mise = cible / TP %, SL = TP / 2, frais 0,1 %/côté inclus.
4. Sortie au TP, au SL, à la durée max ou manuelle. Cooldown 15 min par paire.

Honnêteté : le TP vise le gain configuré, rien ne le garantit ; le SL est la
protection. Mode papier par défaut, mode réel uniquement avec clés API
enregistrées dans le stockage sécurisé de l'appareil.

## Performance

- Prix en direct par WebSocket Binance (miniTicker, reconnexion auto).
- Scan par vagues de 6 requêtes parallèles (24 paires en ~2 s).
- Interface 60 fps : aucun calcul lourd dans le rendu, notification throttlée.

## Build (Codemagic)

`codemagic.yaml` est prêt : APK release automatique, livré par e-mail.
Aucun `flutter analyze` bloquant, minSdk 23 (stockage sécurisé des clés),
target/compileSdk 34, Java 17.
