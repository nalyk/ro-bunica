# Interfața pe telefon (design, 2026-10-17)

Omul a trimis două capturi de pe telefon (1280×576) și a cerut „fă tot”, fără întrebări. Deciziile sunt ale agentului.

## Ce e greșit acum

1. **Cutia de apărare** (212×150, dreapta-jos):
   - butonul de săritură al Roblox stă peste „Furia Bunicii”;
   - ocupă zona degetului mare drept și colțul curții unde vin hoții;
   - cu 4 papuci, textul „Papuci: 3/3” iese din cutie;
   - bara de Nervi n-are etichetă.
2. **Coloana din stânga** (5–6 butoane rotunde pe toată înălțimea): jumătatea de jos e în zona joystick-ului, iar etichetele de ~8 px nu se citesc.
3. **Banii și ziua:** două pastile mari, 470×62, peste o bandă lată din partea de sus.
4. **Butoanele „Familie/Rivali” și „Schimb”** (versiunea 79) stau la (14, 106) și (14, 152), peste primele butoane din coloană. Problema există pe toate platformele.
5. **Panourile** au 60%×70% din ecran, cu maximum 660×540: pe un telefon de 667×339 ies cam 400×237.

## Principii

- **Zonele Roblox sunt sacre pe telefon:**
  - **joystick-ul dinamic** (landscape): stânga 40% din lățime, cele 2/3 de jos. Sursa: `DynamicThumbstick.layoutThumbstickFrame`;
  - **săritura:** citită din `PlayerGui.TouchGui.TouchControlFrame.JumpButton` la rulare;
  - **rezerva pentru săritură:** pe ecran mic (latura mică ≤ 500) mărimea e 70, poziția (W − 95, H − 90); altfel mărimea e 120, poziția (W − 170, H − 210). Sursa: `TouchJump`.
- **Atingerea** trebuie să aibă minimum 44 px pe orice buton.
- **Lumea rămâne vizibilă:** centrul ecranului și curtea nu sunt acoperite.
- **Geometria e pură și testată.** `Domain/HudLayout` primește mărimea ecranului, modul și dreptunghiul săriturii și întoarce dreptunghiurile elementelor. Testele Lune verifică, pe mai multe ecrane, că nimic nu atinge săritura sau joystick-ul, că totul e în ecran, că nimic nu se suprapune și că mărimile de atingere sunt respectate.

## Modurile

- **Touch:** `TouchEnabled` și fără mouse (telefoane, tablete).
- **Compact:** latura mică ≤ 500, la fel ca pragul Roblox pentru ecran mic.
- **Desktop:** restul (PC, consolă, laptop cu touch și mouse).

Modul se recalculează la schimbarea mărimii ecranului (rotire) și la o suprascriere de test.

## Layout-ul Touch

- **Rândul de acțiuni** (sus-stânga, sub bara Roblox), cu butoane rotunde fără etichete (46 px compact, 60 tabletă):
  - Semințe, Beci, Ograda, Caietul și „Mai mult”;
  - „Mai mult” deschide un meniu cu etichete: Horă, Prieteni, Magazin.
- **Starea** (sus-dreapta): pastila banilor și cadranul zilei, la scara 0,62 (compact) sau 0,8 (tabletă). Vremea și evenimentul live stau dedesubt, aliniate la dreapta.
- **Apărarea, lângă săritură, fără cutie:**
  - pe același rând cu săritura, spre stânga: Furia (56/72) lângă săritură, apoi Făcălețul (50/64), cu spațiu de 12 între ele;
  - deasupra săriturii, aliniată la dreapta: pastila muniției, cu papuci mici (cât încap, 22 px), „Nervi” și bara.
- **Bara de semințe:** un ScrollingFrame orizontal în banda liberă de jos, între joystick (0,42 × W) și apărare.
- **Notificările:**
  - bannerele sus, centrate sub rând;
  - toasturile jos, în banda dintre joystick și apărare.
- **Panourile:** 94%×92% pe compact, fără plafonul de 660×540.

## Layout-ul Desktop

- **Coloana:** Semințe, Beci, Horă, Ograda, Caietul, Prieteni (Prieteni înlocuiește „Cheamă prieteni”).
- **Cutia de apărare:**
  - lățimea se potrivește numărului de papuci (până la 5);
  - eticheta „Nervii Bunicii” stă peste bară;
  - Furia și Făcălețul rămân cu text.
- Butoanele plutitoare „Familie/Rivali” și „Schimb” dispar din HUD.

## Panoul „Prieteni” (nou, toate platformele)

- **„Cheamă prieteni”:** invitația Roblox, plus textul „+10% lei pentru fiecare prieten”.
- **„Familie sau rivali”**, vizibil cât e un prieten pe server:
  - explicația;
  - modul curent și butonul de schimbare (doar ziua, regula de pe server);
  - membrii familiei.
- **„Pe server”:** fiecare jucător, cu eticheta (prieten / familie) și butonul „Schimb” (`TradePanel.request`).
- TradePanel păstrează cererea Da/Nu și fereastra de schimb, dar pierde butonul și lista proprii.

## Root

`UI.screen()` întoarce un Frame „Root” din ScreenGui. În mod normal, Root umple ecranul. Pentru teste, `Layout.setOverride({ size, touch })` îl micșorează la mărimea unui telefon, aliniat sus-stânga, și forțează modul. Așa, playtest-ul din Studio vede și fotografiază HUD-ul exact ca pe telefon.

## Verificare

- **Unit (Lune):** `HudLayout` pe 667×339 (iPhone SE), 844×354 (iPhone 14), 800×324 (Android mic), 915×376 (Galaxy) și 1024×732 (tabletă), plus 1600×842 pe desktop.
- **Playtest:** pentru fiecare ecran de telefon din Studio:
  - Root micșorat;
  - auditul dreptunghiurilor reale (`AbsolutePosition`/`AbsoluteSize`) față de săritură, joystick și ecran;
  - lizibilitatea: etichetele vizibile au textul de cel puțin 11 px;
  - capturi.
- **Apoi:** tools.sh, e2e și playtest-ul complet. Commit, push, publicare live, CI.

## Ordinea de construcție

1. `Domain/HudLayout`, cu teste.
2. `Layout` pe client și Root în UI; panourile responsive.
3. HUD-ul: starea, acțiunile (coloană sau rând plus meniu), apărarea (cutie sau grup lângă săritură), bara de semințe.
4. Panoul Prieteni; TradePanel simplificat.
5. Notificările.
6. Playtest: suprascrierea, auditul și capturile.
7. Documentația (PRESENTATION, PROGRESS); verificarea completă; livrarea.
