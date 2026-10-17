# BedrServer — instrukcje dla agentów

Katalog = działający Minecraft Bedrock Dedicated Server; commity gitowe służą jako backupy świata.

**Przeczytaj `README.md` przed zmianami w paczkach** — w szczególności sekcję
„LOKALNY PATCH: Canopy [RP]": paczka `resource_packs/Canopy[RP]` zawiera lokalną modyfikację
`ui/hud_screen.json` (InfoDisplay przełączany F8/paperdoll; wersja podbita do 1.5.10), którą trzeba
**ponownie nałożyć przy każdej aktualizacji Canopy** zgodnie z procedurą z README.
Nie nadpisuj jej bezmyślnie plikami z upstreamu.
Kontrolka `hud_title_text` musi być `stack_panel` z `orientation: vertical` (poprawka zgodności z MC 26.50).

Zasady:
- Nie edytuj plików świata (`worlds/`), gdy `bedrock_server.exe` działa — najpierw zatrzymaj (`stop`).
- Ścieżki z `[BP]`/`[RP]` w PowerShellu: zawsze `-LiteralPath`.
- Świat wymaga eksperymentu Beta APIs (flaga `gametest` w level.dat) — bez niego Canopy/Understudy nie działają.
