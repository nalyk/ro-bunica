# Platforma Roblox: chestionarul de maturitate și Experience Events

Pregătit pe 2026-10-18 (sarcina 36 din planul „Satul viu”). Trimiterea formularelor în Creator Dashboard și publicarea evenimentelor schimbă ce vede publicul, deci le face sau le aprobă omul.

## Chestionarul de maturitate (Creator Dashboard → experiența → Publish settings → Content rating)

Completat pe 2026-10-18, după conținutul real al jocului. Previzualizarea dă eticheta **Mild**, fără regiuni neconforme.

| Întrebare | Răspuns | De ce |
|---|---|---|
| Violență | Da: **Mild**, **Repeated** | papucul aruncat după hoți (la fiecare furt), lupii și Muma Pădurii doborâți comic; nimeni nu e rănit |
| Sânge | Nu | — |
| Frică | Da: **Mild**, **Occasional** | Muma Pădurii, lupii și ceața nopții, doar în întâmplări |
| Umor grosolan, jocuri de noroc fără miză, limbaj | Nu | — |
| Teme romantice | **Nu** | nunta din sat e un cortegiu cu horă, fără gesturi de afecțiune. Atenție: „Yes” aici dă eticheta **Restricted (18+)** |
| Alcool, socializare ca temă principală, desen liber, teme sensibile, conținut din alte experiențe, AI generativ | Nu | strugurii se zdrobesc pentru must; jocul nu are AI la care să răspundă jucătorul |
| Lucruri aleatorii plătite | **Da**, respectă `ArePaidRandomItemsRestricted` | lei cumpărați (semințele cresc cu mărimi și mutații aleatorii), magazinul reînnoit (stoc aleatoriu), vremea cumpărată (mutații) |
| Schimb de lucruri plătite | **Da**, respectă `IsPaidItemTradingAllowed` | schimburile și bazarul mută creaturi cumpărate cu lei |
| Partajare media, flux continuu sau redare automată | Nu | — |

Politicile sunt respectate în cod (`Domain/Policy`, `RegionPolicyService`). Unde `ArePaidRandomItemsRestricted`, magazinul nu arată pachetele de lei, reînnoirea, vremea și permisul 2× lei. Unde schimbul nu e permis, schimburile și bazarul sunt închise, în ambele sensuri. Fără un răspuns de la `PolicyService`, jucătorul e tratat ca restricționat. Pentru publicul sub 16 ani, Roblox mai cere 250 de jucători activi sau taxa rambursabilă de 1.000 Robux (vezi PROGRESS; nu plătim fără acordul omului).

## Experience Events (Creator Dashboard → Engagement → Events)

| Eveniment | Când (UTC) | Titlu (EN / RO) | Descriere scurtă |
|---|---|---|---|
| Update-ul de sâmbătă | în fiecare sâmbătă, 16:00–20:00 | „Saturday in the Village” / „Sâmbăta în sat” | Seara în care tot satul e online: întâmplări la 6–8 minute, mini-jocuri pe echipe, bazarul plin. |
| Bazarul mare | duminică, toată ziua | „Big Sunday Bazaar” / „Bazarul mare de duminică” | 12 tarabe și negustori care cumpără creaturile la preț cinstit. |
| Paștele | Joia Mare – duminica de după (2027: 29 aprilie – 9 mai) | „Easter Egg Hunt” / „Ouăle de Paște” | Ouă încondeiate ascunse prin sat; ciocnitul dă ouă rare. |
| Mărțișorul | 1–14 martie | „Mărțișor Spring” / „Mărțișorul” | Straturile cresc cu 20% mai repede. |
| Drăgaica | 20–27 iunie | „Drăgaica Wreaths” / „Coronițele de Drăgaică” | Aruncă o coroniță pe acoperiș: dacă rămâne sus, primești 250 de lei. |
| Culesul | 15 septembrie – 15 octombrie | „Harvest Time” / „Culesul” | Știuletele roșu ascuns în lan, strugurii de zdrobit mai des. |
| Iarna | 15 decembrie – 14 ianuarie | „Winter Carols” / „Colindele de iarnă” | Colinde la porțile vecinilor, Capra și Ursul, masca de Malanca. |

Datele vin din `Domain/Seasons` (aceleași ferestre ca în joc). Imaginile evenimentelor: `tools/event_art.py` → `art/ui/events/` (fundalul ecranului de încărcare, personajele din concepte, titlul cu Luckiest Guy din `art/fonts`). Evenimentele se publică după refacerea graficii din sat (cerința omului, 2026-10-18).

## Ce ține de om

- Verificarea identității, 2FA și abonamentul (dacă e cerut pentru evenimente sau pentru publicul sub 16 ani) se fac din contul omului.
- Trimiterea chestionarului și publicarea fiecărui eveniment: le pot completa în browser, dar butonul final îl apasă omul sau îl aprob explicit cu el.
