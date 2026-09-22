# Die Oberfläche startet vor der Kennworteingabe mit Administratorrechten.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
try {
    . (Join-Path $PSScriptRoot "gui\GuiSupport.ps1")
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $arguments = @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
        $argumentLine = ($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " "
        Start-Process -FilePath (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe") `
            -ArgumentList $argumentLine -Verb RunAs -WindowStyle Hidden -ErrorAction Stop
        return
    }
    . (Join-Path $PSScriptRoot "BuildSupport.ps1")
    . (Join-Path $PSScriptRoot "gui\GuiWindow.ps1")
    $ui = New-BuilderWindow -Root $PSScriptRoot -ViewPath (Join-Path $PSScriptRoot "gui\BuilderWindow.xaml")
    [void]$ui.Window.ShowDialog()
}
catch {
    [void][Windows.MessageBox]::Show($_.Exception.Message, "ISO-Werkstatt – Start nicht möglich", "OK", "Error")
}
