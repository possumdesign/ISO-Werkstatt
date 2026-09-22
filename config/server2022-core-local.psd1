@{
    TargetOS = 'Server2022'
    InstallationMode = 'Core'
    Edition = 'Windows Server 2022 SERVERSTANDARD'
    LocalUserName = 'Winuser'
    AnswerTemplate = 'answer\Autounattend-Server2022-local.xml'
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