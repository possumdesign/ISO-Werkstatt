# Repariert nur Attribute vorhandener Shell-Metadaten; -Diagnose verändert nichts.
param([string[]]$Folders = @(
    [Environment]::GetFolderPath('DesktopDirectory'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('Startup'),
    [Environment]::GetFolderPath('CommonStartup')
), [switch]$Diagnose)
$ErrorActionPreference='Stop'

function Repair-ProtectedDesktopIni {
    param([string]$Path)
    if(-not ('IsoCrafter.DesktopIniAttributesV3' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace IsoCrafter {
    public static class DesktopIniAttributesV3 {
        [StructLayout(LayoutKind.Sequential)] struct LUID { public uint Low; public int High; }
        [StructLayout(LayoutKind.Sequential)] struct TOKEN_PRIVILEGES { public uint Count; public LUID Luid; public uint Attributes; }
        [StructLayout(LayoutKind.Sequential)] struct FILE_BASIC_INFO {
            public long Creation, Access, Write, Change; public uint Attributes;
        }
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
        [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool LookupPrivilegeValue(string system, string name, out LUID luid);
        [DllImport("advapi32.dll", SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES state, uint size, out TOKEN_PRIVILEGES previous, out uint needed);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetFileInformationByHandleEx(SafeFileHandle file, int infoClass, out FILE_BASIC_INFO info, uint size);
        [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle file, int infoClass, ref FILE_BASIC_INFO info, uint size);
        static SafeFileHandle Open(string path) {
            // Read/write attributes only; no data, owner or ACL write access.
            return CreateFile(path, 0x180, 7, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
        }
        public static void Repair(string path) {
            if(!String.Equals(Path.GetFileName(path), "desktop.ini", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Only desktop.ini is permitted.");
            IntPtr token=IntPtr.Zero;
            TOKEN_PRIVILEGES previous=new TOKEN_PRIVILEGES();
            bool adjusted=false;
            SafeFileHandle file=null;
            try {
                file=Open(path);
                int error=Marshal.GetLastWin32Error();
                if(file.IsInvalid) {
                    file.Dispose(); file=null;
                    if(error!=5) throw new Win32Exception(error);
                    if(!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) throw new Win32Exception(Marshal.GetLastWin32Error());
                    LUID luid;
                    if(!LookupPrivilegeValue(null, "SeRestorePrivilege", out luid)) throw new Win32Exception(Marshal.GetLastWin32Error());
                    TOKEN_PRIVILEGES enable=new TOKEN_PRIVILEGES { Count=1, Luid=luid, Attributes=2 };
                    uint needed;
                    bool ok=AdjustTokenPrivileges(token, false, ref enable, (uint)Marshal.SizeOf(typeof(TOKEN_PRIVILEGES)), out previous, out needed);
                    error=Marshal.GetLastWin32Error();
                    adjusted=ok;
                    if(!ok || error!=0) throw new Win32Exception(error, "SeRestorePrivilege unavailable. Run in elevated Windows PowerShell.");
                    file=Open(path);
                    if(file.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                FILE_BASIC_INFO current;
                uint size=(uint)Marshal.SizeOf(typeof(FILE_BASIC_INFO));
                if(!GetFileInformationByHandleEx(file, 0, out current, size)) throw new Win32Exception(Marshal.GetLastWin32Error());
                if((current.Attributes & 0x410)!=0) throw new IOException("Directories and reparse points are not permitted.");
                // Zero timestamps preserve existing times; retain all other attributes.
                FILE_BASIC_INFO change=new FILE_BASIC_INFO { Attributes=(current.Attributes | 6u) & ~128u };
                if(!SetFileInformationByHandle(file, 0, ref change, size)) throw new Win32Exception(Marshal.GetLastWin32Error());
            } finally {
                if(file!=null) file.Dispose();
                try {
                    if(adjusted) {
                        TOKEN_PRIVILEGES ignored; uint needed;
                        if(!AdjustTokenPrivileges(token, false, ref previous, (uint)Marshal.SizeOf(typeof(TOKEN_PRIVILEGES)), out ignored, out needed))
                            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not restore previous privilege state.");
                    }
                } finally { if(token!=IntPtr.Zero) CloseHandle(token); }
            }
        }
    }
}
'@
    }
    [IsoCrafter.DesktopIniAttributesV3]::Repair($Path)
}


Write-Output 'ISO-Crafter desktop.ini repair v3'
$failures=[Collections.Generic.List[string]]::new()
if($Diagnose){
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=[Security.Principal.WindowsPrincipal]::new($identity)
    "Benutzer: $($identity.Name)"
    "Erhöhte Administratorrechte: $($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
}
foreach($folder in @($Folders | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)){
    $path=Join-Path $folder 'desktop.ini'
    try {
        if(-not (Test-Path -LiteralPath $path -PathType Leaf)){continue}
        $item=Get-Item -LiteralPath $path -Force
        $before=$item.Attributes
        "Prüfe: $path | Attribute: $before"
        if($before -band [IO.FileAttributes]::ReparsePoint){throw 'Verknüpfte desktop.ini wird nicht bearbeitet.'}
        if($Diagnose){
            $acl=Get-Acl -LiteralPath $path
            "Besitzer: $($acl.Owner)"
            foreach($rule in $acl.Access){
                "ACL: $($rule.IdentityReference) | $($rule.AccessControlType) | $($rule.FileSystemRights) | Geerbt: $($rule.IsInherited)"
            }
            continue
        }
        $after=$before -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
        if($before -ne $after){
            try { $item.Attributes=$after }
            catch {
                Write-Output "Standardzugriff fehlgeschlagen; gezielte Attributreparatur mit Wiederherstellungsrecht: $path"
                Repair-ProtectedDesktopIni -Path $path
            }
        }
        $item.Refresh()
        if(($item.Attributes -band ([IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System)) -ne ([IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System)){throw 'Schutzattribute wurden nicht übernommen.'}
        "desktop.ini: $path | vorher: $before | nachher: $($item.Attributes)"
    }
    catch {
        $message="$path : $($_.Exception.Message)"
        $failures.Add($message)
        Write-Warning $message
    }
}
if($failures.Count){throw "Nicht alle Dateien konnten geprüft oder repariert werden: $($failures -join ' | ')"}
