# BedrServer — Minecraft Bedrock Dedicated Server

Prywatny serwer BDS (Windows). Świat: `worlds/moj_swiat`. Całe repozytorium = katalog serwera;
commity gitowe pełnią rolę backupów świata i konfiguracji.

## Zainstalowane dodatki

| Dodatek | Wersja bazowa | Uwagi |
|---|---|---|
| Canopy [BP]+[RP] (ForestOfLight) | 1.5.7 | RP ma **lokalny patch** → wersja podbita do **1.5.8** (patrz niżej) |
| Understudy (ForestOfLight) | 1.2.3 | rozszerzenie Canopy; symulowani gracze `/simplayer:*` |
| Star's Debug Screen (@ayy_star) | BP 7.1.1 / RP 7.1.0 | debug HUD w stylu F3 |

Wymagania: świat musi mieć włączony eksperyment **Beta APIs** (flaga `gametest` w `level.dat`) —
bez niego skrypty Canopy i Understudy w ogóle się nie ładują (`./canopy …` leci jako zwykły czat,
`/simplayer:*` = „Unknown command").

## ⚠️ LOKALNY PATCH: Canopy [RP] — konflikt tytułów ze Star's Debug Screen

**Problem:** oba dodatki przesyłają dane do klienta przez tytuł ekranu (`setTitle`).
Star's Debug Screen dopełnia pola wykrzyknikami (`padStart(100, "!")` w
`behavior_packs/Debug-Screen-B/scripts/debug_main.js`), a Canopy [RP] podmienia kontrolkę
`hud_title_text` na własną etykietę (InfoDisplay), która renderuje surowy tekst tytułu.
Bez patcha: na górze ekranu widać rząd wykrzykników `!!!!…` (surowy pakiet danych Star'sa).

**Patch:** w `resource_packs/Canopy[RP]/ui/hud_screen.json`, w kontrolce
`hud_title_text` → `controls` → `title` → `bindings`, dodane są dwa wpisy (subskrypcja +
warunek widoczności) — etykieta Canopy ukrywa się, gdy tytuł zaczyna się od `!`:

```json
{
    "binding_name": "#hud_title_text_string"
},
{
    "binding_type": "view",
    "source_property_name": "(not (('%.1s' * #hud_title_text_string) = '!'))",
    "target_property_name": "#visible"
}
```

Dodatkowo — żeby klienci nie używali starej kopii z cache — wersja RP jest podbita o +1
względem oryginału, spójnie w **trzech** miejscach:

1. `resource_packs/Canopy[RP]/manifest.json` → `header.version` = `[1, 5, 8]`
2. `behavior_packs/Canopy[BP]/manifest.json` → `dependencies` (uuid `bcf34368-…`) = `[1, 5, 8]`
3. `worlds/moj_swiat/world_resource_packs.json` → wpis `bcf34368-…` = `[1, 5, 8]`

### 🔁 Procedura przy KAŻDEJ aktualizacji Canopy

Nowa wersja Canopy **nadpisze/zgubi patch** — po każdej aktualizacji trzeba go nałożyć ponownie:

1. Zainstaluj nowe Canopy [BP] + [RP] (np. 1.6.0).
2. W nowym `Canopy[RP]/ui/hud_screen.json` dodaj powyższe bindingi do etykiety `title`
   w `hud_title_text` (jeżeli autor zmienił strukturę — zasada: etykieta renderująca
   `#hud_title_text_string` ma być ukryta, gdy pierwszy znak tytułu to `!`).
3. Podbij `header.version` RP o +1 względem wydania autora (np. 1.6.0 → 1.6.1)
   i ustaw tę samą wersję w zależności w manifeście BP oraz w
   `worlds/moj_swiat/world_resource_packs.json` (BP w `world_behavior_packs.json`
   zostaje z oficjalną wersją BP).
4. Sprawdź, czy nowy Understudy wymaga tej wersji Canopy BP (dependency w jego manifeście).
5. Kontrolowany start serwera → w logu mają być: `Experiment(s) active: gtst`, wszystkie paczki
   w Pack Stack, `[Canopy] Registered Understudy …`, brak błędów zależności.
6. Commit + push.

### Ograniczenie (nie do obejścia patchem)

Star's Debug Screen i InfoDisplay Canopy (`./info …`) nadal współdzielą kanał tytułu i nadpisują
się nawzajem (~10×/s) — **używaj jednego wyświetlacza danych naraz**. Obie paczki mogą być
stale zainstalowane; chodzi tylko o jednoczesne włączenie obu HUD-ów (migotanie).

## Przydatne fakty administracyjne

- Wersję BDS najpewniej odczytasz z NBT `lastOpenedWithVersion` w `worlds/moj_swiat/level.dat`
  (binarka `bedrock_server.exe` nie ma VersionInfo).
- Ścieżki z `[BP]`/`[RP]` w PowerShellu wymagają `-LiteralPath` (nawiasy to wildcardy!).
- BDS zamyka się **poprawnie** przy EOF na stdin; konsola przez pipe'y wymaga drenowania
  stdout i stderr (inaczej deadlock przy włączonym content-log-console-output).
- `./canopy …` (komendy czatowe Canopy) wymagają uprawnień operatora; `/simplayer:*` — nie.
