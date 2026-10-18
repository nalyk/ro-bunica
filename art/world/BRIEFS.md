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
| world.Moara | 10 × 10 × 22 | Moldovan wooden windmill: square tapering timber tower on a low stone base, small pitched shingle roof cap, four big lattice sails (cross shape, sails thick enough to read, not wire-thin) facing the viewer, a small wooden door and ladder steps at the bottom. Warm wood #9A6438 / #6B4226. |
| world.Biserica | 16 × 10 × 24 | Small rustic wooden village chapel (Moldovan wooden church style): log walls, steep dark shingle roof with a wide eave all around, one slim bell tower with a pointed shingle spire at the front, small arched door and two small windows. NO cross, no icons, no religious symbols anywhere — the shingle spire alone is the landmark. |
| world.Magazin | 16 × 10 × 12 | Small village general store: whitewashed one-storey building with a flat-ish red tile roof, big shop window with stacked colorful jars and bread loaves visible inside, a blue wooden door, a striped awning over the window, an empty blank blue signboard above the door (no letters at all), two wooden crates by the entrance. |
| world.Statie | 10 × 5 × 8 | Soviet-era village bus stop shelter: concrete back wall and side walls with a flat overhanging concrete roof, the back wall covered in a bright abstract colorful mosaic (circles, waves, sun shapes in blue, red, yellow, green tiles — no faces, no text, no emblems), a wooden bench inside. Cute rounded edges. |
| world.CasaCultura | 22 × 14 × 15 | Small village House of Culture: pastel yellow plastered building, a classical portico of four chunky white columns with a triangular pediment (plain, no emblems, no stars), three wide steps, tall arched windows, a big double wooden door. Charming and slightly squat, not grand. |
| world.Gara | 24 × 12 × 13 | Tiny rural railway station: one-storey building with pale green plaster and white trim, a red tile roof whose long eave extends over a raised stone platform on wooden brackets, a wall clock without numbers, a bench and a lamp post on the platform, blank signboard (no letters). No rails in the image. |
| world.Taraba | 6 × 4 × 7 | Bazaar market stall: wooden table counter with crates of apples, tomatoes and watermelons, four wooden posts holding a red-and-white striped fabric canopy with a scalloped edge, a small wooden stool beside it. No price tags, no text. |
| world.Cuptor | 6 × 5 × 5 | Outdoor summer clay oven in a yard: dome-shaped bread oven of smooth warm ochre clay on a low whitewashed brick base, a round arched opening with a small wooden door leaning beside it, a short chimney nub, a few logs stacked at the side. |
| world.Stana | 18 × 14 × 9 | Shepherd's sheepfold: a small hut with wattle-and-daub walls and a thick thatched roof, beside it a round pen of woven wattle fence with a simple gate, a wooden water trough inside the pen. No animals, no people. |
| world.Claie | 5 × 5 × 8 | Haystack: a big rounded conical stack of golden hay built around a tall wooden pole that pokes out of the top, loose straw tufts at the base. Soft, cozy shape. |
| world.Patul | 6 × 4 × 7 | Moldovan corn crib (pătul): narrow tall slatted wooden crib on four short stone legs, gaps between the vertical slats showing piles of yellow corn cobs inside, a small pitched shingle roof. |
| world.Sperietoare | 4 × 2 × 8 | Friendly scarecrow: mounted on one wooden garden pole, arms stretched slightly down inside the sleeves, wearing a patched blue shirt and a straw hat, burlap sack head with a big stitched smile and button eyes, straw sticking out of the sleeves, standing in a small mound of soil. Cute, not scary. |
| world.Roaba | 5 × 2,5 × 2 | Old wooden wheelbarrow: plank tub with iron corner bands, one chunky wooden spoked wheel at the front, two long handles and two short legs at the back. Empty. |
| world.Puntea | 3 × 12 × 1,5 | Narrow wooden footbridge over a brook: a slightly arched walkway of planks with a simple rail of rough poles on one side, resting on log piles at each end. Only the bridge, no water. |
| world.Pod | 10 × 16 × 3 | Wooden road bridge: wide flat deck of thick planks on log beams, sturdy low wooden railings on both sides with diagonal braces, stone abutments at both ends. Only the bridge, no water, no road. |
| world.Cires | 10 × 10 × 12 | Cherry tree: sturdy short trunk with smooth reddish-brown bark, a rounded fluffy crown of fresh green leaf clusters dotted with many bright red cherry pairs. |
| world.ButucVie | 3 × 2 × 5 | Grapevine stock: a gnarled twisted old vine trunk tied to a wooden stake, green vine leaves and several plump purple and pale green grape bunches hanging from it. |
| world.Stiulete | 2,5 × 1 × 1 | Single ear of corn as a small pickup item, LYING ON ITS SIDE horizontally (diagonal in the picture), short and chunky (length about 2.5 times its width), glossy rounded kernels in neat rows, husk leaves peeled back and fanned out wide at one end like a bow. Bright golden yellow (a red variant can be tinted later). Must not read as any rude shape: never upright. |
