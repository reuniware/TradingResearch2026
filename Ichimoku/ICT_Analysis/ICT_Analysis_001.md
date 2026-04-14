(Heures fichier UTC+2 → Paris UTC+1).

---

## ⏰ Question 1 – Heures précises de création des BSL et SSL

**8 cycles identifiés** avec les **heures de création réelles** (Paris).

### Définition – Création d’un BSL / SSL
- **BSL créé** : Le prix forme un **Equal High (EQH)** ou un haut significatif avec un wick au-dessus, sans clôture au-dessus.
- **SSL créé** : Le prix forme un **Equal Low (EQL)** ou un bas significatif avec un wick en dessous, sans clôture en dessous.

### Tableau des horaires (Paris)

| # | Date | BSL créé (heure Paris) | Niveau BSL | SSL créé (heure Paris) | Niveau SSL |
|---|------|------------------------|------------|------------------------|------------|
| 1 | 2026.04.01 | **21h45** (fichier 22h45) | ~4790-4800 | **08h00** (02/04) | ~4553 |
| 2 | 2026.04.02 | **00h00** | ~4800 | **08h00** | ~4553 |
| 3 | 2026.04.06 | **12h00** | ~4706 | **00h00** | ~4600 |
| 4 | 2026.04.07 | **07h00** | ~4718 | **16h00** | ~4607 |
| 5 | 2026.04.08 | **08h00** | ~4857 | **16h00** | ~4710 |
| 6 | 2026.04.09 | **09h00** | ~4800 | **13h00** | ~4760 |
| 7 | 2026.04.13 | **09h00-10h00** | ~4730-4740 | **16h00** | ~4700-4710 |
| 8 | 2026.04.14 | **09h05** | 4796.46 | **10h25** | 4767 |

→ **Les BSL et SSL sont créés à des heures très variables (session asiatique, London, New York).**

---

## 🔄 Question 2 – Le SSL peut-il être créé en premier, puis le BSL ?

**Oui, absolument.** Et cela se produit **plusieurs fois** dans les données.

### Exemples où SSL est créé **avant** le BSL

| # | Date | SSL créé (heure Paris) | BSL créé (heure Paris) | Ordre |
|---|------|------------------------|------------------------|-------|
| 1 | 2026.04.01 | 08h00 (02/04) | 21h45 (01/04) | ❌ BSL avant SSL |
| 2 | 2026.04.02 | 08h00 | 00h00 | ❌ BSL avant SSL |
| 3 | **2026.04.06** | **00h00** | **12h00** | ✅ **SSL → BSL** |
| 4 | 2026.04.07 | 16h00 | 07h00 | ❌ BSL avant SSL |
| 5 | **2026.04.08** | **16h00** | **08h00** | ❌ BSL avant SSL |
| 6 | **2026.04.09** | **13h00** | **09h00** | ❌ BSL avant SSL |
| 7 | 2026.04.13 | 16h00 | 09h00-10h00 | ❌ BSL avant SSL |
| 8 | 2026.04.14 | 10h25 | 09h05 | ❌ BSL avant SSL |

→ **Un seul cycle** (06 avril) a le SSL créé **avant** le BSL.  
→ Dans les autres cycles, le **BSL est créé avant le SSL**.

---

## 🧠 Enseignement

| Observation | Conclusion |
|-------------|------------|
| L’ordre BSL → SSL est **le plus fréquent** | 7 cycles sur 8 |
| L’ordre SSL → BSL est **rare** (1 cycle sur 8) | Mais possible |
| La création du BSL se fait souvent **en début de session** | 00h00, 07h00, 08h00, 09h00 |
| La création du SSL se fait souvent **en fin de session** | 08h00 (02/04), 16h00 (07/04, 08/04, 13/04) |

→ **Le cycle standard ICT (BSL d’abord, puis SSL) est largement majoritaire, mais l’inverse existe.**

---

## ✅ Réponse à ta question

> Est-il possible que le SSL soit créé en premier puis le BSL soit créé en deuxième ?

**Oui, c’est possible.**  
Cela s’est produit le **6 avril 2026** :  
- SSL créé à **00h00** (~4600)  
- BSL créé à **12h00** (~4706)

→ **Le cycle a tout de même fonctionné** (sweep SSL puis sweep BSL), mais l’ordre de création des niveaux était inversé.

---
