param([string]$RepairScript=(Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Repair-DesktopIni.ps1'))
$ErrorActionPreference='Stop'
. $RepairScript -Folders @()
$root=Join-Path $env:TEMP ('ISO-Crafter-native-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root|Out-Null
$path=Join-Path $root 'desktop.ini'
[IO.File]::WriteAllText($path,'fixture unchanged')
$hash=(Get-FileHash $path).Hash
$acl=Get-Acl $path
$sddl=$acl.Sddl
$stamp=[IO.File]::GetLastWriteTimeUtc($path)
[IO.File]::SetAttributes($path,[IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Archive)
Repair-ProtectedDesktopIni -Path $path
if(([IO.File]::GetAttributes($path) -band 7) -ne 7){throw 'Native attributes missing'}
if((Get-FileHash $path).Hash -ne $hash -or (Get-Acl $path).Sddl -ne $sddl -or [IO.File]::GetLastWriteTimeUtc($path) -ne $stamp){throw 'Content/security/timestamp changed'}
$denied=Get-Acl $path
$denied.SetAccessRuleProtection($true,$false)
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$denied.SetAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity.User,([Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::ChangePermissions),'Allow'))
try {
    [IO.File]::SetAttributes($path,[IO.FileAttributes]::Archive)
    Set-Acl -LiteralPath $path -AclObject $denied
    $restricted=(Get-Acl $path).Sddl
    $elevated=([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $failed=$false
    try {Repair-ProtectedDesktopIni -Path $path}catch{$failed=$true;if($elevated){throw}}
    if(-not $elevated -and -not $failed){throw 'Unexpected unprivileged success'}
    if((Get-Acl $path).Sddl -ne $restricted -or (Get-FileHash $path).Hash -ne $hash){throw 'Protected file security/content modified'}
    if($elevated){'PASS: Protected-file restore privilege path.'}else{'INFO: Elevated restore path requires VM test; unprivileged access correctly rejected.'}
} finally {$restore=[Security.AccessControl.FileSecurity]::new();$restore.SetSecurityDescriptorSddlForm($sddl,[Security.AccessControl.AccessControlSections]::Access);[IO.File]::SetAccessControl($path,$restore)}
'PASS: Native attributes, content/owner/ACL/timestamp preservation.'