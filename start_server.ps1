# Launcher serwera BedrServer z WYLACZONYM krzyzykiem (X) okna konsoli.
# Dzieki temu nie da sie przypadkowo ubic serwera klikajac X (co uszkadza swiat).
# Serwer zatrzymuje sie WYLACZNIE komenda: stop
#
# KATALOG SERWERA = katalog tego skryptu ($PSScriptRoot). Zadnych sciezek na sztywno,
# wiec repo moze lezec gdziekolwiek i na obu maszynach dziala identycznie.
#
# SYNCHRONIZACJA MIEDZY MASZYNAMI (swiat to baza LevelDB - git jej NIE zmerguje):
#   przed startem  - AUTOMATYCZNY pull, jesli origin ma nowsze commity. Bez pytania.
#                    Gdy pull jest niebezpieczny (niezacommitowane zmiany albo rozjazd
#                    historii) launcher NIE startuje i mowi, co zrobic,
#   po zatrzymaniu - swiat jest commitowany i wypychany na origin.
#
# Przelaczniki:
#   -NoSync     pomin caly git (gra offline / awaryjnie). Pamietaj wtedy commitowac recznie.
#   -CheckOnly  wykonaj sam pre-flight (fetch + ewentualny pull) i zakoncz,
#               BEZ uruchamiania serwera. Do sprawdzenia, czy jestes zsynchronizowany.

