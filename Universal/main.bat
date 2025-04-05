@echo off
set BASE=%~dp0
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%BASE%\main.ps1" -UsbRoot "%BASE%"
