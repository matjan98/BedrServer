# BedrServer — Minecraft Bedrock Dedicated Server

Prywatny serwer BDS (Windows). Świat: `worlds/moj_swiat`. Całe repozytorium = katalog serwera;
commity gitowe pełnią rolę backupów świata i konfiguracji.

## Zainstalowane dodatki

| Dodatek | Wersja bazowa | Uwagi |
|---|---|---|
| Canopy [BP]+[RP] (ForestOfLight) | 1.5.7 | RP ma **lokalny patch** → wersja podbita do **1.5.9** (patrz niżej); BP ma **lokalnie podbitą zależność** script API (patrz niżej) |
| Understudy (ForestOfLight) | 1.2.3 | rozszerzenie Canopy; symulowani gracze `/simplayer:*`; ta sama podbita zależność |

Wymagania: świat musi mieć włączony eksperyment **Beta APIs** (flaga `gametest` w `level.dat`) —
bez niego skrypty Canopy i Understudy w ogóle się nie ładują (`./canopy …` leci jako zwykły czat,
`/simplayer:*` = „Unknown command").

### ⚠️ Zależność `@minecraft/server` unieważnia się przy KAŻDYM wydaniu Minecrafta

Mojang trzyma **tylko jedną aktywną wersję beta** każdego modułu skryptowego. Gdy `X.Y.0-beta`
awansuje do stabilnej `X.Y.0`, łańcuch `X.Y.0-beta` **przestaje istnieć** i paczka, która go żąda,
nie ładuje się wcale. Dlatego ForestOfLight wypuszcza nowe Canopy pod każdą wersję MC
(„v1.5.7 for MC 26.30", „v1.5.6 for MC 26.20" …).

Stan na 2026-08-04 (MC 26.40): wydania Canopy pod 26.40 jeszcze nie było, więc zależność jest
**podbita ręcznie** w obu manifestach BP:

```
"module_name": "@minecraft/server",  "version": "2.10.0-beta"     (autor daje 2.9.0-beta)
```

Reszta zależności została bez zmian i działa: `@minecraft/server-ui 2.2.0-beta`,
`@minecraft/debug-utilities 1.0.0-beta`, `@minecraft/server-gametest 1.0.0-beta`.
`min_engine_version` `[1, 26, 30]` to minimum, nie trzeba go ruszać.

Gdy wyjdzie oficjalne Canopy pod 26.40 — instaluj je normalnie (procedura patcha F8 niżej),
ręczne podbicie stanie się zbędne.

**Aktualizacja 2026-08-16 (MC 26.44):** bez zmian — `2.10.0-beta` przetrwało wydanie łatkowe,
manifesty zostały takie same, skrypty ładują się bez błędów. Podbijać trzeba dopiero przy
następnym **minorze** (26.50), nie przy łatkach linii 26.4x.

### ⚠️ LOKALNY PATCH nr 2: Canopy [BP] → `scripts/src/rules/infodisplay/NoFog.js`

Skutek uboczny podbicia na `2.10.0-beta`: z enuma `EntityComponentTypes` **zniknął człon `Fog`**,
a zastępujące go `FogSettings` pojawia się dopiero w `2.11.0-beta` (26.50-preview) — na 26.40 nie
ma żadnego API mgły. `getComponent(undefined)` rzucało `InvalidArgumentError` **w konstruktorze**
`NoFog`, a że `InfoDisplay` tworzy wszystkie elementy w swoim konstruktorze, to:

- `InfoDisplay.playerToInfoDisplayMap[player.id] = this` (linia 82) nigdy się nie wykonywało,
- `system.runInterval` (linia 200) próbował tworzyć InfoDisplay **od nowa co tick** → ~20 błędów/s,
- InfoDisplay nie powstawał ani razu, więc **nie było współrzędnych, a F8 nie miał czego pokazywać**.

Patch: `NoFog.resolveFogComponent()` bierze `EntityComponentTypes.Fog ?? 'minecraft:fog'`, opakowuje
`getComponent` w `try/catch`, a `removeFog`/`resetFog`/`clearFog`/`onDimensionChange` wychodzą
wcześniej, gdy komponentu nie ma. Reguła `noFog` zostaje widoczna w `./info menu`, ale na 26.40
nic nie robi — reszta InfoDisplay działa normalnie.

Wersji BP **nie podbijamy** (skrypty chodzą po stronie serwera, nie ma cache klienta — inaczej niż
przy patchu RP niżej). Ten patch **znika razem ze starą paczką**, gdy zainstalujesz Canopy pod 26.40.
Aktualne wersje modułów sprawdzisz w changelogach:
`https://github.com/MicrosoftDocs/minecraft-creator/blob/main/creator/ScriptAPI/minecraft/server/changelog.md`.

## ⚠️ LOKALNY PATCH: Canopy [RP] — InfoDisplay przełączany klawiszem F8

**Cel:** wyświetlacz danych Canopy (InfoDisplay, np. współrzędne po `./info coords true`)
ma być chowany/pokazywany jednym klawiszem.

**Mechanizm:** w `resource_packs/Canopy[RP]/ui/hud_screen.json`, w kontrolce
`hud_title_text` → `controls` → `title` → `bindings`, dodany jest binding wiążący widoczność
etykiety z widocznością paperdolla:

```json
{
    "binding_name": "#paper_doll_visible",
    "binding_name_override": "#visible",
    "binding_type": "global"
}
```

**F8** (= przełącznik „Ukryj kukłę postaci" / Hide Paperdoll) pokazuje i chowa InfoDisplay.
Ustawienia `./info …` są per-gracz i trwałe — raz włączone `coords` zostaje na zawsze,
F8 steruje tylko widocznością po stronie klienta.
Efekt uboczny: zwykłe tytuły `/title` też są widoczne tylko przy włączonym paperdollu
(na prywatnym serwerze bez znaczenia).

Wersja RP jest podbita o +2 względem oryginału (historia: 1.5.8 = filtr „!" dla Star'sa,
1.5.9 = obecny binding paperdolla), spójnie w **trzech** miejscach:

1. `resource_packs/Canopy[RP]/manifest.json` → `header.version` = `[1, 5, 9]`
2. `behavior_packs/Canopy[BP]/manifest.json` → `dependencies` (uuid `bcf34368-…`) = `[1, 5, 9]`
3. `worlds/moj_swiat/world_resource_packs.json` → wpis `bcf34368-…` = `[1, 5, 9]`

### 🔁 Procedura przy KAŻDEJ aktualizacji Canopy

Nowa wersja Canopy **nadpisze/zgubi patch** — po każdej aktualizacji trzeba go nałożyć ponownie:

1. Zainstaluj nowe Canopy [BP] + [RP] (np. 1.6.0).
2. W nowym `Canopy[RP]/ui/hud_screen.json` dodaj powyższy binding `#paper_doll_visible`
   do etykiety `title` w `hud_title_text`.
3. Podbij `header.version` RP o +1 względem wydania autora (np. 1.6.0 → 1.6.1)
   i ustaw tę samą wersję w zależności w manifeście BP oraz w
   `worlds/moj_swiat/world_resource_packs.json` (BP w `world_behavior_packs.json`
   zostaje z oficjalną wersją BP). Bez podbicia wersji klient użyje starej kopii z cache!
4. Sprawdź, czy nowy Understudy wymaga tej wersji Canopy BP (dependency w jego manifeście).
5. Kontrolowany start serwera → w logu mają być: `Experiment(s) active: gtst`, obie paczki
   w Pack Stack, `[Canopy] Registered Understudy …`, brak błędów zależności.
6. Test w grze: `./info coords true`, F8 chowa/pokazuje. Commit + push.

## Understudy — symulowani gracze (ściąga)

- Dodanie bota: `/simplayer:join <nazwa>` (bez OP). Usunięcie: `/simplayer:leave <nazwa>`
  **albo po prostu zabij bota** — śmierć automatycznie wyrejestrowuje go na stałe
  (`scripts/classes/Understudies.js`, handler `entityDie`).
- Pozostałe komendy: `/simplayer:tp | move | look | sneak | sprint | action | inventory |
  swapheld | select | stop | rejoin | claimprojectiles | prefix`.
- **Trwałość po restarcie serwera**: reguła `./canopy simplayerRejoining true` (jednorazowo, OP).
  Przy poprawnym zamknięciu serwera (`stop`/Ctrl+C) lista aktywnych botów zapisuje się w świecie;
  po restarcie boty wracają na ostatnią pozycję z ekwipunkiem — ale dopiero, gdy pierwszy
  prawdziwy gracz wejdzie na serwer (skrypty startują razem ze światem).
  Reguły `noSimplayerSaving` nie włączać (wyłączyłaby zapis pozycji/ekwipunku).
  Po twardym ubiciu procesu (crash/kill) lista może być nieaktualna.
- InfoDisplay (pozycja itp.): `./info coords true` raz, potem **F8** pokazuje/ukrywa (patrz patch wyżej);
  pełne menu przełączników: `./info menu`.
- **Normalne wpisy w logu startowym (nie naprawiać):**
  - `WARN … Custom Command alias [tp]/[stop]/[claimprojectiles] already in use` — silnik nie może
    wystawić skrótów bez prefiksu (zajęte przez vanilla/Canopy); pełne nazwy `/simplayer:*` działają.
  - `ERROR [SimplayerRejoining] Error parsing simplayersToRejoin DP` — pojawia się tylko, dopóki
    lista botów nie została ani razu zapisana przy poprawnym zamknięciu (`stop`); znika po pierwszym
    pełnym cyklu bot → stop → start. Wraca po twardym ubiciu procesu.

## Wydajność (laptop Gigabyte G6 KF: i7-13620H 6P+4E, 32 GB DDR5, NVMe)

- Pętla gry BDS = 20 ticków/s, w dużej mierze jednowątkowa; zdrowie serwera monitoruj przez
  `./info tps true` (TPS < 20 = serwer nie wyrabia).
- **Każdy gracz i każdy bot Understudy utrzymuje bańkę symulacji o promieniu `tick-distance`**
  (romb/taxicab: 2r(r+1)+1 chunków; r=4 → 41, r=6 → 85, r=12 → 313 chunków NA GRACZA).
  Rozproszone boty = osobne bańki (spawny mobów + tick chunków + skrypt per bot co tick).
  Dziesiątki rozproszonych botów wymagają `tick-distance` 4–6; boty zgrupowane współdzielą bańki.
  Uwaga: globalny cap naturalnych spawnów to ~200 mobów NA ŚWIAT — rozproszone boty
  rozcieńczają dropy farm (grupuj boty przy farmach).
- Skrypty (Canopy/Understudy, QuickJS bez JIT) wykonują się NA GŁÓWNYM WĄTKU w ticku;
  watchdog: spike >100 ms/tick = warning, pamięć skryptów >250 MB (`script-watchdog-memory-limit`)
  = **serwer sam się zapisuje i WYŁĄCZA** (limit można podnieść do 2000).
- Leaki RAM BDS są udokumentowane (BDS-14781/17567) — przy pracy 24/7 okresowy restart to higiena.
- Backup bez zatrzymywania serwera: `save hold` → `save query` → kopiowanie → `save resume`.
- `view-distance` wpływa tylko na to, co widać (client-side-chunk-generation włączone),
  `tick-distance` na to, co żyje — farmy działają tylko w tikowanych chunkach.
- `max-threads=0` = użyj wszystkich wątków CPU (generowanie terenu itp.).
- Laptop: na czas serwowania plan zasilania „Wysoka wydajność", zasilacz podpięty,
  **zamknięcie klapy ustawić na „nic nie rób"** (uśpienie = ubity serwer bez zapisu).
- Git z historią świata rośnie — pilnuj wolnego miejsca na C: (2026-07-23: 95 GB wolne).

## Historia: aktualizacja 26.40 → 26.44 (2026-08-16)

Postawienie serwera na **drugiej maszynie** (świeży `git clone`) połączone z aktualizacją BDS.

- Serwer podniesiony do **BDS 1.26.44.3** (`bedrock-server-1.26.44.3.zip`, 94 996 851 B,
  SHA256 `1C02222F32256A8B44AD27720C8E1E1D15ABF6705ADF945B62ED48E7480BEF8B`).
  Z logu: `Build ID: 49326048`, `Branch: r/26_u4`.
- **1.26.44 to wydanie łatkowe linii 26.40, nie nowy minor** — i to zmienia wszystko na plus:
  `@minecraft/server 2.10.0-beta` **nadal istnieje**, więc manifestów Canopy i Understudy
  **nie trzeba było ruszać**. Oba lokalne patche (NoFog, binding paperdolla) przetrwały
  nietknięte, bo aktualizacja BDS nie dotyka `Canopy[BP]`, `Canopy[RP]` ani `Understudy-*`.
- `server.properties`: 41 kluczy po obu stronach, **zero różnic** — nic nie doszło.
- **Sierot brak** — wszystkie paczki `vanilla_*` z repo są też w 26.44. Doszły
  `behavior_packs/vanilla_1.26.44` i `resource_packs/vanilla_1.26.44`.
- Kontrolowany start czysty: `Experiment(s) active: gtst`, obie paczki w Pack Stack,
  `[Canopy] Registered Understudy v1.2.3.`, `Quit correctly`, kod wyjścia 0.
  Świat zmigrowany do 26.44 — **stary serwer 26.40 już go nie otworzy** (patrz „Praca na
  dwóch maszynach").
- Przy okazji: launcher przepisany na ścieżki względne + synchronizację gitową (sekcja
  „Praca na dwóch maszynach"). Wcześniej `Start-Server.bat` i `start_server.ps1` miały
  `C:\BedrServer` na sztywno, przez co po sklonowaniu w inne miejsce nie startowały wcale.
- Pułapka techniczna wyłapana przy pisaniu launchera: **`git` pisze normalne komunikaty na
  stderr** (`push` praktycznie wszystko), a PowerShell 5.1 opakowuje przechwycony stderr
  natywnego programu w `ErrorRecord` — przy `$ErrorActionPreference = 'Stop'` wywalało to
  skrypt mimo kodu wyjścia 0. Helper `Invoke-Git` ustawia u siebie lokalne `'Continue'`
  i stan sprawdza **wyłącznie** przez `$LASTEXITCODE`.
- Drobiazg przy rozpakowywaniu: `Expand-Archive` do długiej ścieżki wywala się na limicie
  260 znaków i **wycofuje całą operację** (zostaje pusty katalog). Rozpakowuj do krótkiej
  ścieżki, np. `C:\Users\<user>\bds_work\`.

### ⚠️ POTWIERDZONE: `git clone` uszkadzał `worlds/*/db/CURRENT`

Nie hipoteza — zmierzone na tym klonie. Plik `db/CURRENT` po świeżym `git clone`:

```
kopia zrobiona zaraz po clone :  M A N I F E S T - 0 8 1 7 5 2  \r  \n     <-- doklejone \r
zawartosc w gicie             :  M A N I F E S T - 0 8 1 7 5 2  \n
```

`CURRENT` to kilkanaście znaków ASCII bez bajtów NUL, więc git bierze go za plik tekstowy,
a `core.autocrlf=true` (domyślne w Git for Windows, ustawione na obu maszynach) dokleja mu `\r`
przy **każdym** `clone`, `checkout` i `reset --hard`. Reszta LevelDB (`.ldb`, `MANIFEST-*`)
ma bajty NUL i git sam wykrywa je jako binarne — dlatego problem dotyczył wyłącznie tego
jednego pliku i był niewidoczny w diffie.

BDS 26.44 taki świat **otworzył bez protestu** — LevelDB toleruje nadmiarowy `\r` w `CURRENT`.
To znaczy, że błąd siedział tam po cichu, a nie że był nieszkodliwy: zależał od pobłażliwości
parsera, nie od poprawności danych.

Naprawione regułą `worlds/*/db/** binary` w `.gitattributes`. Po niej checkout oddaje bajt
w bajt to, co jest w gicie. **Jeśli klonowałeś to repo przed 2026-08-16, twój `CURRENT`
najprawdopodobniej ma `\r`** — wystarczy pobrać tę zmianę i przełożyć plik na nowo
(`git checkout -- worlds/`), albo pozwolić serwerowi nadpisać go przy najbliższym starcie.

## Historia: aktualizacja 26.32 → 26.40 (2026-08-04)

Klient zaktualizował się przez Store o 18:51 do **1.26.4005.0 (26.40)**, serwer został na
**1.26.32.2** i zaczął zrywać połączenia na handshake'u. Bedrock 26.40 wyszedł tego samego dnia.

- Serwer podniesiony do **BDS 1.26.40.8** (`bedrock-server-1.26.40.8.zip`, 94 954 789 B,
  SHA256 `7B649671E1D88F8BD1499C580910F099E27533EFC213F9FAF5A5C68DD41A77C9`).
- 26.40 wydało `@minecraft/server` **2.9.0** jako stabilne i dodało **2.10.0-beta**, przez co
  `2.9.0-beta` żądane przez Canopy 1.5.7 i Understudy 1.2.3 zniknęło. Zależność podbita ręcznie
  do `2.10.0-beta` — skrypty ładują się bez błędów, `[Canopy] Registered Understudy v1.2.3.`
- `bedrock_server.exe` przestał być śledzony przez gita/LFS (limit 1 GB).
- Paczka `behavior_packs/vanilla_1.26.32` nie występuje w zipie 26.40 — przeniesiona do kopii.
- `server.properties`: zestaw 41 kluczy identyczny jak w domyślnym 26.40, nic nie doszło.
- Przy okazji: pierwszy skrypt testowy nie umiał zatrzymać serwera (pułapka BOM opisana wyżej)
  i ubił go twardo. Świat przywrócono z kopii sprzed aktualizacji — bez strat, bo na serwerze
  nie było wtedy żadnego gracza. Stąd nowe ostrzeżenia w „Przydatnych faktach".
- Podbicie na `2.10.0-beta` odsłoniło drugi problem: `EntityComponentTypes.Fog` zniknęło z API,
  przez co konstruktor `NoFog` wywalał cały `InfoDisplay` co tick (brak współrzędnych, F8 bez
  efektu). Naprawione lokalnym patchem w `Canopy[BP]/scripts/src/rules/infodisplay/NoFog.js`
  — opis w sekcji „LOKALNY PATCH nr 2".

## Historia: Star's Debug Screen (USUNIĘTY 2026-07-23)

Paczki `Debug-Screen-B` (BP 7.1.1) i `Debug-Screen-R` (RP 7.1.0) zostały **całkowicie usunięte**
z serwera (foldery + wpisy w `world_*_packs.json`). Powody:
1. Addon przestał renderować dane na kliencie **1.26.33** (silnik UI ubił triki stringowe
   `'%.Ns' *` w jego hud_screen.json; autor nie aktualizował od 2025-12-03).
2. Konflikt kanału tytułów z InfoDisplay Canopy (oba dodatki przesyłały dane przez `setTitle`).

Odzyskanie: pełne pliki paczek są w historii gita (commit `f4b714b` i wcześniejsze).
Przy ewentualnym powrocie (po aktualizacji autora pod 26.3x+): przywróć foldery, dodaj wpisy
do world_*_packs.json, a do patcha Canopy [RP] dopisz z powrotem filtr ukrywający payloady „!":
`{"binding_type": "view", "source_property_name": "(not (('%.1s' * #hud_title_text_string) = '!'))", "target_property_name": "#visible"}`
(o ile silnik UI znów wspiera te operatory) i podbij wersję RP.

## Procedura aktualizacji BDS

Klient z Microsoft Store aktualizuje się sam i wtedy **przestaje wchodzić na stary serwer** —
objaw jest charakterystyczny: w `packet-statistics.txt` widać `RequestNetworkSettingsPacket`
na wejściu i od razu `PlayStatusPacket` + `DisconnectPacket` na wyjściu (zerwanie na pierwszym
pakiecie handshake'u = niezgodność protokołu).

**Aktualny link do pobrania bierz z oficjalnego API**, nie ze strony ani z wyszukiwarki:

```powershell
(Invoke-WebRequest 'https://net-secondary.web.minecraft-services.net/api/v1.0/download/links' -UseBasicParsing |
  ConvertFrom-Json).result.links | Where-Object downloadType -eq 'serverBedrockWindows' |
  Select-Object -ExpandProperty downloadUrl
```

Kroki:

1. **Zatrzymaj serwer** (`stop`) i zrób kopię poza repozytorium: `worlds\`, `server.properties`,
   `allowlist.json`, `permissions.json`, manifesty Canopy/Understudy, stary `bedrock_server.exe`.
   To jedyna siatka, jeśli aktualizacja pójdzie źle — **po pierwszym starcie na nowej wersji świat
   zostaje zmigrowany i powrót na starą wersję nie jest gwarantowany**.
2. Pobierz zip, sprawdź rozmiar i `Get-FileHash -Algorithm SHA256`, rozpakuj **do folderu
   roboczego**, nigdy prosto na `C:\BedrServer`.
3. Skopiuj z paczki: `bedrock_server.exe`, `bedrock_server_how_to.html`, `release-notes.txt`,
   `packetlimitconfig.json`, `profanity_filter.wlist`, `definitions\`, `data\`, `config\`,
   `behavior_packs\`, `resource_packs\` (robocopy `/E`, **nigdy `/MIR`** — skasowałby Canopy).
4. **Nie nadpisuj** `server.properties`, `allowlist.json`, `permissions.json` ani `worlds\`.
   Zamiast tego porównaj zestaw kluczy naszego `server.properties` z domyślnym z paczki i dopisz
   te, które doszły (przy 26.32 → 26.40 nie doszedł żaden).
5. Sprawdź „sieroty": paczki `vanilla_*`/`chemistry_*`, które są lokalnie, a nie ma ich w nowym
   zipie, przenieś do kopii zapasowej (przy 26.40 taką sierotą był `vanilla_1.26.32`).
6. Podbij zależność `@minecraft/server` w manifestach Canopy i Understudy, jeśli nie ma jeszcze
   wydania autora pod nową wersję MC (patrz sekcja o script API wyżej).
7. Kontrolowany start i weryfikacja logu — w logu mają być `Version: <nowa>`,
   `Experiment(s) active: gtst`, obie paczki w Pack Stack, `[Canopy] Registered Understudy …`,
   brak błędów modułów. Potem wejście klientem, `./info coords true` + F8, `/simplayer:join`.
8. Commit + push.

## Przydatne fakty administracyjne

- Wersję BDS najpewniej odczytasz z NBT `lastOpenedWithVersion` w `worlds/moj_swiat/level.dat`
  (binarka `bedrock_server.exe` nie ma VersionInfo). Drugi trop: najwyższa paczka
  `behavior_packs/vanilla_1.26.*`.
- **`bedrock_server.exe` nie jest już śledzony przez gita** (od 2026-08-04). Wcześniej szedł przez
  Git LFS, ale każda aktualizacja BDS zabierała tam na stałe ~200 MB z 1 GB darmowego limitu
  GitHuba — po kilku aktualizacjach push zacząłby się wywalać na „over data quota". Repo jest
  backupem **świata i konfiguracji**; binarkę pobierasz na nowo (link w procedurze wyżej).
- Ścieżki z `[BP]`/`[RP]` w PowerShellu wymagają `-LiteralPath` (nawiasy to wildcardy!).
- Konsola przez pipe'y wymaga drenowania stdout **i** stderr (inaczej deadlock przy włączonym
  `content-log-console-output`).
- ⚠️ **Pułapka BOM przy sterowaniu serwerem ze skryptu (.NET/PowerShell).** `Process.StandardInput`
  tworzy `StreamWriter` z `AutoFlush = true`, a setter `AutoFlush` robi natychmiastowy flush —
  preambuła UTF-8 (`EF BB BF`) leci do potoku **już przy pierwszym odczytaniu właściwości**, zanim
  cokolwiek napiszesz. Serwer widzi wtedy `Unknown command: ﻿stop` i **się nie zatrzymuje**.
  Obejście: przed startem procesu ustaw `[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)`
  albo po prostu wyślij wiodący `\n`, żeby BOM poszedł jako osobna, śmieciowa linia.
- ⚠️ **Samo EOF na stdin nie zatrzymuje 26.40 od ręki** — w teście 2026-08-04 serwer zignorował
  zamknięcie strumienia przez ponad 2 minuty, a wyszedł dopiero ~35 s po zakończeniu procesu
  rodzica. Jedyne przewidywalne zamknięcie to **komenda `stop`** (albo Ctrl+C w prawdziwej konsoli).
  Nie ustawiaj w skryptach „timeout → `Kill()`": twarde ubicie uszkadza LevelDB (patrz incydent
  2026-07-24). Lepiej zostawić wiszący proces i zdiagnozować, niż go zabić.
- **Serwer zatrzymuj komendą `stop` (lub Ctrl+C), NIE zamykaj okna konsoli na X** — Windows daje
  wtedy tylko ~5 s na zapis i twardo ubija proces (ryzyko uciętego zapisu świata; ginie też
  zapis listy botów `simplayerRejoining`).
- **Nie uruchamiaj dwóch instancji serwera na tym samym świecie** i nie ubijaj procesu twardo —
  to główne przyczyny uszkodzenia bazy LevelDB.

### Bezpieczny launcher: `Start-Server.bat` (wyłączony krzyżyk X)

Żeby nie dało się przypadkowo ubić serwera myszką, uruchamiaj go przez **`Start-Server.bat`**
(dwuklik). Launcher (`start_server.ps1`) usuwa „Zamknij" z menu systemowego okna → **krzyżyk (X)
i Alt+F4 są nieaktywne, dopóki serwer działa**. Jedyny sposób zatrzymania to wpisanie `stop`.
Po `stop` X wraca do działania i okno można normalnie zamknąć.

Aby uruchamiać z pulpitu: zrób skrót do `C:\BedrServer\Start-Server.bat` (albo przepnij istniejący
skrót „SERVER" na ten plik).

**Ścieżki są względne** (od 2026-08-16): `.bat` używa `%~dp0`, a `start_server.ps1` — `$PSScriptRoot`.
Katalogiem serwera jest zawsze katalog skryptu, więc repo może leżeć gdziekolwiek i na obu
maszynach działa identycznie. Nie ma już nic zaszytego na `C:\BedrServer`.

Launcher **odmawia startu, gdy brakuje `bedrock_server.exe`** i wypisuje polecenie pobierające
aktualny link z oficjalnego API — to pierwsza rzecz, na którą trafisz po świeżym `git clone`.

Ograniczenia (X to zabezpieczenie przed *przypadkiem*, nie przed wszystkim): zabicie przez
Menedżer zadań, wylogowanie/restart Windows czy zanik zasilania nadal ubiją proces. Dlatego
**ostateczną siatką bezpieczeństwa pozostają commity świata do gita** — rób je po sesjach.

## Praca na dwóch maszynach (serwer „wędrujący")

Serwer stoi na obu komputerach, a **git jest jedynym kanałem synchronizacji świata**. Grasz tam,
gdzie akurat siedzisz; po sesji świat jedzie na `origin`, druga maszyna go pobiera przed swoją sesją.

### ⚠️ Dlaczego to wymaga dyscypliny

Świat to baza **LevelDB** — zbiór plików binarnych. Git ich **nie zmerguje**. Jeśli zagrasz na
maszynie A bez wypchnięcia, a potem na B, dostaniesz rozjazd, którego nie da się połączyć —
trzeba **wybrać jedną wersję świata i wyrzucić drugą**. Nie ma scenariusza „scalimy postępy".

Stąd jedna zasada: **pobierz przed grą, wypchnij po grze.** Zawsze, na obu maszynach.

### Co launcher robi za ciebie

`start_server.ps1` pilnuje tego sam, więc nie polegasz na pamięci:

| Sytuacja przed startem | Zachowanie |
|---|---|
| repo w synchronizacji | startuje normalnie |
| origin ma nowsze commity | proponuje `git pull --ff-only`, po odmowie **nie startuje** |
| jesteś w tyle **i** masz niezacommitowane zmiany | **nie startuje**, każe ogarnąć lokalne zmiany |
| repo rozjechane (i w tył, i w przód) | **nie startuje**, wymaga ręcznej decyzji |
| masz lokalne commity niewypchnięte | startuje, ostrzega, wypycha po `stop` |
| brak sieci / `fetch` padł | pyta wprost, czy startować mimo nieznanego stanu |

Po `stop` launcher robi `git add -A`, commituje jako `Sesja <data> (<NAZWA-KOMPUTERA>)` i wypycha
na `origin`. Jeśli push padnie, commit i tak jest lokalnie — dostaniesz czerwony komunikat, żeby
wypchnąć ręcznie przed graniem na drugiej maszynie.

Awaryjnie: `Start-Server.bat` uruchomiony z przełącznikiem `-NoSync` (albo bezpośrednio
`powershell -File start_server.ps1 -NoSync`) pomija cały git — wtedy commitujesz sam.

### ⚠️ Wersja BDS musi się zgadzać na obu maszynach

`bedrock_server.exe` nie jest w repo, więc **git nie zsynchronizuje wersji serwera**. Świat jest
migrowany w górę przy pierwszym starcie na nowszym BDS i **starszy serwer go już nie otworzy**.
Kolejność przy aktualizacji jest więc nieprzestawialna:

1. Zaktualizuj BDS na maszynie A, odpal kontrolowanie, zacommituj i wypchnij zmigrowany świat.
2. **Zanim** maszyna B zrobi `git pull` — zaktualizuj na niej BDS do **tej samej** wersji.
3. Dopiero wtedy `pull` i granie.

Odwrotna kolejność = maszyna B pobiera świat, którego jej serwer nie umie otworzyć.

## ⚠️ Incydent 2026-07-24: uszkodzenie i odzysk świata

Objaw: dziura przy bazie + zniknięte farmy (lokalna regeneracja chunków).
Przyczyna: **brudne zamknięcia serwera** podczas serii testów 23.07 (twarde ubicia procesu
między 02:24 a 18:04) → uszkodzenie kilku chunków w LevelDB → regeneracja na świeżo.
NIE było to spowodowane włączeniem Beta APIs (migawka 02:24 z Beta APIs była zdrowa).

Odzysk (bo repo = backup): przywrócono zdrowe pliki świata z commita `b3c168f` (23.07 02:24),
zachowując aktualny konfig paczek (`git checkout b3c168f -- worlds/moj_swiat`, potem
`git checkout HEAD -- worlds/moj_swiat/world_*_packs.json`), weryfikacja kontrolowanym startem.
Uszkodzony stan pozostaje w historii jako `4b39f56` (na wypadek chirurgicznego odzysku
nowszych budowli z uszkodzonej wersji).

**Wniosek na przyszłość:** commituj świat po każdej sesji (git to jedyna siatka bezpieczeństwa),
zawsze zamykaj przez `stop`, jedna instancja serwera naraz.
- `./canopy …` (komendy czatowe Canopy) wymagają uprawnień operatora; `/simplayer:*` — nie.
- Klient nakłada wyłącznie paczki wymienione przez serwer w stacku — kopie w cache klienta
  są nieaktywne, dopóki żaden świat ich nie żąda.
