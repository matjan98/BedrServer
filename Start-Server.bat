@echo off
REM Wymuszamy KLASYCZNY host konsoli (conhost.exe), bo Windows Terminal
REM ignoruje wylaczenie przycisku X. Tylko w conhost da sie zdezaktywowac X.
REM %~dp0 = katalog tego pliku (z koncowym backslashem) -> zadnych sciezek na sztywno,
REM wiec repo moze lezec gdziekolwiek i na obu maszynach dziala identycznie.
start "BedrServer - Minecraft Bedrock (zatrzymanie: wpisz stop)" conhost.exe powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_server.ps1"
