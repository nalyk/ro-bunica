# BUNICA — Game Design Document (v2)

Sursa de adevăr pentru design. Înlocuiește pitch-ul din `BUNICA — Roblox Game Concept.md` (păstrat ca istoric).
Starea construcției: `docs/PROGRESS.md`. Arhitectura și convențiile de cod: `docs/ARCHITECTURE.md`.

## 1. Pe scurt

**O propoziție:** Crești creaturi trăsnite din mâncare, le furi pe ale prietenilor și îi bați cu papucul Bunicii când vin după ale tale.

**Fantezia:** „Ograda mea, creaturile mele, papucul Bunicii — și tot ce e al tău o să fie al meu.”

**Poziționare:** comedie universală cu bunici, făcută în Moldova. Papucul („la chancla”, „chinelo da mãe”, „тапок”) e cârligul universal. Partea moldovenească e pielea: creaturile din mâncare, satul, stilul de broderie.

**Piețe țintă:** Brazilia, America Latină, Europa de Est (MD, RO, UA, PL, Balcani), apoi global.

**Limbi de la început:** RO, RU, EN, ES, PT-BR. Textele și numele creaturilor se scriu de mână pe fiecare limbă, nu prin traducere automată.

**Echipă și mod de lucru:** un singur om plus agenți AI. Totul e construit pe date (config), lumea e generată din cod, conținutul nou înseamnă o intrare nouă într-un tabel.

**Succes:** CCU mare și venit real, ambele. Lansăm când jocul e gata, fără dată fixă.

## 2. Principii de design

1. **Un singur rând, cinci secunde.** Un copil explică jocul unui prieten într-o frază și prietenul râde.
2. **Om contra om.** Papucul îl aruncă proprietarul. Hoțul se poate feri. Țipetele vin din faptul că de ambele părți e o persoană.
3. **Gluma devine abilitate.** Ochitul, eschivele, loviturile norocoase de la capătul ogrăzii și escaladarea (papuc → făcăleț → Furia Bunicii) țin gluma proaspătă.
4. **Cultura vine ca meme, niciodată ca lecție.**
5. **Umor de copii:** papuci, plăcinte zburătoare, ceapă furioasă. Fără satiră politică sau glume pentru adulți.
6. **Jucabil fără citit și fără chat.** Iconițe, săgeți, pinguri, mesaje rapide predefinite.
7. **Fiecare sesiune produce un clip.** Lovitura de papuc, mutațiile, drop-urile legendare și furturile mari sunt anunțate tuturor de pe server.
8. **Prietenii fac jocul mai bun, nu doar mai mare.** Bonus de prieten, crew-uri, raiduri în echipă.
9. **Fără pay-to-win în raiduri.** Protecția nu se cumpără.

## 3. Loop-ul principal

1. **Plantezi** semințe în straturile ogrăzii.
2. **Crește** o creatură în timp real; vremea o poate muta într-o variantă rară.
3. **Expui** creatura pe un piedestal din ogradă: produce lei pe secundă, dar poate fi furată noaptea. Sau o ții în **beci**: e în siguranță, dar nu produce.
4. **Furi** noaptea creaturile altora și le cari acasă, mai încet, cu ele deasupra capului.
5. **Aperi** ograda cu papucul: o lovitură trimite hoțul în zbor și creatura se întoarce acasă.
6. **Te lauzi:** cele mai rare creaturi stau pe gardul dinspre drum, la vedere pentru tot serverul.

Decizia centrală a jucătorului: **expun (câștig, dar risc) sau ascund (sigur, dar nu câștig)?** Și a doua: **stau să-mi apăr ograda sau plec la furat?**

## 4. Serverul și ogrăzile

- Un server are **8 ogrăzi** de-a lungul unui drum de sat (4 pe fiecare parte). Mărimea serverului: 8 jucători.
- La intrare primești o ogradă liberă. Creaturile și straturile tale se încarcă din DataStore.
- **Ograda există doar cât ești pe server.** La ieșire, totul se salvează și ograda se golește. Nu există raiduri offline.
- **Ogrăzile libere sunt locuite de „vecini” NPC**, cu creaturi comune și o bunică leneșă. Un server cu puțini jucători rămâne jucabil, iar tutorialul de furt folosește un vecin NPC.
- Structura unei ogrăzi: gard cu poartă spre drum, casă cu prispă (Bunica stă acolo), straturi de plantat, piedestale pentru creaturi, ușa beciului (zona de depozitare pentru furturi) și gardul de laudă spre drum.

