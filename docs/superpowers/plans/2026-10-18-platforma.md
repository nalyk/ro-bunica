# Platforma Roblox la maximum: planul (2026-10-18)

Sursa: `docs/RESEARCH_PLATFORMA.md`. Omul: „da, pornește cu tot, deblochez și pasul 7”. În afara planului rămân LLM-ul (linia roșie) și Server Authority (nerecomandat).

Verificarea fiecărui lot: `./tools.sh` (teste Lune pentru tot ce e în `Domain`), `python3 tools/cloud.py e2e` pentru servicii, `tools/playtest.sh` pentru client, apoi commit, push și publicare. API-urile care nu merg în Studio sau în Open Cloud (notificări, share links, capture, RSVP, Configs) se izolează în `pcall` și se testează prin logica lor pură; în joc li se verifică doar degradarea curată.

## Lotul 1: creșterea (grupul A)

1. **`Domain/Launch`**: codifică și decodifică LaunchData (≤ 200 de octeți, JSON scurt `{k="yard", h=<gazda>, r=<cine a recomandat>}`), cu validare strictă. Teste.
2. **`Social/Presence`**: unde e fiecare jucător (MemoryStore hash map: userId → jobId, TTL 120 s, reîmprospătat la 60 s).
3. **`LaunchService`**: la intrare citește `GetJoinData().LaunchData`. Dacă gazda e pe alt server, teleportează jucătorul la ea (`TeleportOptions.ServerInstanceId`), cu cel mult o încercare. Dacă e pe același server, cei doi se leagă în familie (preferință de familie, valabilă pe sesiune). Recomandarea (`r`) se înregistrează o singură dată pe profil (`referredBy`); recompensa cosmetică pentru amândoi vine după 10 minute de joc ale celui nou.
4. **Party → familie**: `FamilyService` leagă și jucătorii cu același `PartyId`, nu doar prietenii.
5. **Invitații și link-uri**: în panoul de prieteni, „Invită” (`PromptGameInvite` cu `ExperienceInviteOptions.LaunchData`) și „Trimite link-ul ogrăzii” (`PromptLinkSharingAsync` pe server).
6. **RSVP**: un card cu următorul eveniment Roblox (`GetUpcomingExperienceEventsAsync`) și butonul „Vin și eu” (`PromptRsvpToEventAsync`).
7. **Clipul papucului**: reluarea celei mai bune aruncări se filmează (`CaptureService:StartVideoCaptureAsync`). Apoi „Trimite clipul” (`PromptShareCapture` cu LaunchData spre ograda ta).
8. **Notificări**: cererea de opt-in apare după prima apărare reușită, o singură dată (`ExperienceNotificationService`). Notificările programate stau într-un sorted map MemoryStore (`due → {user, șir, parametri}`); orice server pornit le trimite la scadență prin Open Cloud `UserNotification`. Tipuri: „creaturile tale au crescut” (la plecare, după timpul de creștere), „bazarul de duminică s-a deschis”, „sâmbăta în sat începe”. Maximum 1 pe zi, cum impune Roblox. Șirurile se creează în Dashboard.
9. **Thumbnail-uri**: încă 2 imagini (`tools/store_art.py`), urcate cu personalizarea pornită.

## Lotul 2: grafica PBR (grupul C)

1. `post3d`: hărțile normale și roughness se coc din plasa TRELLIS de 40k pe plasa redusă, exportate în glTF (`normalTexture`, `metallicRoughnessTexture`). Se verifică pe un model că Roblox creează SurfaceAppearance cu `NormalMap` (interogare în playtest).
2. Reconstruirea și reîncărcarea modelelor (casa, clădirile, copacii; coroanele procedurale primesc normal-ul atlasului).
3. `MaterialVariant` pentru iarbă, pământ și noroi (texturi seamless din concept Codex, urcate ca imagini), aplicate prin `MaterialService:SetBaseMaterialOverride`.
4. `GlobalWind` după vreme, `Clouds` cu acoperire după vreme și fază.
5. Emissive și SLIM: se testează în Studio; intră doar dacă proprietățile există în motorul curent.

## Lotul 3: live ops (grupul B, pasul 7)

1. **`Domain/Tuning`**: lista valorilor reglabile (cale, tip, min, max) și aplicarea validată a unei suprascrieri peste `Config`. Teste.
2. **`TuningService`**: `ConfigService:GetConfigAsync()` la pornire și la `UpdateAvailable`; valorile valide se aplică în loc, cele invalide se ignoră și se raportează. Experiments merg prin aceleași Configs.
3. **Analytics**: câmpuri custom (platformă, limbă, mărimea familiei) și funnel-uri noi (familie, schimb, mini-joc).
4. **Clasamente globale**: `OrderedDataStore` săptămânal (apărători, prinderi, hora), scrise la plecare și la 5 minute, afișate pe un panou în centru și în joc.
5. **Anunțuri între servere**: `MessagingService` „sat”: prinderile rare (Secret), plus comenzi de admin publicate din `tools/cloud.py announce` (Open Cloud messaging).
6. **Moderare**: `tools/cloud.py ban` (Open Cloud user restrictions).