param(
    [switch]$NoSync,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Exe  = Join-Path $Root 'bedrock_server.exe'

function Write-Banner($Text, $Color) {
    Write-Host ""
    Write-Host "  ==================================================================" -ForegroundColor $Color
    foreach ($line in $Text) { Write-Host "   $line" -ForegroundColor $Color }
    Write-Host "  ==================================================================" -ForegroundColor $Color
    Write-Host ""
}

function Stop-WithMessage($Text) {
    Write-Banner $Text 'Red'
    [void](Read-Host "Nacisnij Enter, aby zamknac to okno")
    exit 1
}

function Invoke-Git {
    # Zwraca wyjscie jako tablice linii; kod wyjscia w $script:GitExit.
    # Lokalne 'Continue' jest KONIECZNE: git pisze normalne komunikaty na stderr
    # (push praktycznie wszystko), a PowerShell 5.1 opakowuje przechwycony stderr
    # natywnego programu w ErrorRecord - przy 'Stop' wywalaloby to caly skrypt
    # mimo kodu wyjscia 0. Stan sprawdzamy wylacznie przez $LASTEXITCODE.
    $ErrorActionPreference = 'Continue'
    $out = & git -C $Root @args 2>&1
    $script:GitExit = $LASTEXITCODE
    return $out
}

# ---------------------------------------------------------------- kontrola wstepna
if (-not (Test-Path -LiteralPath $Exe)) {
    Stop-WithMessage @(
        "BRAK PLIKU: bedrock_server.exe",
        "",
        "Binarka celowo nie jest trzymana w gicie (patrz .gitignore i README).",
        "Pobierz aktualna wersje BDS i skopiuj exe do:",
        "  $Root",
        "",
        "Link do pobrania (PowerShell):",
        "  (Invoke-WebRequest 'https://net-secondary.web.minecraft-services.net/api/v1.0/download/links'",
        "     -UseBasicParsing | ConvertFrom-Json).result.links |",
        "     Where-Object downloadType -eq 'serverBedrockWindows' |",
        "     Select-Object -ExpandProperty downloadUrl"
    )
}

# ---------------------------------------------------------------- synchronizacja: przed startem
$SyncActive = $false

if ($NoSync) {
    Write-Banner @("Tryb -NoSync: git pominiety. Swiat NIE zostanie zacommitowany po stop.") 'Yellow'
}
elseif (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
    Write-Banner @("To nie jest repozytorium git - synchronizacja pominieta.") 'Yellow'
}
else {
    $branch = (Invoke-Git rev-parse --abbrev-ref HEAD | Select-Object -First 1)
    if ($GitExit -ne 0) { Stop-WithMessage @("Nie udalo sie odczytac galezi gita.", $branch) }
    $branch = "$branch".Trim()

    $null = Invoke-Git remote get-url origin
    if ($GitExit -ne 0) {
        Write-Banner @("Repo nie ma zdalnego 'origin' - synchronizacja pominieta.") 'Yellow'
    }
    else {
        $SyncActive = $true
        Write-Host "  Sprawdzam stan wzgledem origin/$branch ..." -ForegroundColor DarkGray
        $fetchOut = Invoke-Git fetch origin --quiet
        if ($GitExit -ne 0) {
            Write-Banner @(
                "NIE UDALO SIE POLACZYC Z ORIGIN (brak sieci?).",
                "Nie wiem, czy swiat na tej maszynie jest aktualny.",
                "",
                $($fetchOut -join ' ')
            ) 'Yellow'
            $a = Read-Host "Startowac mimo to? Grozi nadpisaniem postepow z drugiej maszyny [t/N]"
            if ($a -notmatch '^[tTyY]') { Stop-WithMessage @("Przerwane. Polacz sie z siecia i sprobuj ponownie.") }
            $SyncActive = $false
        }
        else {
            $dirty  = @(Invoke-Git status --porcelain).Count -gt 0
            $counts = (Invoke-Git rev-list --left-right --count "origin/$branch...$branch" | Select-Object -First 1)
            $parts  = "$counts".Trim() -split '\s+'
            $behind = [int]$parts[0]
            $ahead  = [int]$parts[1]

            if ($behind -gt 0 -and $ahead -gt 0) {
                Stop-WithMessage @(
                    "REPO SIE ROZJECHALO: $behind commitow z tylu, $ahead z przodu.",
                    "",
                    "Ktos gral na obu maszynach bez synchronizacji. Swiat to baza LevelDB,",
                    "git NIE potrafi tego zmergowac - trzeba WYBRAC jedna wersje swiata.",
                    "Rozwiaz to recznie, zanim wystartujesz serwer."
                )
            }
            elseif ($behind -gt 0) {
                if ($dirty) {
                    Stop-WithMessage @(
                        "Jestes $behind commitow za origin, a masz NIEZACOMMITOWANE zmiany.",
                        "Najpierw ogarnij lokalne zmiany (commit albo odrzuc), potem pobierz."
                    )
                }
                Write-Host "  Origin ma $behind nowszych commitow - pobieram ..." -ForegroundColor Yellow
                $pullOut = Invoke-Git pull --ff-only origin $branch
                if ($GitExit -ne 0) {
                    Stop-WithMessage @(
                        "POBIERANIE NIE POWIODLO SIE - nie startuje, zebys nie gral na starym swiecie.",
                        "",
                        $($pullOut -join ' ')
                    )
                }
                Write-Banner @("Pobrano $behind commitow z origin. Swiat jest aktualny.") 'Green'
            }
            elseif ($ahead -gt 0) {
                Write-Banner @("Masz $ahead lokalnych commitow niewypchnietych na origin. Wypchne je po stop.") 'Yellow'
            }
            else {
                Write-Host "  Swiat aktualny wzgledem origin/$branch." -ForegroundColor Green
            }

            if ($dirty -and $behind -eq 0) {
                Write-Host "  Uwaga: sa niezacommitowane zmiany z poprzedniej sesji - wejda do commita po stop." -ForegroundColor Yellow
            }
        }
    }
}

# ---------------------------------------------------------------- tryb samego sprawdzenia
if ($CheckOnly) {
    Write-Banner @(
        "Tryb -CheckOnly: pre-flight zakonczony, serwera NIE uruchamiam.",
        "Swiat nietkniety."
    ) 'Cyan'
    exit 0
}

# ---------------------------------------------------------------- wylaczenie krzyzyka (X)
Add-Type -Namespace Win -Name Con -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern System.IntPtr GetSystemMenu(System.IntPtr hWnd, bool bRevert);
[DllImport("user32.dll")] public static extern bool DeleteMenu(System.IntPtr hMenu, uint uPosition, uint uFlags);
[DllImport("user32.dll")] public static extern bool DrawMenuBar(System.IntPtr hWnd);
'@

$SC_CLOSE = 0xF060
$MF_BYCOMMAND = 0x0
$hwnd = [Win.Con]::GetConsoleWindow()
if ($hwnd -ne [System.IntPtr]::Zero) {
    $menu = [Win.Con]::GetSystemMenu($hwnd, $false)
    [void][Win.Con]::DeleteMenu($menu, $SC_CLOSE, $MF_BYCOMMAND)   # usun "Zamknij" z menu systemowego -> X szary/nieaktywny
    [void][Win.Con]::DrawMenuBar($hwnd)
}

Write-Banner @(
    "Krzyzyk (X) tego okna jest WYLACZONY - nie ubijesz serwera myszka.",
    "Aby ZATRZYMAC serwer wpisz:   stop    i nacisnij Enter."
) 'Yellow'

# ---------------------------------------------------------------- serwer
# Uruchamiamy bezposrednio, bez pipe'ow: stdin/stdout zostaja prawdziwa konsola.
# (Pipe'y wymagalyby drenowania stdout I stderr, a StandardInput dokleja BOM,
#  przez co serwer widzi "Unknown command: <BOM>stop" i sie nie zatrzymuje.)
Set-Location -LiteralPath $Root
& $Exe

# ---------------------------------------------------------------- przywrocenie krzyzyka
if ($hwnd -ne [System.IntPtr]::Zero) {
    [void][Win.Con]::GetSystemMenu($hwnd, $true)   # bRevert=true -> przywroc domyslne menu (X znowu dziala)
    [void][Win.Con]::DrawMenuBar($hwnd)
}

Write-Host ""
Write-Host "Serwer zatrzymany. Okno mozna teraz zamknac." -ForegroundColor Green

# ---------------------------------------------------------------- synchronizacja: po zatrzymaniu
if ($SyncActive) {
    Write-Host ""
    Write-Host "  Zapisuje swiat do gita ..." -ForegroundColor DarkGray

    $null = Invoke-Git add -A
    if (@(Invoke-Git status --porcelain).Count -eq 0) {
        Write-Host "  Brak zmian w swiecie - nie ma czego commitowac." -ForegroundColor DarkGray
    }
    else {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        $msg   = "Sesja $stamp ($env:COMPUTERNAME)"
        $cOut  = Invoke-Git commit -m $msg
        if ($GitExit -ne 0) { Write-Banner @("Commit sie nie udal:", $($cOut -join ' ')) 'Red' }
        else { Write-Host "  Zacommitowano: $msg" -ForegroundColor Green }
    }

    $pOut = Invoke-Git push origin HEAD
    if ($GitExit -ne 0) {
        Write-Banner @(
            "PUSH SIE NIE UDAL - zmiany sa zacommitowane LOKALNIE, ale nie ma ich na origin.",
            "Wypchnij je recznie (git push), zanim usiadziesz do gry na drugiej maszynie.",
            "",
            $($pOut -join ' ')
        ) 'Red'
    }
    else {
        Write-Banner @("Swiat zacommitowany i wypchniety. Mozesz grac na drugiej maszynie.") 'Green'
    }
}

[void](Read-Host "Nacisnij Enter, aby zamknac to okno")