## 5. Creaturi

### Rarități

Valorile sunt de pornire și se ajustează din `Config/Rarities` și `Config/Creatures`.

| Raritate | Venit (lei/s) | Timp de creștere | Preț sămânță |
| --- | --- | --- | --- |
| Comun | 1–5 | 30–60 s | 10–100 |
| Rar | 10–25 | ~2 min | 500–2.000 |
| Epic | 50–120 | ~5 min | 5k–20k |
| Legendar | 300–700 | ~10 min | 100k–300k |
| Mitic | 2k–5k | ~20 min | 2M–5M |
| Secret | foarte mare | doar din evenimente | nu se vinde |

### Mărime

Se decide la plantare: Mică (×0,8), Normală (×1), Mare (×1,5), Uriașă (×3, rară). Mărimea se vede și e bună de clip.

### Lotul inițial

Toate creaturile sunt originale. Nu copiem meme-uri existente (de exemplu nume de „Italian brainrot”).

| Creatură | Ce e | Raritate |
| --- | --- | --- |
| Cartofel Agent | un cartof spion cu ochelari | Comun |
| Ardeiaș Iute | un ardei roșu care fuge | Comun |
| Covrig Skater | un covrig pe skateboard | Comun |
| Gogoașă Ninja | o gogoașă asasin | Rar |
| Ceapa Turbo | o ceapă cu bocanci-rachetă | Rar |
| Strugurel Furios | un ciorchine de struguri furios | Rar |
| Pepene Boxer | un pepene cu mănuși de box | Epic |
| Sarmalina Ballerina | o sarma care dansează | Epic |
| Mămăligator | un crocodil de mămăligă | Epic |
| Brânzoi Sumo | un cubuleț de brânză luptător sumo | Legendar |
| Plăcintonio Bombardino | o plăcintă zburătoare | Legendar |
| Colțunaș Pirat | un colțunaș cu petic pe ochi | Legendar |
| Cozonac Robot | un cozonac robot | Mitic |
| Dovleac DJ | un dovleac la pupitru | Mitic |
| Rețeta Secretă | caietul de rețete al Bunicii, viu | Secret |

## 6. Vreme și mutații

Evenimentele meteo sunt ale întregului server și apar programat (config) sau cumpărate de un jucător pentru tot serverul.
Plantele în creștere și creaturile expuse au o șansă pe tick să primească mutația evenimentului.
O creatură are o singură mutație; una mai valoroasă o înlocuiește pe cea mai slabă, niciodată invers. Vremea nu distruge nimic.

| Eveniment | Mutație | Multiplicator | Note |
| --- | --- | --- | --- |
| Ploaie | Udă | ×2 | creșterea merge de 1,5× mai repede |
| Grindină | Grindinată | ×3 | moment vizual mare: gheață pe acoperișuri |
| Noapte geroasă | Înghețată | ×4 | doar noaptea |
| Culesul de aur | Aurie | ×10 | rar |
| Curcubeu | Curcubeu | ×20 | foarte rar sau cumpărat |

Momentul de clip: planta se zguduie, strălucește și explodează în varianta rară, cu un fulger de cusături aurii.

## 7. Furtul

- Se fură **doar noaptea**, doar creaturi **expuse** pe piedestal, doar de la jucători prezenți pe server și fără scut.
- Hoțul ține apăsat pe creatură (1,5 s pentru Comun, mai mult pentru rarități mari), apoi o cară deasupra capului.
- Cu creatura în brațe, hoțul **merge mai încet** (×0,75, iar la Legendar și peste ×0,6) și nu poate sări sus.
- Furtul reușește când hoțul ajunge la **ușa beciului din propria ogradă**. Creatura devine a lui.
- Furtul eșuează când hoțul e lovit de papuc, iese de pe server sau proprietarul iese de pe server. În toate cazurile creatura se întoarce la proprietar. Așa nu apar duplicate.
- Orice viteză de deplasare imposibilă (teleport, speed hack) anulează furtul.
- **Victima primește un scut de 60 s** după un furt reușit.
- **Jucătorii noi nu pot fi jefuiți** în primele 20 de minute de joc.
- Anunț pe server la furturi mari: „Ana a furat Plăcintonio Bombardino de la Mihai!”.

