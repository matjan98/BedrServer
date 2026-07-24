# BedrServer — Minecraft Bedrock Dedicated Server

Prywatny serwer BDS (Windows). Świat: `worlds/moj_swiat`. Całe repozytorium = katalog serwera;
commity gitowe pełnią rolę backupów świata i konfiguracji.

## Zainstalowane dodatki

| Dodatek | Wersja bazowa | Uwagi |
|---|---|---|
| Canopy [BP]+[RP] (ForestOfLight) | 1.5.7 | RP ma **lokalny patch** → wersja podbita do **1.5.9** (patrz niżej) |
| Understudy (ForestOfLight) | 1.2.3 | rozszerzenie Canopy; symulowani gracze `/simplayer:*` |

Wymagania: świat musi mieć włączony eksperyment **Beta APIs** (flaga `gametest` w `level.dat`) —
bez niego skrypty Canopy i Understudy w ogóle się nie ładują (`./canopy …` leci jako zwykły czat,
`/simplayer:*` = „Unknown command").

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

## Przydatne fakty administracyjne

- Wersję BDS najpewniej odczytasz z NBT `lastOpenedWithVersion` w `worlds/moj_swiat/level.dat`
  (binarka `bedrock_server.exe` nie ma VersionInfo).
- Ścieżki z `[BP]`/`[RP]` w PowerShellu wymagają `-LiteralPath` (nawiasy to wildcardy!).
- BDS zamyka się **poprawnie** przy EOF na stdin oraz przy Ctrl+C; konsola przez pipe'y wymaga
  drenowania stdout i stderr (inaczej deadlock przy włączonym content-log-console-output).
- **Serwer zatrzymuj komendą `stop` (lub Ctrl+C), NIE zamykaj okna konsoli na X** — Windows daje
  wtedy tylko ~5 s na zapis i twardo ubija proces (ryzyko uciętego zapisu świata; ginie też
  zapis listy botów `simplayerRejoining`).
- **Nie uruchamiaj dwóch instancji serwera na tym samym świecie** i nie ubijaj procesu twardo —
  to główne przyczyny uszkodzenia bazy LevelDB.

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
