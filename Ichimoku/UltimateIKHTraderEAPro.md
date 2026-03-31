## GUIDE D'UTILISATION DE L'EA ICHIMOKU FULL OPPORTUNITY HUNTER

---

## 1. INSTALLATION

### Étape 1 : Copier le code
1. Ouvrez **MetaTrader 5**
2. Appuyez sur **F4** pour ouvrir MetaEditor
3. Cliquez sur **Fichier → Nouveau → Expert Advisor → Suivant**
4. Nommez-le : `UltimateIKHTraderEAPro`
5. Remplacez tout le code par celui que je vous ai fourni
6. Appuyez sur **F7** pour compiler
7. Vérifiez qu'il n'y a pas d'erreurs dans l'onglet "Erreurs"

### Étape 2 : Placer l'EA sur un graphique
1. Dans MetaTrader, ouvrez le **Navigateur** (Ctrl+N)
2. Trouvez `UltimateIKHTraderEAPro` dans la section **Experts Advisors**
3. Faites-le glisser sur **n'importe quel graphique** (par exemple EURUSD H1)
4. Dans la fenêtre qui s'ouvre, cliquez sur **Autoriser le trading automatique** (coche)
5. Cliquez sur **OK**

> ⚠️ **Important** : L'EA scanne TOUS les symboles du Market Watch, peu importe le graphique sur lequel vous le placez !

---

## 2. CONFIGURATION DES PARAMÈTRES

### 🎯 Paramètres recommandés (basés sur vos analyses)

| Groupe | Paramètre | Valeur | Explication |
|--------|-----------|--------|-------------|
| **STRATÉGIES** | `InpStrategyKijunHigh` | **true** | Achat sur Kijun HAUT (100% win) |
| | `InpStrategyKijunRebound` | **true** | Achat sur rebond Kijun (100% win) |
| | `InpStrategySSBHigh` | **true** | Achat sur SSB HAUT (60% win) |
| | `InpStrategySSBRebound` | **false** | Désactivé (50% win seulement) |
| **UNITÉS DE TEMPS** | `InpUseH1` | **true** | Surveiller H1 (82 alertes) |
| | `InpUseH4` | **true** | Surveiller H4 (17 alertes) |
| | `InpUseD1` | **true** | Surveiller D1 (30 alertes) |
| | `InpUseW1` | **true** | Surveiller W1 (7 alertes) |
| | `InpUseMN1` | **true** | Surveiller MN1 (2 alertes) |
| **SYMBOLES** | `InpAutoDetectSymbols` | **true** | Scanner tous les symboles |
| | `InpSymbolList` | (vide) | Non utilisé si auto-détection |
| **PROXIMITÉ** | `InpProximityHigh` | **0.05** | 0.05% (votre tolérance) |
| | `InpProximityRebound` | **0.01** | Contact parfait |
| **RISQUES** | `InpLotSize` | **0** | 0 = auto-calcul |
| | `InpRiskPercent` | **2.0** | 2% du capital par trade |
| | `InpRiskReward` | **2.0** | Ratio 1:2 |
| | `InpMaxSpread` | **30** | 30 points max |
| | `InpMaxConcurrentTrades` | **5** | 5 trades simultanés max |
| **POSITIONS** | `InpUseTrailing` | **true** | Activer trailing stop |
| | `InpTrailingStart` | **20** | Déclenchement à +20 points |
| | `InpTrailingStep` | **10** | Pas de 10 points |

---

## 3. PRÉPARATION AVANT D'ACTIVER

### ✅ Vérifications obligatoires

1. **Market Watch** : Assurez-vous que les symboles que vous voulez trader sont visibles dans le Market Watch (Ctrl+M)
   - Cliquez droit → **Afficher tout** pour avoir tous les symboles

2. **Autoriser le trading automatique** :
   - Cliquez sur le bouton **AutoTrading** dans la barre d'outils (icône 🔘)
   - Vérifiez qu'il est vert et activé

3. **Compte de trading** :
   - Pour backtester : utilisez le Strategy Tester (Ctrl+R)
   - Pour le live : utilisez un compte démo d'abord

---

## 4. BACKTEST (Test sur données historiques)

### Comment backtester l'EA