## 8. Apărarea: papucul și Bunica

### Papucul (arma proprietarului)

- Proprietarul are mereu papucul. Pe mobil atinge ecranul unde vrea să arunce, pe PC dă click.
- **3 papuci**, se reîncarcă câte unul la 2,5 s. Traiectorie ușor curbată, se vede clar, deci te poți feri.
- Papucul lovește doar **intruși**: jucători aflați în ograda ta sau care îți cară o creatură. Nu poți hărțui pe nimeni pe drum.
- **Lovitura:** hit-stop, încetinire scurtă, strigătul Bunicii, hoțul zboară spre poartă, e amețit 1,2 s și scapă creatura, care se întoarce pe piedestal.

### Escaladarea: Nervii Bunicii

Bara **Nervi** se umple la fiecare lovitură reușită și se golește la răsărit.

| Nivel | Cost | Efect |
| --- | --- | --- |
| Papuc | gratis | proiectil simplu |
| Făcăleț | 50 Nervi | proiectil greu, lovește în zonă (8 studs), aruncă mai departe |
| Furia Bunicii | 100 Nervi | Bunica iese de pe prispă 8 s și urmărește singură hoții |

### Bunica (personaj, apărare de bază)

Bunica e personaj, nu doar o armă. Are fața, vocea și reacțiile ei: doarme, devine bănuitoare („?”), se trezește, sărbătorește când nimerești și se supără când ratezi.

Când **proprietarul lipsește** din ogradă (e plecat la furat), Bunica apără singură, dar slab:

1. Doarme. Un hoț pe care îl vede îi umple bara de bănuială.
2. La bănuială plină se trezește și aruncă un papuc **lent și anunțat** (avânt de 0,6 s), dodge-abil, la câteva secunde.
3. **Cocoșul** cântă și proprietarul primește alertă: pictogramă, sunet și săgeată spre ogradă.

Așa ambele roluri au sens: plecat la furat riști, dar nu ești lăsat complet descoperit.

### Upgrade-uri (pe lei, nu pe Robux)

- **Grivei** (câinele): latră la hoți și îi încetinește în ogradă.
- **Cocoș de alarmă mai bun**: alertă mai devreme, din drum.
- **Bunica mai ageră**: bănuiala crește mai repede, aruncă mai precis.
- **Mai mulți papuci** (3 → 5) și reîncărcare mai rapidă.
- **Ținute** pentru Bunica (trening, astronaut): doar cosmetice.

## 9. Ziua și noaptea

| Fază | Durată (pornire) | Ce se întâmplă |
| --- | --- | --- |
| Zi | 6 min | crești, cumperi, vinzi, decorezi; fără furturi |
| Noapte | 3 min | furturile sunt deschise, Bunica e de pază, tensiunea crește |

Trecerea în noapte e un moment de 3 secunde: cerul trece la indigo, ferestrele se aprind, Bunica deschide ochii. Duratele sunt în config.

## 10. Economie

- **Moneda de joc: lei.** Surse: venitul creaturilor expuse (pe secundă), vânzarea creaturilor la Piață, recompense zilnice.
- **Cheltuieli:** semințe, piedestale și straturi în plus, upgrade-uri de apărare, decorațiuni.
- **Taraba cu semințe** are stoc care se reînnoiește la 5 minute, cu șanse mai mici pentru semințele rare. E motiv de revenire, dar fără presiune pe Robux.
- **Valoarea unei creaturi** = venitul de bază × multiplicatorul mutației × multiplicatorul mărimii.
- **Vânzare la Piață:** valoarea × 30 (ajustabil).
- **Sloturi la început:** 4 straturi, 6 piedestale, beci de 30. Toate se extind.
- **Venit offline:** creaturile lăsate pe piedestale produc 10% cât ești plecat, maximum 8 ore. Te așteaptă un sac cu lei la revenire.

## 11. Primele 10 minute

