# Satul BUNICA — brief-uri pentru obiectele lumii

Satul e moldovenesc, cald, de poveste, nu realist. Același stil ca la creaturi: forme rotunjite, culori plate,
contur maro-închis (subțire: la obiectele mari, `kit.outline(thickness=0.08)`). Unitatea e studul.

**Integrarea:** `WorldBuilder` păstrează piesele actuale ca **coliziuni invizibile**; modelul se așază peste ele
și e doar vizual (fără coliziuni). Deci dimensiunile de mai jos sunt obligatorii: modelul trebuie să
acopere coliziunea și să nu iasă mult în afara ei. Fața modelului (-Y în Blender) privește spre drum.
Pivotul e la mijlocul bazei.

Paleta satului (tokeni comuni cu UI-ul): perete var `#F7F1E1`, albastru de sat `#3F7FD0` (rame, porți, stâlpi),
lemn `#9A6438`, lemn închis `#6B4226`, țiglă `#C2452F`, stuf `#C9A75A`, roșu de ie `#D7263D`,
piatră `#A9A39A`, verde frunză `#4BAE4F`, verde închis `#2F7A3A`, pământ `#6B4A30`.

| Cheie | Dimensiuni (L × A × H) | Descriere |
|---|---|---|
| world.Casa | 28 × 18 × 19 | Casă moldovenească: pereți de var, soclu albastru jos, acoperiș în patru ape cu țiglă roșie și streașină lată, **prisă** pe toată fața (podea de lemn la 1 stud înălțime, 5 adâncime) cu **stâlpi de lemn sculptați** (6) și arcade albastre între ei, două ferestre cu rame și obloane albastre, ușă de lemn în mijloc, brâu brodat roșu sub streașină, coș de fum. Coliziunea actuală: zidurile 26 × 12 × 12 (centrul la 6 deasupra solului, retras 4,5 față de mijlocul casei spre spate) și prispa 26 × 5. |
| world.Gard | 10 × 0,8 × 4 | Segment de gard de nuiele: 6 pari verticali rotunjiți la vârf și nuiele împletite orizontal (ondulate, sus-jos alternativ). Se repetă de-a lungul marginilor. |
| world.Poarta | 14 × 1,5 × 8 | Poartă moldovenească deschisă: doi stâlpi groși albaștri cu ornamente sculptate (romburi), un acoperiș mic de țiglă peste ei (streașină), lățimea liberă 12. Fără canaturi (trecerea rămâne liberă). |
| world.Fantana | 8 × 8 × 15 | Fântână cu **cumpănă**: ghizd rotund de piatră (diametru 5, înalt 3), cu ramă de lemn; lângă el un stâlp înalt bifurcat (12), pe el o prăjină lungă înclinată (16) cu o greutate (piatră legată) la un capăt și o găleată pe lanț la celălalt, deasupra ghizdului. Centrul ghizdului = pivotul. |
| world.Pedestal | 5 × 5 × 0,6 | Piedestal jos pentru o creatură: o felie de buștean (inele de lemn pe față, scoarță pe margine), cu un ștergar brodat (alb cu roșu) petrecut pe margine. Jucătorii pășesc peste el, deci fără margini ascuțite. |
| world.Strat | 5 × 5 × 0,8 | Strat de grădină: ramă de scândurițe, pământ afânat cu brazde (sus), câteva fire de iarbă la colțuri. |
| world.Beci | 6 × 5 × 1,4 | Ușa beciului: două canaturi de lemn înclinate cu feronerie neagră, într-o ramă de piatră. |
| world.Nuc | 14 × 14 × 18 | Nuc bătrân: trunchi gros și noduros, coroană bogată din sfere de frunze (2-3 nuanțe de verde), câteva nuci. |
| world.Visin | 9 × 9 × 11 | Vișin: trunchi zvelt, coroană rotundă, vișine roșii în ciorchini. |
| world.FloareaSoarelui | 3 × 3 × 6 | Mănunchi de 3 floarea-soarelui de înălțimi diferite, capete mari galbene cu centru maro, frunze late. |
| world.Raft | 4 × 3 × 0,6 | Raftul de laudă de pe gard: scândură cu ștergar brodat. |
| world.Tabla | 14 × 0,5 × 2,5 | Tăblița cu numele proprietarului: scândură albă cu chenar albastru și colțuri rotunjite (textul îl pune jocul). |
