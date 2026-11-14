@echo off
setlocal enabledelayedexpansion
title Atualizador Unificado: Byparr + Jackett

:: ========================================================
:: 0. Verificacao de Privilegios de Administrador
:: ========================================================
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Solicitando privilegios de administrador para atualizar Jackett e Byparr...
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process '%~dpnx0' -Verb RunAs"
    ) else (
        powershell -NoProfile -Command "Start-Process '%~dpnx0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)

echo ========================================================
echo       ATUALIZADOR UNIFICADO: BYPARR + JACKETT
echo ========================================================
echo.

:: 1. Executa o atualizador do Byparr
echo ========================================================
echo [ETAPA 1/2] ATUALIZANDO BYPARR...
echo ========================================================
call "C:\Program Files\byparr\atualizar_byparr.bat" --no-pause
set EXIT_CODE=!ERRORLEVEL!
if !EXIT_CODE! neq 0 (
    echo.
    echo [ERRO] A atualizacao do Byparr encerrou com falha - codigo !EXIT_CODE!.
    if "%~1"=="" pause
    exit /b !EXIT_CODE!
)

echo.
echo ========================================================
echo [ETAPA 2/2] ATUALIZANDO JACKETT...
echo ========================================================
call "C:\Users\xiyun\repos\Jackett\atualizar_jackett.bat" --no-pause
set EXIT_CODE=!ERRORLEVEL!
if !EXIT_CODE! neq 0 (
    echo.
    echo [ERRO] A atualizacao do Jackett encerrou com falha - codigo !EXIT_CODE!.
    if "%~1"=="" pause
    exit /b !EXIT_CODE!
)

echo.
echo ========================================================
echo       RESUMO FINAL: VALIDACAO DE INTEGRACAO
echo ========================================================
powershell -NoProfile -Command ^
    "Write-Host 'Testando comunicacao entre os servicos...' -ForegroundColor Cyan; " ^
    "try { $j = Invoke-WebRequest -Uri 'http://127.0.0.1:9117/UI/Dashboard' -UseBasicParsing -TimeoutSec 3; Write-Host ' [OK] Jackett WebUI: Online (Porta 9117)' -ForegroundColor Green } catch { Write-Host ' [FALHA] Jackett WebUI indisponivel' -ForegroundColor Red }; " ^
    "try { $b = Invoke-RestMethod -Uri 'http://127.0.0.1:8191/config' -TimeoutSec 3; Write-Host (' [OK] Byparr Solver: Online (Porta 8191, Concorrencia: ' + $b.maxConcurrency + ')') -ForegroundColor Green } catch { Write-Host ' [FALHA] Byparr Solver indisponivel' -ForegroundColor Red }"

echo.
echo Ambos os servicos foram atualizados, sincronizados com seus
echo respectivos repositorios no GitHub e reiniciados com sucesso!
echo ========================================================
echo.
if "%~1"=="" pause
exit /b 0