| Timp | Ce trăiește jucătorul | Scop |
| --- | --- | --- |
| 0:00 | Apare în ograda lui. Bunica face cu mâna de pe prispă. Fără creare de personaj, fără text. | proprietate imediată |
| 0:15 | O sămânță deja plantată crește și eclozează: primul Cartofel Agent dansează pe piedestal. | prima surpriză |
| 0:45 | O săgeată duce la taraba cu semințe; cumpără două cu leii de start. | progres vizibil |
| 1:30 | Plantează cu o atingere; contorul de lei crește. | loop |
| 2:00 | Un hoț NPC se furișează. Jucătorul primește papucul, cu ajutor la ochit, și îl nimerește. Bunica sărbătorește. | gluma de bază, garantată, făcută de jucător |
| 3:00 | Iese pe drum și vede gardurile vecinilor pline de creaturi rare. | viitor accesibil |
| 4:00 | Prima noapte: furt ghidat de la un vecin NPC. | învață să fure în siguranță |
| 6:00 | Aduce creatura acasă și o pune la vedere. | prima laudă |
| 8:00 | Prima lui plantă primește garantat o mutație („Udă”). | primul moment „OMG” |
| 10:00 | Cartonaș-rezumat „Prima zi la Bunica” și invitație pentru prieteni (bonus de prieten). | motiv de revenire și invitație |

Jucătorul nu poate fi jefuit pe toată această secvență (scutul de 20 de minute).

## 12. Social și creștere (CCU)

- **Bonus de prieten:** +10% lei pentru fiecare prieten Roblox de pe același server, maximum +50%.
- **Anunțuri pe server** pentru eclozări legendare, mutații rare, furturi mari și lovituri spectaculoase. Toată lumea vede momentul.
- **Clasamente:** cei mai bogați, cei mai buni hoți, cei mai buni apărători (lovituri de papuc). Pe server și global.
- **Gardul de laudă:** primele 3 creaturi ale tale stau pe gardul dinspre drum, cu eticheta mutației.
- **Recompense obișnuite pe Roblox:** intrare în grup, like și favorite, serie zilnică de logări.
- **Iconița și thumbnail-ul** se schimbă ușor, ca să le testăm A/B.
- **Creatori de conținut:** creatori din MD, RO, BR, LATAM și RU primesc creaturi exclusive numite după ei. Provocări reale („Pot 5 dintre noi să fure de la o singură Bunică într-o noapte?”). Sponsorizarea se declară clar.

## 13. Monetizare

Monetizăm identitatea, comoditatea și momentele sociale. Niciodată frica sau jocurile de noroc.

**Game passes:**

- VIP: +4 piedestale, ramă VIP pe gard.
- 2× lei.
- Papucul de Aur: urmă și efect de lovitură aurii (cosmetic).
- Beci mare: +50 locuri în beci.
- Grădinar: +2 straturi.

**Developer products:**

- Pachete de lei.
- Îngrășământ: termini instantaneu creșterea unei plante.
- Reînnoirea instantă a stocului personal de semințe.
- Semințe anume cumpărate direct (fără element aleatoriu).
- **Vreme pentru tot serverul** (Grindină, Culesul de aur, Curcubeu): cumpărătorul e anunțat pe server. E momentul social cu cel mai mare potențial de venit.

**Cosmetice:** skin-uri de papuc, ținute pentru Bunica, decorațiuni pentru ogradă, rame de gard, pălării pentru creaturi.

**Altele:** reclame cu recompensă (dacă sunt disponibile pe platformă) și Premium Payouts.

**Nu facem:**

- Protecție plătită contra furtului.
- Cutii aleatorii plătite. Orice element aleatoriu respectă regulile Roblox de afișare a șanselor.
- Presiune de timp pe Robux („cumpără în 5 minute”).

Un jucător care nu plătește poate juca orice mod de bază.

## 14. Siguranță și confidențialitate

- Nu colectăm date personale: fără școli, nume reale, vârste sau locații.
- Clasamentele afișează doar display name-uri Roblox filtrate.
- Joc complet fără chat: pinguri, emote-uri, mesaje rapide predefinite.
- Fără text generat live de AI în joc.
- Playtest-uri cu copii doar cu acordul părinților; respectăm principiile GDPR și Legea 195/2024 a Moldovei.

## 15. Direcție artistică: „Satul brodat”

- O diorama de jucărie, pictată de mână, a unui sat moldovenesc. **Broderia tradițională** (cusăturile roșu cu negru de pe ii și covoare) e limbajul grafic al întregului joc.
- **Ziua:** lumină caldă de apus (galben de floarea-soarelui, roșu de cărămidă, mov de strugure, albastru de cer). **Noaptea:** indigo profund, ferestre calde, tensiune, dar tot primitor.
- **Broderia ca efect și interfață:** urma papucului e o linie de cusătură roșie, mutațiile sclipesc în model cusut, ramele și butoanele sunt brodate.
- **Siluetă pe primul loc:** fiecare creatură și Bunica se recunosc ca formă neagră pe un ecran de telefon.
- **Juice peste tot:** squash and stretch, hit-stop, screen shake, confetti, sunet pe fiecare acțiune.
- **Performanța bate poligoanele:** testăm pe un Android ieftin. Folosim niveluri de calitate, streaming și puține materiale.

