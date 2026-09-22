@{
    TargetOS = 'Windows10'
    InstallationMode = 'Desktop'
    Edition = 'Windows 10 Pro'
    LocalUserName = 'Winuser'
    AnswerTemplate = 'answer\Autounattend-Windows10-local.xml'
    ToolsDirectory = 'tools'
    IncludeVirtioDrivers = $false
    Adjustments = @{
        Search = $true
        Explorer = $true
        WindowsDefaults = $true
        Edge = $true
    }
    Features = @{
        Tools = $true
        UBlockLite = $true
        QemuGuestAgent = $false
    }
}