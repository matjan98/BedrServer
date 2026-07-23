# BedrServer — instrukcje dla agentów

Katalog = działający Minecraft Bedrock Dedicated Server; commity gitowe służą jako backupy świata.

**Przeczytaj `README.md` przed zmianami w paczkach** — w szczególności sekcję
„LOKALNY PATCH: Canopy [RP]": paczka `resource_packs/Canopy[RP]` zawiera lokalną modyfikację
`ui/hud_screen.json` (InfoDisplay przełączany F8/paperdoll; wersja podbita do 1.5.9), którą trzeba
**ponownie nałożyć przy każdej aktualizacji Canopy** zgodnie z procedurą z README.
Nie nadpisuj jej bezmyślnie plikami z upstreamu.

Zasady:
- Nie edytuj plików świata (`worlds/`), gdy `bedrock_server.exe` działa — najpierw zatrzymaj (`stop`).
- Ścieżki z `[BP]`/`[RP]` w PowerShellu: zawsze `-LiteralPath`.
- Świat wymaga eksperymentu Beta APIs (flaga `gametest` w level.dat) — bez niego Canopy/Understudy nie działają.
