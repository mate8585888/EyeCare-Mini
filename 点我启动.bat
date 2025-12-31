@echo off
cd /d "%~dp0"
:: 杀掉旧进程
taskkill /f /im powershell.exe /t >nul 2>&1
:: 后台启动并完全隐藏 PowerShell 自身的窗口
start /b powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "EyeCare.ps1"
exit