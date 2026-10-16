# Creaturile BUNICA — brief-uri de design

Universul: mâncăruri și obiecte de la țară din Moldova care au prins viață și au câte o „meserie” comică.
Copilul trebuie să le recunoască după **siluetă** de la 20 de studs și să râdă la a doua privire.

## Reguli comune (toate creaturile)

- **Stil:** forme rotunde, moi, „de jucărie”; culori plate și saturate; contur maro-închis (automat, din kit).
- **Față:** ochi mari cu strălucire (`kit.eyes`), privirea spre jucător; gura e un `tube`. Expresia spune
  meseria: agentul e șmecher, boxerul e încruntat, balerina e visătoare.
- **Fața spre -Y** în Blender (devine „înainte” în Roblox). Baza la Z = 0, fără bucăți sub sol.
- **Picioare sau talpă stabilă:** creatura stă pe piedestal.
- **Un singur obiect-semn** citibil de departe (ochelarii agentului, mănușile boxerului, căștile DJ-ului).
- **Înălțime pe raritate:** Common 4 · Rare 4.5 · Epic 5 · Legendary 5.5 · Mythic 6 · Secret 6.5 (studs).
- **Buget:** ~2.600 de triunghiuri la model plus 1.600 la contur (implicitele din `kit.main`). Sloturile
  sunt puține și cu sens (`body`, `accent`, `dark`, `white`, `pupil`, ...), pentru că mutațiile le recolorează.
- **Sloturi rezervate:** `white` și `pupil` sunt ochii (nu se recolorează la mutații); `ink` e conturul,
  generat automat.
- **Interzis:** degete ridicate, gesturi sau forme care pot fi citite urât, arme reale (cuțite, pistoale),
  simboluri politice sau religioase. Jocul e pentru copii.
- **Verificare:** după fiecare randare, privește PNG-ul (și dintr-un unghi lateral, cu `yaw=70`) și corectează:
  piese care plutesc, intersecții urâte, fețe ascunse, contur întrerupt.

## Fișele

| Id | Nume (RO / EN) | Raritate | Concept |
|---|---|---|---|
| CartofelAgent | Cartofel Agent / Agent Potato | Common | ✅ făcut: cartof spion, ochelari negri, cravată roșie, zâmbet strâmb, salută |
| ArdeiasIute | Ardeiaș Iute / Speedy Pepper | Common | ardei iute roșu alungit, aplecat înainte ca un sprinter, codiță verde ca o creastă în vânt, sprâncene încruntate de viteză, panglică albă pe frunte, adidași |
| CovrigSkater | Covrig Skater / Pretzel Skater | Common | covrig rumen cu semințe (sare albă), șapcă întoarsă, pe un skateboard albastru (puntea + 4 roți), ochi relaxați, limba scoasă într-o parte |
| GogoasaNinja | Gogoașă Ninja / Donut Ninja | Rare | gogoașă rotundă cu glazură roz și ornamente colorate, bandană neagră de ninja peste ochi cu fundă în spate, ochi îngustați concentrați, poziție de luptă (fără arme) |
| CeapaTurbo | Ceapa Turbo / Turbo Onion | Rare | ceapă mov cu foi verzi răsucite ca o elice deasupra, ochelari de aviator ridicați pe frunte, ochi lăcrimând (ceapă!), obraji umflați de efort |
| StrugurelFurios | Strugurel Furios / Furious Grapes | Rare | ciorchine de boabe mov (blob din multe sfere), față furioasă pe boaba mare din centru, vrej spiralat și o frunză de viță pe cap ca pălărie, pumnișori strânși |
| PepeneBoxer | Pepene Boxer / Boxer Melon | Epic | pepene verde dungat, mănuși de box roșii mari, centură cu catarama aurie, ochi încruntați, dinte lipsă în zâmbet, stă ca boxerii |
| SarmalinaBallerina | Sărmălina Balerina / Sarmalina Ballerina | Epic | sarma (rulou de frunză de varză, verde-pal cu vinișoare) stând în vârfuri, fustă tutu roz, brațe ridicate în arc, ochi închiși visători, gene lungi |
| Mamaligator | Mămăligator / Polentagator | Epic | aligator cu corpul de mămăligă galbenă (formă de bulz/coală pe un fund de lemn ca un fund de tocătoare), solzi ca boabe, gură mare zâmbitoare cu dinți rotunjiți (prietenoși), cu o furculiță uriașă de lemn sprijinită pe umăr |
| BranzoiSumo | Brânzoi Sumo / Sumo Cheese | Legendary | bucată masivă de brânză de burduf albă-gălbuie cu găuri, mawashi (centură de sumo) roșu-auriu, coc de sumo, stă în poziție de sumo, ochi mici și hotărâți, obraji mari |
| PlacintonioBombardino | Plăcintonio Bombardino / Placintonio Bombardino | Legendary | plăcintă rotundă aurie împletită cu marginea răsucită, aripioare de avion de jucărie și o elice în față, cască de pilot din piele cu ochelari, eșarfă albă fluturând, zâmbet larg |
| ColtunasPirat | Colțunaș Pirat / Dumpling Pirate | Legendary | colțunaș (semilună cu marginea ciupită) cu pălărie de pirat neagră (fără craniu: o cireașă roșie pe pălărie), petic pe un ochi, cârlig de bucătărie (polonic) în loc de mână, mustață răsucită |
| CozonacRobot | Cozonac Robot / Sweetbread Robot | Mythic | cozonac împletit (pâine) cu vârtej de nucă/cacao în secțiune, corp de robot: antenă cu bec, șuruburi aurii, ochi-ecrane albastre, brațe din tuburi argintii articulate, picioare de cutie |
| DovleacDJ | Dovleac DJ / DJ Pumpkin | Mythic | dovleac portocaliu mare, căști imense negre cu inel neon, ochelari de soare tip vizor, mâini pe un pupitru mic de DJ cu două discuri, codiță ca un mic moț de rocker |
| Papucel | Păpucel / Little Slipper | Legendary (exclusiv) | papucul Bunicii cu viață proprie: talpă maro groasă, baretă roșie de pâslă cu un pompon, ochi pe baretă, zâmbet poznaș; e semnătura jocului, trebuie să fie ICONIC |
| Martisorel | Mărțișorel / Martisorel | Legendary (exclusiv) | mărțișor viu: o floare albă (ghiocel) și un fir răsucit alb-roșu care formează corpul spiralat, fundiță, ochi blânzi, obraji roz |
| RetetaSecreta | Rețeta Secretă / The Secret Recipe | Secret | caiet vechi de rețete al Bunicii, cu coperta de pânză cusută (motiv de ie roșu), pagini îngălbenite care ies, o lingură de lemn ca braț, ochelarii Bunicii pe „nas”, aură misterioasă |

Accesoriile mutației „Papucită” (un papuc mic lipit pe cap) se fac separat, ca `prop.PapucMic`.
