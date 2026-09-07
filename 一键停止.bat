@echo off
chcp 65001 >nul
title Arena Hero 一键停止
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "PIDFILE=%CD%\state\agent_launcher.pid"
echo [停止] 正在停止 Arena Hero Agent ...

rem ===== 1. 优先使用启动记录中的 PID：先尝试平滑关闭，等待数秒后强制结束整棵进程树 =====
if exist "%PIDFILE%" (
    set /p AGENT_PID=<"%PIDFILE%"
    if not "!AGENT_PID!"=="" (
        tasklist /FI "PID eq !AGENT_PID!" 2>nul | findstr /I /C:"cmd.exe" >nul
        if not errorlevel 1 (
            echo   已定位启动进程 PID !AGENT_PID!，正在停止……
            taskkill /PID !AGENT_PID! /T >nul 2>nul
            for /l %%i in (1,1,8) do (
                tasklist /FI "PID eq !AGENT_PID!" 2>nul | findstr /I /C:"cmd.exe" >nul || goto :pid_stopped
                timeout /t 1 /nobreak >nul 2>&1 || ping -n 2 127.0.0.1 >nul 2>&1
            )
            taskkill /PID !AGENT_PID! /T /F >nul 2>nul
        )
    )
)
:pid_stopped

rem ===== 2. 兜底清理：杀掉本项目根目录下仍存活的 Agent / Dashboard / 包装进程 =====
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $me=$PID; $root='%~dp0'; Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $me -and $_.CommandLine -and $_.CommandLine.ToLowerInvariant().Contains($root.ToLowerInvariant()) -and ($_.CommandLine -match 'arena_farmer\.py|arena_dashboard\.py|start_agent\.cmd|start_agent\.ps1') } | ForEach-Object { & taskkill.exe /PID $_.ProcessId /T /F 2>$null } | Out-Null"

rem ===== 3. 兜底清理：按窗口标题关闭可能残留的 Agent 控制台 =====
taskkill /FI "WINDOWTITLE eq Arena Hero Agent + Dashboard" /T /F >nul 2>nul
taskkill /FI "WINDOWTITLE eq Arena Hero Agent" /T /F >nul 2>nul

if exist "%PIDFILE%" del "%PIDFILE%" >nul 2>nul

echo [完成] Arena Hero Agent 已停止。
timeout /t 3 /nobreak >nul 2>&1 || ping -n 4 127.0.0.1 >nul 2>&1
exit /b 0