## Lotul 4: senzația (grupul D)

1. `UnreliableRemoteEvent` pentru fluxurile cosmetice (papucul în zbor, poziția creaturii purtate).
2. `GuiService.PreferredTextSize` → mărirea textului în UI.
3. IK pentru Bunica (privirea spre cel mai apropiat jucător), dacă rig-ul o permite.
4. Input Action System pentru acțiunile principale (aruncarea papucului, interacțiunea), cu remapare.

## Lotul 5: monetizarea (grupul E)

1. Managed Pricing pornit din Dashboard (prețurile se citesc deja prin `GetProductInfo`).
2. Abonamentul „Prietenii Bunicii” (cosmetice lunare, fără putere): creat în Dashboard, verificat cu `GetUserSubscriptionStatusAsync`.
3. Reclame cu recompensă opționale (`AdService`), cu bonusul zilnic de lei, doar dacă jocul e eligibil (`GetAdAvailabilityNowAsync`).

## Progres

- **Lotul 1 (creștere):**
  - `Domain/Launch`, `Domain/Referral`, `Social/Presence`, `LaunchService`: link-ul ogrăzii (PromptLinkSharingAsync), invitația cu LaunchData și mesaj propriu, mutarea pe serverul gazdei, familia pe sesiune, recomandările cu titlurile „Gazda satului” și „Musafirul”.
  - Party → familie (FamilyService).
  - RSVP la evenimente, în panoul de prieteni.
  - Clipul reluării (CaptureService, doar în afara Studio).
  - Notificările: `Domain/NotifyPlan`, `NotificationService` (sorted map MemoryStore + Open Cloud), cererea de acord (dimineața de după prima lovitură). Șirurile sunt create în Dashboard.
  - Cheia Open Cloud e în Secrets („notifications”, pusă de om pe 2026-10-18). Verificat cu `cloud.py run` pe versiunea 152: secretul se citește, iar cererea e autentificată (400 „not opted in” pentru contul creatorului, adică formatul e bun).
- **Lotul 2 (grafică PBR):**
  - `post3d` coace harta normală din plasa de 40k. Roblox importă singur toate cele 4 hărți (culoare, normală, rugozitate, metal; verificat pe moară cu `cloud.py run`). 85 de modele reconstruite și urcate.
  - Terenul: `tools/terrain_tex.py` (Codex → seamless → normală) → MaterialVariant „SatIarba/SatPamant/SatNoroi” în `default.project.json`, aplicate cu `SetBaseMaterialOverride`.
  - Nori dinamici și vânt după vreme (LightingDirector).
  - Emissive și SLIM: neîncepute (proprietățile nu sunt confirmate în motorul curent).
- **Lotul 3 (live ops):**
  - `Domain/Tuning` + `TuningService` + `TuningClient`: 12 valori, server și jucător; papucul pe jucător pentru A/B. Config-urile reglabile nu mai sunt înghețate. Reîncărcarea are un minim de 0,6 s.
  - Analytics: 3 câmpuri custom, funnel-ul „Social”.
  - `LeaderboardService`: topul săptămânal din toate satele, pe al doilea avizier.
  - `BroadcastService` + `Social/Broadcast`: anunțurile rare pe toate serverele, comenzi de admin.
  - `cloud.py announce|live|ban|unban`.
- **Lotul 4 (senzație):**
  - Mărimea textului după `PreferredTextSize`.
  - Bunica urmărește cu privirea jucătorul apropiat.
  - Ruling: `UnreliableRemoteEvent` nu are unde intra (nu există fluxuri continue cosmetice; proiectilul și lovitura sunt unice și nu au voie să se piardă).
  - Ruling: Input Action System amânat. Câștigul pentru jucători e mic, iar o regresie pe atingere ar costa mult. Devine necesar doar cu Server Authority, pe care nu-l folosim.
- **Lotul 5 (monetizare):**
  - Abonamentul „Grandma's Friends” (99 Robux pe lună, EXP-4024965016297013811, în review), cu beneficii doar cosmetice: coronița de aur a Bunicii și titlul „Prietenul Bunicii”.
  - Managed Pricing (omul a aprobat, 2026-10-18): pornit pe cele 5 permise. Produsele (lei, îngrășământ, vreme, reînnoire) au rămas pe preț fix: Roblox avertizează că schimburile permit arbitrajul între regiuni, iar la noi leii și creaturile se schimbă. Ar cere Price Levels API și verificări în schimburi.
  - Reclamele cu recompensă: neeligibil încă (2.000 de vizitatori unici pe lună).
- **Lecții:**
  - Fereastra Roblox de acord pentru notificări acoperă jocul. În playtest a blocat mersul scriptat și a făcut să pice 3 pași.
  - Filmarea CaptureService încetinește Studio sub Vinegar. Ambele sunt oprite în Studio.
