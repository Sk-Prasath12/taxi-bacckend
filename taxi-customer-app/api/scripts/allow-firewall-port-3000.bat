@echo off
:: Run as Administrator: right-click -> Run as administrator
powershell -ExecutionPolicy Bypass -File "%~dp0allow-firewall-port-3000.ps1"
pause
