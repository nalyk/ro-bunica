# Platforma Roblox: chestionarul de maturitate și Experience Events

Pregătit pe 2026-10-18 (sarcina 36 din planul „Satul viu”). Trimiterea formularelor în Creator Dashboard și publicarea evenimentelor schimbă ce vede publicul, deci le face sau le aprobă omul.

## Chestionarul de maturitate (Creator Dashboard → experiența → Audience → Maturity & Compliance)

Răspunsurile, după conținutul real al jocului:

| Categorie | Răspuns | De ce |
|---|---|---|
| Violență | **Mild** (violență ușoară, nerealistă) | papucul aruncat după hoți, lupii și Muma Pădurii doborâți comic; nimeni nu e rănit, nu există arme reale |
| Sânge | Nu | — |
| Groază / teamă | Nu (cel mult „mild”) | Muma Pădurii și lupii sunt caricaturi; ceața e doar vizibilitate redusă |
| Umor grosolan | Nu | — |
| Teme romantice | Nu (cel mult „mild”) | nunta din sat e un cortegiu cu horă, fără gesturi romantice |
| Alcool, droguri, tutun | Nu | strugurii se zdrobesc „pentru must”; nu apare vin |
| Jocuri de noroc | Nu | ouăle și răsadurile au rezultate aleatoare, dar nu se cumpără cu bani reali pe noroc; nu există cutii cu pradă plătite |
| Limbaj | Nu | textele sunt scrise de mână; chatul trece prin filtrul Roblox |
| Interacțiune socială liberă | Da: chat text (filtrat), mesaje rapide predefinite, schimburi și bazar | |
| Conținut creat de utilizatori | Nu | numele hibrizilor sunt generate din silabe fixe |
| Cumpărături | Da: Developer Products și Game Passes (lei, permisul 2× lei), fără pradă aleatoare plătită | |

Rezultatul așteptat: eticheta **Mild** (9+). Pentru publicul sub 16 ani, Roblox mai cere 250 de jucători activi sau taxa rambursabilă de 1.000 Robux (vezi PROGRESS; nu plătim fără acordul omului).

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

Datele vin din `Domain/Seasons` (aceleași ferestre ca în joc). Imaginile evenimentelor: compoziții din `tools/store_art.py`.

## Ce ține de om

- Verificarea identității, 2FA și abonamentul (dacă e cerut pentru evenimente sau pentru publicul sub 16 ani) se fac din contul omului.
- Trimiterea chestionarului și publicarea fiecărui eveniment: le pot completa în browser, dar butonul final îl apasă omul sau îl aprob explicit cu el.
