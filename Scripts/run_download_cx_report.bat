@echo off
REM Checkmarx Download Report Wrapper
powershell -ExecutionPolicy Bypass -File "%~dp0download_cx_report.ps1" %*

REM PowerShell 可能會將 Console 編碼改為 UTF-8 (65001)
REM 為了避免影響後續執行的 Big5 (950) 批次檔，此處強制切回 950
chcp 950 >nul
