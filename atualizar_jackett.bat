@echo off
setlocal enabledelayedexpansion
echo ========================================================
echo        Atualizador do Jackett (Custom Concurrency)
echo ========================================================
echo.

cd /d "C:\Users\xiyun\repos\Jackett"
echo [1/4] Baixando atualizacoes do Jackett oficial...
git fetch upstream master
git merge upstream/master -m "merge: upstream updates" --no-edit
if %ERRORLEVEL% neq 0 (
    echo AVISO: Houve conflito no merge. Resolva os conflitos antes de compilar.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/4] Detectando versao do Jackett...
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "try { ([System.Reflection.AssemblyName]::GetAssemblyName('C:\ProgramData\Jackett\JackettService.dll')).Version.ToString() } catch { '0.24.2981.0' }"') do set JACKETT_VER=%%v
if "%JACKETT_VER%"=="" set JACKETT_VER=0.24.2981.0
echo Versao detectada: %JACKETT_VER%

echo.
echo Compilando Jackett (win-x86 Release) com versao %JACKETT_VER%...
dotnet publish src/Jackett.Server/Jackett.Server.csproj -f net9.0 -c Release -r win-x86 --no-self-contained -o "C:\Users\xiyun\repos\Jackett\build_output" /p:AssemblyVersion=%JACKETT_VER% /p:FileVersion=%JACKETT_VER% /p:Version=%JACKETT_VER%
if %ERRORLEVEL% neq 0 (
    echo ERRO na compilacao!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/4] Parando Jackett para substituir binarios...
powershell -Command "Stop-Process -Name Jackett*, jackett* -Force -ErrorAction SilentlyContinue"
timeout /t 2 /nobreak >nul

echo.
echo [4/4] Copiando binarios atualizados...
copy /Y "C:\Users\xiyun\repos\Jackett\build_output\Jackett.Common.dll" "C:\ProgramData\Jackett\Jackett.Common.dll"
copy /Y "C:\Users\xiyun\repos\Jackett\build_output\JackettConsole.dll" "C:\ProgramData\Jackett\JackettConsole.dll"
copy /Y "C:\Users\xiyun\repos\Jackett\src\Jackett.Common\Content\custom.js" "C:\ProgramData\Jackett\Content\custom.js"
copy /Y "C:\Users\xiyun\repos\Jackett\src\Jackett.Common\Content\index.html" "C:\ProgramData\Jackett\Content\index.html"

echo.
echo ========================================================
echo           Jackett atualizado com sucesso!
echo ========================================================
echo.
pause
