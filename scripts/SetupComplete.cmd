@echo off

set LOG=C:\ISO-Werkstatt\setup.log

echo ======================================== >> "%LOG%"
echo ISO-Werkstatt SetupComplete >> "%LOG%"
echo %DATE% %TIME% >> "%LOG%"
echo ======================================== >> "%LOG%"

echo Installiere QEMU Guest Agent... >> "%LOG%"

msiexec.exe /i "C:\ISO-Werkstatt\packages\qemu-ga-x86_64.msi" /qn /norestart /L*v "C:\ISO-Werkstatt\qemu-ga-install.log"

echo QEMU Guest Agent ExitCode: %ERRORLEVEL% >> "%LOG%"

exit /b 0