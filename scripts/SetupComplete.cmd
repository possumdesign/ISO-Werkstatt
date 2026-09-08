@echo off

echo [ISO-Werkstatt] Installiere QEMU Guest Agent...

msiexec.exe /i "C:\ISO-Werkstatt\packages\qemu-ga-x86_64.msi" /qn /norestart

exit /b 0