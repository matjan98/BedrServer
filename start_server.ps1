# Launcher serwera BedrServer z WYLACZONYM krzyzykiem (X) okna konsoli.
# Dzieki temu nie da sie przypadkowo ubic serwera klikajac X (co uszkadza swiat).
# Serwer zatrzymuje sie WYLACZNIE komenda: stop
$ErrorActionPreference = 'Stop'

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

Write-Host ""
Write-Host "  ==================================================================" -ForegroundColor Yellow
Write-Host "   Krzyzyk (X) tego okna jest WYLACZONY - nie ubijesz serwera myszka." -ForegroundColor Yellow
Write-Host "   Aby ZATRZYMAC serwer wpisz:   stop    i nacisnij Enter." -ForegroundColor Yellow
Write-Host "  ==================================================================" -ForegroundColor Yellow
Write-Host ""

Set-Location -LiteralPath 'C:\BedrServer'
& 'C:\BedrServer\bedrock_server.exe'

# Po zatrzymaniu serwera przywroc dzialanie X, zeby dalo sie zamknac okno.
if ($hwnd -ne [System.IntPtr]::Zero) {
    [void][Win.Con]::GetSystemMenu($hwnd, $true)   # bRevert=true -> przywroc domyslne menu (X znowu dziala)
    [void][Win.Con]::DrawMenuBar($hwnd)
}
Write-Host ""
Write-Host "Serwer zatrzymany poprawnie. Okno mozna teraz zamknac." -ForegroundColor Green
[void](Read-Host "Nacisnij Enter, aby zamknac to okno")
