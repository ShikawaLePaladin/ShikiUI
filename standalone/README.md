# ShikiUI — addons autonomes

Deux modules de ShikiUI sont aussi disponibles **seuls**, pour les joueurs qui n'utilisent pas ShikiUI :

| Addon | Ce qu'il fait | Commande |
|---|---|---|
| **ShikiPallyPower** | Bénédictions de raid pour paladin : grille d'attribution par classe, cycle de pose (portée / vue / Symboles des rois / pas d'interruption d'un soin), synchro entre paladins | `/sui pp` |
| **ShikiFinder** | Chercheur de groupe (LFG / LFM) : analyse des annonces des canaux publics, filtres, alertes, annonce de son propre groupe | `/sui lfg` |

## Installation

1. Copier le dossier `ShikiPallyPower/` et/ou `ShikiFinder/` dans `Interface/AddOns/`
   (les deux peuvent être installés ensemble : ils partagent le même socle).
2. Relancer le jeu (ou `/reload`).
3. `/sui` ouvre le menu de réglages (limité au module installé), `/sui pp` ou `/sui lfg` ouvre directement le module.

Le jeu peut être en français ou en anglais : les textes suivent la langue du client.

## Bon à savoir

- **Rien d'autre à installer.** Chaque dossier embarque le socle de ShikiUI (réglages, thème, déplacement des fenêtres).
- **Les deux ensemble** : le socle n'est chargé qu'une fois. Les réglages sont dans la variable sauvegardée `ShikiUIDB`.
- **Avec ShikiUI complet** : si ShikiUI est installé, ces addons se mettent en retrait et ne font rien (le module de ShikiUI complet prend la main, sans doublon). On peut donc laisser les dossiers sans conflit.
- Le module est **actif d'office** dans la version autonome (il est coupé par défaut dans ShikiUI complet).
- Pas d'assistant de premier lancement dans la version autonome (il configure tout ShikiUI).

## Pour les développeurs

Ces dossiers sont **générés** à partir des sources de `ShikiUI/` : ne pas les modifier à la main.

```
node tools/build_standalone.js          # régénère standalone/
node tools/build_standalone.js --check  # vérifie que standalone/ est à jour
```
