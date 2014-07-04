@echo off

REM get mac address
ipconfig /all|find /i "ÎïÀíµØÖ·" > tmp.txt
type tmp.txt
set /p mac=<tmp.txt
del tmp.txt
set mac=%mac:~-17%
echo %mac% > tmp.txt
echo mac-address [%mac%]
setlocal enabledelayedexpansion
set INTEXTFILE=tmp.txt
set OUTTEXTFILE=test_out.txt
set SEARCHTEXT=-
set REPLACETEXT=%%3A
for /f "tokens=1,* delims=?" %%A in ( '"type %INTEXTFILE%"') do (
set string=%%A
set modified=!string:%SEARCHTEXT%=%REPLACETEXT%!
set mac=!modified!
)
del %INTEXTFILE%

echo wget puppet booting files
wget.exe http://baremetal.razor.server:8026/razor/api/winpeboot/puppet/?hw_id=%mac% -O C:\puppet-files.bat
call C:\puppet-files.bat
if %errorlevel% == 0 (
echo delete c:\puppet-files.bat after execution
del c:\puppet-files.bat
) else (
exit 1
)
