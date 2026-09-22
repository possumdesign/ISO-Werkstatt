@{
    LocalUserName = 'Winuser'
    TargetOS            = 'Windows11'
    Edition             = 'Windows 11 Pro'
    AnswerTemplate      = 'answer\Autounattend-PC.xml'
    ToolsDirectory      = 'tools'
    IncludeVirtioDrivers = $false
    Adjustments = @{
        Search          = $true
        Explorer        = $true
        WindowsDefaults = $true
        Edge            = $true
    }
    Features = @{
        Tools          = $true
        UBlockLite     = $true
        QemuGuestAgent = $false
    }
}
