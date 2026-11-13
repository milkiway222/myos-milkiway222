@echo off
chcp 65001 >nul
title MyOS - cloud build
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-cloud.ps1"
echo.
pause
