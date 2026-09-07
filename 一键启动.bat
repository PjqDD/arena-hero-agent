@echo off
chcp 65001 >nul
title Arena Hero 一键启动
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

if not exist "state" mkdir "state" >nul 2>nul
set "PIDFILE=%CD%\state\agent_launcher.pid"

rem ===== 防重复启动：若已记录的 PID 进程仍存活，则直接退出 =====
if exist "%PIDFILE%" (
    set /p OLD_PID=<"%PIDFILE%"
    if not "!OLD_PID!"=="" (
        tasklist /FI "PID eq !OLD_PID!" 2>nul | findstr /I /C:"cmd.exe" >nul
        if not errorlevel 1 (
            echo [提示] Arena Hero Agent 已在运行（PID !OLD_PID!）。
            echo        如需停止，请运行“一键停止.bat”。
            pause
            exit /b 1
        )
    )
    del "%PIDFILE%" >nul 2>nul
)

rem ===== 检查虚拟环境，首次运行自动初始化 =====
echo [1/2] 检查 Python 虚拟环境 ...
if not exist ".venv\Scripts\python.exe" (
    echo [首次运行] 未检测到 .venv，正在执行 scripts\bootstrap.ps1 初始化环境，请耐心等待……
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1"
    if errorlevel 1 (
        echo [错误] 环境初始化失败，请手动运行 scripts\bootstrap.ps1 查看原因。
        pause
        exit /b 1
    )
)

rem ===== 打开独立 Agent 控制台窗口，并记录该窗口进程的 PID =====
echo [2/2] 正在打开 Agent 控制台窗口 ...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c','start_agent.cmd') -WorkingDirectory '%~dp0' -PassThru; if ($null -eq $p) { exit 1 }; Set-Content -LiteralPath '%~dp0state\agent_launcher.pid' -Value $p.Id"
if errorlevel 1 (
    echo [错误] 无法启动 Agent 控制台窗口。
    pause
    exit /b 1
)

echo.
echo [完成] Arena Hero Agent 已在新的控制台窗口启动。
echo        实时日志：arena_farmer.log
echo        战术展示页：http://127.0.0.1:8765
echo        停止请运行“一键停止.bat”。
echo.
timeout /t 5 /nobreak >nul 2>&1 || ping -n 6 127.0.0.1 >nul 2>&1
exit /b 0
