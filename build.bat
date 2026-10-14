@echo off
REM ===================================================================
REM  Compila o servidor DelphiMCP a partir da linha de comando.
REM  Ajuste STUDIO_VER se usar outra versao do RAD Studio.
REM
REM  Na primeira execucao, baixa as dependencias em lib\ (requer git):
REM    - MCPConnect  https://github.com/delphi-blocks/MCPConnect
REM    - Neon        https://github.com/paolo-rossi/delphi-neon
REM    - Logify      https://github.com/delphi-blocks/Logify
REM ===================================================================
setlocal

set "STUDIO_VER=37.0"
set "RSVARS=C:\Program Files (x86)\Embarcadero\Studio\%STUDIO_VER%\bin\rsvars.bat"
set "LIB=%~dp0lib"

if not exist "%RSVARS%" (
  echo [ERRO] rsvars.bat nao encontrado em: "%RSVARS%"
  echo        Edite STUDIO_VER neste arquivo para a sua versao instalada.
  exit /b 1
)

call :baixar MCPConnect https://github.com/delphi-blocks/MCPConnect.git || exit /b 1
call :baixar Neon       https://github.com/paolo-rossi/delphi-neon.git  || exit /b 1
call :baixar Logify     https://github.com/delphi-blocks/Logify.git     || exit /b 1

call "%RSVARS%"

if not exist "%~dp0bin" mkdir "%~dp0bin"
if not exist "%~dp0bin\dcu" mkdir "%~dp0bin\dcu"

set "PATHS=%LIB%\MCPConnect\Source;%LIB%\Neon\Source;%LIB%\Logify\Source"

echo Compilando DelphiMCP...
dcc32.exe -B -E"%~dp0bin" -NU"%~dp0bin\dcu" -U"%PATHS%" -I"%PATHS%" ^
  -NS"System;System.Win;Winapi;Vcl;Data;Web" "%~dp0src\DelphiMCP.dpr"

if errorlevel 1 (
  echo.
  echo [FALHA] Compilacao com erros.
  exit /b 1
)

echo.
echo [OK] Binario gerado em: %~dp0bin\DelphiMCP.exe
endlocal
exit /b 0

REM Clona %2 em lib\%1, se ainda nao existir.
:baixar
if exist "%LIB%\%~1" exit /b 0
echo Baixando %~1...
git clone --depth 1 %~2 "%LIB%\%~1"
if errorlevel 1 (
  echo [ERRO] Falha ao clonar %~2
  exit /b 1
)
exit /b 0