**Strategia pentru un singur om:** lumea și creaturile se construiesc întâi **procedural, din cod** (forme simple, culori, accesorii din config). Fiecare creatură are în config un câmp opțional `modelId`. Când apare modelul final, îl punem acolo și nu se schimbă nicio linie de cod. Modelele hero (Bunica, creaturile, papucul) se fac în Blender sau cu unelte AI și trec printr-o verificare de stil.

**Cele cinci momente „wow”:** lovitura de papuc, căderea nopții, apariția unei mutații, grindina, drop-ul legendar.

## 16. Backlog de conținut

Intră pe același sistem de evenimente, când loop-ul principal e solid:

- **Crew-uri:** raiduri și apărare în echipă, cu cod de crew.
- **Raion League:** clasament săptămânal pe raioane și orașe, opțional (Chișinău, Bălți, Cahul, Diaspora…), plus echivalentul pe țări pentru BR și LATAM.
- **Ciocnitul ouălor:** duel 1v1 cu clasament, modul principal la Paște.
- **Mărțișor:** săptămâna darurilor (1 martie).
- **Hramul:** boss în co-op, Regele Norului de Grindină.
- **Hora Battle:** mod scurt de ritm.
- **Roluri pentru creaturi:** momeală, gardian (încetinește hoții).
- **Renaștere (rebirth):** progres pe termen lung.
- **Mașina Bunicii:** al doilea personaj.
- **Poarta încuiată:** blocare temporară a porții, dacă apărarea în lipsa proprietarului se dovedește prea slabă.
- **Calendar sezonier:** Revelion, Halloween, Sezonul grindinii, Culesul.

## 17. Când spunem „gata de lansare”

Decidem noi, pe baza a ce fac jucătorii în playtest, nu pe ce spun. Instrumentăm din prima zi:

- funnel-ul din primele 10 minute (unde pleacă oamenii);
- retenția D1, D7, D30;
- durata sesiunii;
- câte raiduri și câte lovituri de papuc are un jucător pe noapte;
- conversia la prima achiziție și venitul mediu pe jucător.

Semnalul calitativ: copiii cer singuri „încă o noapte” și își cheamă prietenii fără să fie rugați.

## 18. Decizii deschise

- Titlul final al jocului (de testat A/B; fără „Moldova” în titlu).
- Durata finală a zilei și a nopții (din playtest).
- Echilibrul dintre puterea Bunicii NPC și papucul proprietarului.
- Mărimea serverului (8 sau 6 ogrăzi), după performanța pe mobil.

## 19. Ungheni ca decor (propunere, de confirmat)

Pe baza brief-ului despre Ungheni (2026-10-12). Deciziile de faze, costuri și echipă din acel brief nu se aplică: proiectul e construit de un singur om, la scară mare, de la început.

- **Câmpul de joc rămâne compact:** strada cu cele 8 ogrăzi. Genul cere distanțe de câteva secunde între ogrăzi.
- **Strada e „o stradă din Ungheni”, lângă Prut.** Reperele stilizate se văd la capete și la orizont: gara, podul peste Prut (popular numit „podul Eiffel”; atribuirea nu e confirmată), râul, siluete de blocuri.
- **Nu reconstituim case private reale**, ca un copil să nu-și poată recunoaște casa sau pe a altcuiva. Doar repere publice.
- **OpenStreetMap (ODbL, cu atribuirea „© OpenStreetMap contributors”)** e folosit pentru forma străzilor și a reperelor. Un script le convertește în JSON, iar jocul generează casele stilizate din cod. Fără Google 3D Tiles.
- **Primul eveniment special:** gara cu schimbarea ecartamentului (1520 mm ↔ 1435 mm). Trenul trece prin sat, i se schimbă roțile, vine un negustor cu semințe rare, iar linia ferată taie traseele hoților.
- Faptele despre Ungheni (populație, pod, repere) se verifică înainte de orice material public.
