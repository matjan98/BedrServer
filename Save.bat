@echo off
setlocal
REM Zapis swiata i konfiguracji do gita + wypchniecie na origin.
REM
REM cd /d "%~dp0" = przejdz do katalogu TEGO pliku. Wczesniej skrypt polegal na
REM katalogu startowym skrotu - odpalony skadkolwiek indziej dzialal na zlym repo
REM albo nie dzialal wcale.
cd /d "%~dp0"

REM --- serwer nie moze dzialac -------------------------------------------------
REM LevelDB trzyma otwarte uchwyty na plikach swiata. Commit przy dzialajacym
REM serwerze konczy sie bledem gita albo zapisuje niespojny stan bazy.
tasklist /FI "IMAGENAME eq bedrock_server.exe" 2>nul | find /I "bedrock_server.exe" >nul
if not errorlevel 1 goto :serwer_dziala

REM --- czy jest co zapisywac ---------------------------------------------------
git add -A
if errorlevel 1 goto :blad_add
git diff --cached --quiet
if errorlevel 1 goto :commituj

echo.
echo   Brak zmian - nie ma czego zapisywac.
echo.
goto :koniec

REM --- commit + push -----------------------------------------------------------
:commituj
git commit -m "Save"
if errorlevel 1 goto :blad_commit
git push origin main
if errorlevel 1 goto :blad_push

echo.
echo   ==================================================================
echo    Zapisane i wypchniete na origin.
echo    Mozesz teraz grac na drugiej maszynie.
echo   ==================================================================
echo.
goto :koniec

REM --- bledy -------------------------------------------------------------------
:serwer_dziala
echo.
echo   ==================================================================
echo    SERWER DZIALA - nie zapisuje.
echo.
echo    LevelDB trzyma otwarte pliki swiata, wiec git rzucilby bledem
echo    albo zapisal niespojny stan bazy.
echo    Zatrzymaj serwer komenda  stop  i uruchom SAVE ponownie.
echo.
echo    Uwaga: launcher SERVER i tak commituje oraz wypycha swiat sam,
echo    zaraz po zatrzymaniu serwera. Zwykle nie musisz tu nic klikac.
echo   ==================================================================
echo.
goto :koniec

:blad_add
echo.
echo   BLAD przy 'git add -A' - patrz komunikat powyzej.
echo   Najczestsza przyczyna: plik zablokowany przez inny proces.
echo.
goto :koniec

:blad_commit
echo.
echo   BLAD przy 'git commit' - patrz komunikat powyzej.
echo.
goto :koniec

:blad_push
echo.
echo   ==================================================================
echo    PUSH SIE NIE UDAL - zmiany sa zacommitowane LOKALNIE,
echo    ale NIE MA ich na origin.
echo.
echo    Najczestsza przyczyna: druga maszyna wypchnela cos w miedzyczasie.
echo    Wtedy trzeba najpierw pobrac jej zmiany - ale UWAGA, swiata
echo    nie da sie zmergowac, patrz "Praca na dwoch maszynach" w README.
echo   ==================================================================
echo.
goto :koniec

:koniec
pause
