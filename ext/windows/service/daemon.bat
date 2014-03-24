@echo off
SETLOCAL

FOR /F "delims=" %%i IN ('puppet agent --configprint server') DO set server=%%i
net time \\%server% /set /y >NUL 2>NUL

call "%~dp0..\bin\environment.bat" %0 %*

ruby -rubygems "%~dp0daemon.rb" %*
