@echo off
REM Wymuszamy KLASYCZNY host konsoli (conhost.exe), bo Windows Terminal
REM ignoruje wylaczenie przycisku X. Tylko w conhost da sie zdezaktywowac X.
start "BedrServer - Minecraft Bedrock (zatrzymanie: wpisz stop)" conhost.exe powershell -NoProfile -ExecutionPolicy Bypass -File "C:\BedrServer\start_server.ps1"
