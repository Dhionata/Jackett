@echo off
setlocal enabledelayedexpansion
title Atualizador do Jackett (Custom Concurrency)

:: ========================================================
:: 0. Verificacao de Privilegios de Administrador
:: Necessario para parar/iniciar o servico Windows do Jackett
:: e substituir os binarios em C:\ProgramData\Jackett
:: ========================================================
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Solicitando privilegios de Administrador para gerenciar o servico do Jackett...
    powershell -NoProfile -Command "Start-Process '%~dpnx0' -ArgumentList '%*' -Verb RunAs"
    exit /b
)

echo ========================================================
echo        Atualizador do Jackett (Custom Concurrency)
echo ========================================================
echo.

cd /d "C:\Users\xiyun\repos\Jackett"

:: ========================================================
:: 1. Sincronizacao Git (Upstream e Repositorio Pessoal)
:: ========================================================
for /f "tokens=*" %%b in ('git branch --show-current 2^>nul') do set CURRENT_BRANCH=%%b
if "!CURRENT_BRANCH!"=="" set CURRENT_BRANCH=feature/flaresolverr-max-concurrency-setting

echo [1/6] Sincronizando com o Jackett oficial (upstream/master)...
git fetch upstream master
git merge upstream/master -m "merge: upstream updates" --no-edit
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Conflito no merge com o upstream. Resolva os conflitos antes de compilar.
    if "%~1"=="" pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/6] Enviando atualizacoes para seu GitHub (origin/!CURRENT_BRANCH!)...
git push origin !CURRENT_BRANCH!
if %ERRORLEVEL% neq 0 (
    echo [AVISO] Falha ao enviar para o GitHub. Verifique credenciais ou conexao de rede.
) else (
    echo [OK] Repositorio no GitHub atualizado com sucesso.
)

:: ========================================================
:: 2. Deteccao de Versao e Compilacao do Jackett
:: ========================================================
echo.
echo [3/6] Detectando versao do Jackett...
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "try { ([System.Reflection.AssemblyName]::GetAssemblyName('C:\ProgramData\Jackett\JackettService.dll')).Version.ToString() } catch { '0.24.2981.0' }"') do set JACKETT_VER=%%v
if "!JACKETT_VER!"=="" set JACKETT_VER=0.24.2981.0
echo Versao detectada: !JACKETT_VER!

echo.
echo [4/6] Compilando Jackett (win-x86 Release) com versao !JACKETT_VER!...
dotnet publish src/Jackett.Server/Jackett.Server.csproj -f net9.0 -c Release -r win-x86 --no-self-contained -o "C:\Users\xiyun\repos\Jackett\build_output" /p:AssemblyVersion=!JACKETT_VER! /p:FileVersion=!JACKETT_VER! /p:Version=!JACKETT_VER!
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falha na compilacao do Jackett!
    if "%~1"=="" pause
    exit /b %ERRORLEVEL%
)

:: ========================================================
:: 3. Parada Segura do Servico do Windows e Processos
:: ========================================================
echo.
echo [5/6] Parando servico do Windows e processos do Jackett...
powershell -NoProfile -Command "Stop-Service -Name Jackett -Force -ErrorAction SilentlyContinue; Stop-Process -Name Jackett*, jackett* -Force -ErrorAction SilentlyContinue"
net stop Jackett /y >nul 2>&1

:: Aguarda liberacao completa dos locks de arquivos
timeout /t 3 /nobreak >nul

:: ========================================================
:: 4. Substituicao dos Binarios e Arquivos WebUI
:: ========================================================
echo.
echo [6/6] Copiando binarios e arquivos da WebUI...
copy /Y "C:\Users\xiyun\repos\Jackett\build_output\Jackett.Common.dll" "C:\ProgramData\Jackett\Jackett.Common.dll" >nul
if %ERRORLEVEL% neq 0 (
    echo [AVISO] Tentando liberar processo residual travando Jackett.Common.dll...
    powershell -NoProfile -Command "Stop-Process -Name Jackett*, jackett* -Force -ErrorAction SilentlyContinue"
    timeout /t 2 /nobreak >nul
    copy /Y "C:\Users\xiyun\repos\Jackett\build_output\Jackett.Common.dll" "C:\ProgramData\Jackett\Jackett.Common.dll"
)
copy /Y "C:\Users\xiyun\repos\Jackett\build_output\JackettConsole.dll" "C:\ProgramData\Jackett\JackettConsole.dll" >nul
copy /Y "C:\Users\xiyun\repos\Jackett\src\Jackett.Common\Content\custom.js" "C:\ProgramData\Jackett\Content\custom.js" >nul
copy /Y "C:\Users\xiyun\repos\Jackett\src\Jackett.Common\Content\index.html" "C:\ProgramData\Jackett\Content\index.html" >nul
copy /Y "%~dpnx0" "C:\ProgramData\Jackett\atualizar_jackett.bat" >nul 2>&1

:: ========================================================
:: 5. Reinicializacao do Servico e Aplicacao de Bandeja
:: ========================================================
echo.
echo Reiniciando servico do Windows Jackett...
powershell -NoProfile -Command "Start-Service -Name Jackett -ErrorAction SilentlyContinue"
net start Jackett >nul 2>&1

if exist "C:\ProgramData\Jackett\JackettTray.exe" (
    powershell -NoProfile -Command "if (-not (Get-Process -Name JackettTray -ErrorAction SilentlyContinue)) { Start-Process 'C:\ProgramData\Jackett\JackettTray.exe' }"
)

:: ========================================================
:: 6. Validacao de Servico e Integracao com Byparr
:: ========================================================
echo.
echo Validando servicos e comunicacao...
powershell -NoProfile -Command ^
    "$jackettOk = $false; for ($i=0; $i -lt 5; $i++) { try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:9117/UI/Dashboard' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { $jackettOk = $true; break } } catch { Start-Sleep -Seconds 1 } }; " ^
    "if ($jackettOk) { Write-Host '[OK] Jackett esta ativo e respondendo na porta 9117!' -ForegroundColor Green } else { Write-Host '[AVISO] Jackett ainda esta inicializando na porta 9117.' -ForegroundColor Yellow }; " ^
    "try { $byparr = Invoke-RestMethod -Uri 'http://127.0.0.1:8191/config' -TimeoutSec 3; Write-Host ('[OK] Byparr (FlareSolverr) conectado na porta 8191! Concorrencia: ' + $byparr.maxConcurrency) -ForegroundColor Green } catch { Write-Host '[AVISO] Byparr nao respondeu na porta 8191. Verifique se o Byparr esta em execucao.' -ForegroundColor Yellow }"

echo.
echo ========================================================
echo           Jackett atualizado com sucesso!
echo ========================================================
echo.
if "%~1"=="" pause
