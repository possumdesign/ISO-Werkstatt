@{
    TargetOS = 'Server2025'
    InstallationMode = 'Desktop'
    Edition = 'Windows Server 2025 SERVERSTANDARD (Desktop Experience)'
    LocalUserName = 'LabAdmin'
    AnswerTemplate = 'answer\Autounattend-Server2025-vm.xml'
    ToolsDirectory = 'tools'
    IncludeVirtioDrivers = $true
    Adjustments = @{
        Search = $false
        Explorer = $true
        WindowsDefaults = $false
        Edge = $false
    }
    Features = @{
        Tools = $true
        UBlockLite = $false
        QemuGuestAgent = $true
    }
}