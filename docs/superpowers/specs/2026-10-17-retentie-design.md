# Retenția: prieteni rivali, noapte vie, Caietul Bunicii, schimburi (design, 2026-10-17)

Scris după evaluarea sinceră a jocului din 2026-10-17. Pe scurt: primele 10 minute sunt puternice, dar jocul
nu are încă motive să revii mâine. Omul a aprobat toate cele 6 puncte („proceed”) și a cerut decizii luate
autonom, fără întrebări. Deciziile de mai jos sunt ale agentului.

## De ce

- Furtul, cârligul jocului, era deschis doar 3 minute din 9.
- Prietenii veniți împreună (canalul principal de creștere pe Roblox) nu puteau face gluma de bază unul altuia.
- Solo, noaptea însemna doar furt de la vecini NPC, fără nimic de apărat.
- După ce aveai creaturile Mitice, nu mai era nimic de urmărit: fără renaștere, colecție, misiuni sau schimburi.

## Ținte și ce evităm

Ținte:

- Fiecare sesiune are un scop mic: treburile zilei.
- Fiecare săptămână are un scop mare: colecția și renașterea.
- Solo, noaptea are tensiune.
- Prietenii aleg singuri dacă se ajută sau se fură.

Ce nu facem:

- Pay-to-win: nimic din toate astea nu se cumpără cu Robux.
- Pierderi crude: un jucător AFK nu e jefuit de boți, iar boții nu fură Legendare sau mai rare.
- Înșelătorii la schimb: confirmare dublă, valorile la vedere, numărătoare inversă, revalidare atomică pe server.

## 1. Serverul de 8 (făcut)

Place-ul avea `serverSize` 50, dar jocul are 8 ogrăzi, deci jucătorii 9–50 erau dați afară.
Setat la 8 din Creator Dashboard (Access → Maximum Visitor Count).

## 2. Familie sau Rivali

- Profilul primește câmpul `familyMode`, cu valoarea `"Family"` (implicită) sau `"Rival"`.
- **Familia e consimțământ mutual:** doi prieteni sunt legați în familie doar dacă amândoi sunt pe „Family”.
  Dacă unul alege „Rival”, se pot fura reciproc, ca între străini; ogrăzile rămân alăturate.
- Modul se schimbă **doar ziua** și cel mult o dată la 10 s. Așa nu poți trece pe Rival noaptea, fura și reveni.
- **Interfața:** un buton mic lângă eticheta familiei („Familie” / „Rivali”).
- **Descoperire:** când e pe server un prieten Roblox de-al tău, primești o notificare care explică alegerea.
- Pe server, `Family.group` primește un predicat care cere atât prietenia, cât și ambele moduri „Family”.

## 3. Ziua de 4 minute

- `daySeconds` scade de la 360 la 240; `nightSeconds` rămâne 180. Furtul e deschis 43% din timp, față de 33%.
- Creșterile lungi (Mitic, 18–20 min) rămân acoperite de câteva cicluri.
- Furtul de zi de pe straturi a fost respins: ar distruge progresul jucătorilor noi și ar fi hărțuire.

## 4. Vecinii fură și ei (noaptea vie)

- La fiecare noapte, un vecin NPC trimite un hoț (rig-ul Hoțomanul, cu numele vecinului) spre ograda unui
  jucător **activ**.
- Numărul de încercări pe noapte depinde de câți jucători reali sunt pe server (config `NpcThieves`):
  solo 3, 2–3 jucători 2, 4–5 jucători 1, 6+ niciunul. Prima încercare vine la 20–40 s după căderea nopții,
  iar între încercări sunt 35–55 s.
- **Ținta:**
  - jucătorul nu e AFK: s-a mișcat în ultimele 90 s;
  - nu e în protecția de jucător nou (20 min);
  - nu are scut;
  - nu a atins limita de 2 furturi pe noapte.
- **Creatura țintită:** cea mai valoroasă creatură expusă cu raritatea Comun, Rar sau Epic.
- **Hoțul** e un bot real (`Actors.createBot`), legat temporar ca actor al ogrăzii vecinului.
  - Folosește exact regulile de furt (`RaidService.tryStart`), deci papucul, Bunica, alarma, recompensa de
    apărare și limitele funcționează identic.
  - Merge mai încet decât un jucător și abandonează după 40 s.
  - Dacă reușește, creatura ajunge pe piedestalul vecinului, iar jucătorul o poate fura înapoi în aceeași noapte.
