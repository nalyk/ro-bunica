# Planul de terminare (din 2026-10-16)

Jocul e public (https://www.roblox.com/games/5300295145). Ce lipsește ca să crească numărul de jucători simultani și
venitul, în ordinea în care se face. Fiecare pas se verifică cu `./tools.sh`, e2e și playtest, apoi se salvează.

## 1. Progres pe lei: magazinul de îmbunătățiri

Acum leii se cheltuie doar pe semințe, iar piedestalele (6 din 20) și straturile (4 din 10) nu se pot debloca.

- `Config/Upgrades`: piedestale +1 (până la 20), straturi +1 (până la 10), beci +10 locuri, papuci 3 → 5,
  reîncărcare mai rapidă, Grivei (câinele încetinește hoții din ogradă), Bunica mai ageră (bănuiala crește mai repede).
- Prețuri în creștere geometrică, calibrate pe venitul creaturilor (1 → 5.000 lei/s).
- Serverul validează (preț, nivel maxim), salvează în `profile.upgrades`, aplică efectul.
- Panou nou „Ogradă” cu buton în HUD, pe sistemul de design.

## 2. Vânzări pe Robux (GDD §13)

- Game passes: VIP (+4 piedestale, ramă pe gard), 2× lei, Papucul de Aur (urmă aurie), Beci mare (+50), Grădinar (+2 straturi).
- Developer products: pachete de lei, îngrășământ (creștere instantă), stoc nou de semințe, vreme pentru tot serverul.
- `MonetizationService` cu `ProcessReceipt` idempotent (chitanțele procesate în profil), anunț pe server.
- Fără protecție plătită contra furtului, fără cutii aleatorii, fără presiune de timp.

## 3. Măsurători (GDD §17)

- `AnalyticsService`: funnel-ul primelor 10 minute (intrare, sămânță, eclozare, primul hoț, prima noapte, primul furt, prima apărare),
  evenimente de economie (surse și cheltuieli de lei), evenimente proprii (furturi, lovituri pe noapte).

## 4. Revenire și social

- Recompensă zilnică cu serie, insigne (prima creatură, primul furt, prima apărare, legendar, horă), invitarea prietenilor.

## 5. Sunetul și vocea Bunicii

- Vocea (Gemini gratuit, după resetarea cotei), ambianța satului în 3D, efectele în tot UI-ul.

## 6. Performanță și finisaj

- `StreamingEnabled` evaluat pe telefon, mutațiile ca spectacol, verificare finală pe toate platformele.

Ce nu se face fără om: taxa de 1.000 Robux pentru publicul sub 16 ani și verificarea în doi pași a contului.
