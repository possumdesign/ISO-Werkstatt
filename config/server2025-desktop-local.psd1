@{
    TargetOS = 'Server2025'
    InstallationMode = 'Desktop'
    Edition = 'Windows Server 2025 SERVERSTANDARD (Desktop Experience)'
    LocalUserName = 'Winuser'
    AnswerTemplate = 'answer\Autounattend-Server2025-local.xml'
    ToolsDirectory = 'tools'
    IncludeVirtioDrivers = $false
    Adjustments = @{
        Search = $false
        Explorer = $true
        WindowsDefaults = $false
        Edge = $false
    }
    Features = @{
        Tools = $true
        UBlockLite = $false
        QemuGuestAgent = $false
    }
}