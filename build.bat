@echo off
REM ===================================================================
REM  Compila o servidor DelphiMCP a partir da linha de comando.
REM  Ajuste STUDIO_VER se usar outra versao do RAD Studio.
REM ===================================================================
setlocal

set "STUDIO_VER=37.0"
set "RSVARS=C:\Program Files (x86)\Embarcadero\Studio\%STUDIO_VER%\bin\rsvars.bat"

if not exist "%RSVARS%" (
  echo [ERRO] rsvars.bat nao encontrado em: "%RSVARS%"
  echo        Edite STUDIO_VER neste arquivo para a sua versao instalada.
  exit /b 1
)

call "%RSVARS%"

if not exist "%~dp0bin" mkdir "%~dp0bin"
if not exist "%~dp0bin\dcu" mkdir "%~dp0bin\dcu"

echo Compilando DelphiMCP...
dcc32.exe -B -E"%~dp0bin" -NU"%~dp0bin\dcu" -NS"System;System.Win;Winapi;Vcl;Data" "%~dp0src\DelphiMCP.dpr"

if errorlevel 1 (
  echo.
  echo [FALHA] Compilacao com erros.
  exit /b 1
)

echo.
echo [OK] Binario gerado em: %~dp0bin\DelphiMCP.exe
endlocal
