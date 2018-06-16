@echo off
CHCP 65001
"%~dp0bin\lua.exe" "%~dp0script\encrypt.lua" "%~dp0\" %1 
pause