- La răsărit, hoții rămași pleacă și scapă ce cară.
- Botul e dezlegat de ograda vecinului înainte să fie șters, ca vecinul să nu fie înlocuit și creatura să rămână acolo.

## 5. Caietul Bunicii (colecție, treburile zilei, renaștere)

Un singur panou nou, cu trei file, deschis de un buton rotund nou din coloana din stânga.

### Colecția

- O intrare = o creatură plus o mutație: „fără mutație” și fiecare mutație din config, inclusiv Papucită.
- Se descoperă când creatura intră în posesia ta: eclozare, furt, mutație pe o creatură a ta (nu și schimbul: altfel conturile noi ar cultiva recompensele).
- Prima descoperire dă lei. Pentru creatura fără mutație, recompensa e prețul de vânzare al variantei
  Normale × 0,5; pentru o mutație, se mai înmulțește cu multiplicatorul mutației. Rezultatul are un minim de 50.
- **Praguri** la 10, 25, 50, 75 și 100 de intrări, apoi la toate: fiecare dă +5% venit permanent.
- Profilul primește `collection: { [string]: boolean }`, cu chei `"<id>"` și `"<id>:<mutation>"`.

### Treburile zilei

- Primești 3 treburi pe zi UTC, alese determinist din ziua curentă și UserId.
- Tipurile: plantezi, eclozezi, furi, aperi (lovești un hoț care cară), vinzi, dansezi hora, câștigi lei,
  prinzi o mutație.
- Toate se pot face și solo (furi de la vecini, aperi de hoții vecini).
- Recompensa unei treburi: `max(150, venitul pe secundă × 90 s)`, calculată la revendicare.
- Toate trei gata dau în plus o sămânță: Rar sau Epic, aleasă determinist.
- Profilul primește `quests: { day, list: { { kind, goal, progress, claimed } }, bonusClaimed }`.

### Renașterea („Gospodăria nouă”)

- **Cost:** 1M × 4^n lei, unde n = renașterile făcute. Maximum 10.
- **Se resetează:** leii (la cei de start), semințele, plantele și creaturile.
- **Rămân:**
  - creatura cea mai valoroasă („de suflet”), pusă înapoi pe piedestal;
  - îmbunătățirile, permisele, colecția, statisticile, darul zilnic și treburile zilei.
- **Câștigi:**
  - +50% venit permanent pe nivel (×1,5, ×2, ×2,5…);
  - o sămânță Epică;
  - steluțe pe tăblița ogrăzii („★2”).
- Profilul primește `rebirths: number`.

Multiplicatorul de venit devine: prieteni × boost (permisul 2× lei) × (1 + 0,5 × renașteri) × (1 + 0,05 × prag).
Venitul offline rămâne la baza ×1, ca până acum.

## 6. Schimburile

- Butonul „Schimb” (în Caietul Bunicii sau rotund) deschide lista jucătorilor de pe server.
  - Alegi un jucător, el primește cererea și o acceptă sau o refuză.
  - Rate limit: o cerere la 10 s.
- Fereastra de schimb: fiecare parte oferă cel mult 4 creaturi **din beci** și, opțional, lei. Sub fiecare
  ofertă se vede valoarea totală de vânzare.
- Orice schimbare de ofertă anulează acceptările. Când ambii acceptă, urmează o numărătoare de 3 s, apoi
  serverul revalidează atomic:
  - ambii au încă creaturile și leii oferiți;
  - ambii au loc în beci.
  - Abia apoi mută totul, o singură dată (un „Accept” repetat nu programează a doua execuție). Creaturile primite nu intră în colecție, ca recompensele să nu poată fi cultivate prin conturi noi.
- Schimbul se anulează dacă unul iese, se îndepărtează prea mult de fereastră (nu e cazul, e UI) sau închide
  fereastra.
- Nu se pot schimba semințe sau creaturi Secrete; acestea rămân trofee.
- Logica pură stă în `Domain/Trade`: ofertă, acceptare, validare. Serviciul e `TradeService`.

## Ordinea de construcție

Fiecare pas e verificat (tools.sh, e2e, playtest unde atinge clientul), apoi commit, push și publicare live.

1. Familie/Rivali.
2. Ziua de 4 minute.
3. Vecinii hoți.
4. Colecția.
5. Treburile zilei.
6. Renașterea, împreună cu panoul Caietul Bunicii.
7. Schimburile.

## Lăsate constructorului

Pozițiile exacte în UI, textele (RO și EN, scrise de mână), mesajele Bunicii pentru noile momente și
valorile fine din config.
