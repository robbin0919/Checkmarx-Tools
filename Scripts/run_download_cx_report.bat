@echo off
REM Checkmarx Download Report Wrapper
powershell -ExecutionPolicy Bypass -File "%~dp0download_cx_report.ps1" %*
