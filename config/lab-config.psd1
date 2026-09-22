@{
    LocalUserName = 'LabAdmin'
    # Bisheriger Labor-Build; Pfade relativ zum Repository.
    TargetOS       = "Windows11"
    Edition        = "Windows 11 Pro"
    AnswerTemplate = "answer\Autounattend.xml"
    ToolsDirectory = "tools"

    # Jede Gruppe kann unabhängig deaktiviert werden.
    Adjustments = @{
        Search          = $true
        Explorer        = $true
        WindowsDefaults = $true
        Edge            = $true
    }
}
