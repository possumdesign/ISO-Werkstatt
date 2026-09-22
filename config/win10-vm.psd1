@{
    TargetOS = 'Windows10'
    InstallationMode = 'Desktop'
    Edition = 'Windows 10 Pro'
    LocalUserName = 'LabAdmin'
    AnswerTemplate = 'answer\Autounattend-Windows10-vm.xml'
    ToolsDirectory = 'tools'
    IncludeVirtioDrivers = $true
    Adjustments = @{
        Search = $true
        Explorer = $true
        WindowsDefaults = $true
        Edge = $true
    }
    Features = @{
        Tools = $true
        UBlockLite = $true
        QemuGuestAgent = $true
    }
}