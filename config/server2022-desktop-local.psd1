@{
    TargetOS = 'Server2022'
    InstallationMode = 'Desktop'
    Edition = 'Windows Server 2022 SERVERSTANDARD (Desktop Experience)'
    LocalUserName = 'Winuser'
    AnswerTemplate = 'answer\Autounattend-Server2022-local.xml'
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