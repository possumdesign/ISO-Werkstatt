@{
    TargetOS = 'Server2022'
    InstallationMode = 'Core'
    Edition = 'Windows Server 2022 SERVERSTANDARD'
    LocalUserName = 'LabAdmin'
    AnswerTemplate = 'answer\Autounattend-Server2022-vm.xml'
    ToolsDirectory = 'tools'
    IncludeVirtioDrivers = $true
    Adjustments = @{
        Search = $false
        Explorer = $false
        WindowsDefaults = $false
        Edge = $false
    }
    Features = @{
        Tools = $true
        UBlockLite = $false
        QemuGuestAgent = $true
    }
}