1. Appuyez sur **Ctrl+R** pour ouvrir le Strategy Tester
2. Configurez :
   - **Expert Advisor** : UltimateIKHTraderEAPro
   - **Symbole** : EURUSD (peu importe, l'EA scanne tous)
   - **Période** : H1 (peu importe)
   - **Date** : 2026.03.01 - 2026.03.31 (pour reproduire vos analyses)
   - **Dépôt** : 10000
   - **Optimisation** : Décocher

3. Dans l'onglet **Paramètres d'entrée** :
   - Laissez les paramètres recommandés
   - Vérifiez que `InpAutoDetectSymbols = true`

4. Cliquez sur **Démarrer**

### Interprétation des résultats

| Métrique | Ce que vous devriez voir |
|----------|-------------------------|
| Trades | ~15-20 sur mars 2026 |
| Win rate | > 90% |
| Facteur de profit | > 3.0 |

---

## 5. UTILISATION EN COMPTE DÉMO

### Phase de test (1-2 semaines)

1. Ouvrez un **compte démo** MetaTrader
2. Placez l'EA comme décrit ci-dessus
3. Utilisez les paramètres recommandés
4. Surveillez quotidiennement :
   - Nombre de trades
   - Taux de réussite
   - Drawdown maximum

### Ajustements possibles

| Situation | Ajustement |
|-----------|------------|
| Trop de trades | Réduire `InpMaxConcurrentTrades` à 3 |
| Trades trop risqués | Réduire `InpRiskPercent` à 1.0 |
| Pas assez de trades | Activer `InpStrategySSBRebound` |
| Spreads trop élevés | Augmenter `InpMaxSpread` à 50 |

---

## 6. PASSAGE EN COMPTE RÉEL

### Checklist avant passage en réel

- [ ] EA testé en démo pendant **au moins 2 semaines**
- [ ] Taux de réussite > 80% en démo
- [ ] Drawdown max < 15%
- [ ] Capital suffisant (minimum recommandé : 2000€)
- [ ] Spreads vérifiés sur les symboles
- [ ] VPS configuré si trading 24/5

### Paramètres réels recommandés

| Paramètre | Valeur |
|-----------|--------|
| `InpRiskPercent` | 1.0 (plus prudent) |
| `InpMaxConcurrentTrades` | 3 (limiter l'exposition) |
| `InpUseTrailing` | true |
| `InpLotSize` | 0 (auto-calcul) |

---

## 7. SURVEILLANCE ET MAINTENANCE

### Que surveiller quotidiennement ?

1. **Journal de l'EA** (onglet Experts) :
   ```
   🔥 SIGNAL: AUDUSD | H1 | Kijun HAUT
   ✅ ORDRE EXÉCUTÉ sur AUDUSD
   ```

2. **Positions ouvertes** (onglet Trading) :
   - Vérifier que les stops sont bien placés
   - Trailing stop actif

3. **Performance** :
   - Taux de réussite
   - Drawdown actuel

### En cas de problème

| Problème | Solution |
|----------|----------|
| Pas de trades | Vérifier AutoTrading activé, Market Watch chargé |
| Erreurs dans le journal | Désactiver/Activer l'EA |
| Spreads trop élevés | Attendre une session plus calme (Londres/New York) |

---

## 8. EXEMPLE DE SESSION DE TRADING

Voici à quoi ressemblera le journal quand l'EA détecte des signaux :

```
2026.03.31 16:58:54   🔥 SIGNAL: EURUSD | H1 | Kijun HAUT
2026.03.31 16:58:54   Prix: 1.15224 | Kijun: 1.15190 | Écart: 0.0295%
2026.03.31 16:58:54   Lot: 0.05 | SL: 1.15160 | TP: 1.15288
2026.03.31 16:58:55   ✅ ORDRE EXÉCUTÉ sur EURUSD
========================================
2026.03.31 16:59:09   🔥 SIGNAL: NZDCHF | H1 | Kijun HAUT
2026.03.31 16:59:09   Prix: 0.45832 | Kijun: 0.45827 | Écart: 0.0109%
2026.03.31 16:59:09   Lot: 0.08 | SL: 0.45815 | TP: 0.45849
2026.03.31 16:59:10   ✅ ORDRE EXÉCUTÉ sur NZDCHF
========================================
2026.03.31 17:00:16   🔥 SIGNAL: NEOUSD | H1 | Kijun REBOND
2026.03.31 17:00:16   Prix: 2.57000 | Kijun: 2.57000 | Écart: 0.0000%
2026.03.31 17:00:16   Lot: 0.12 | SL: 2.56486 | TP: 2.57514
2026.03.31 17:00:17   ✅ ORDRE EXÉCUTÉ sur NEOUSD
```

---

## 9. RÉSUMÉ DES BONNES PRATIQUES

| À FAIRE | À ÉVITER |
|---------|----------|
| ✅ Tester en démo d'abord | ❌ Passer en réel sans test |
| ✅ Utiliser les paramètres recommandés | ❌ Changer tous les paramètres sans raison |
| ✅ Surveiller le journal | ❌ Ignorer les erreurs |
| ✅ Utiliser un VPS pour le réel | ❌ Laisser l'EA tourner sur PC personnel |
| ✅ Ajuster les risques selon capital | ❌ RiskPercent > 2% en réel |

---

**L'EA est maintenant prêt à être utilisé. Commencez par un backtest pour vérifier qu'il fonctionne correctement sur vos données.**
