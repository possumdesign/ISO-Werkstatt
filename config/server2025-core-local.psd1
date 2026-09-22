@{
    TargetOS = 'Server2025'
    InstallationMode = 'Core'
    Edition = 'Windows Server 2025 SERVERSTANDARD'
    LocalUserName = 'Winuser'
    AnswerTemplate = 'answer\Autounattend-Server2025-local.xml'
    ToolsDirectory = 'tools'
    IncludeVirtioDrivers = $false
    Adjustments = @{
        Search = $false
        Explorer = $false
        WindowsDefaults = $false
        Edge = $false
    }
    Features = @{
        Tools = $true
        UBlockLite = $false
        QemuGuestAgent = $false
    }
}