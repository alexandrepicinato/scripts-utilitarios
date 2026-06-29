@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"

set "WINRAR=C:\Program Files\WinRAR\WinRAR.exe"

if not exist "%WINRAR%" (
    echo ERRO: WinRAR nao encontrado em:
    echo %WINRAR%
    echo.
    pause
    exit /b 1
)

echo =====================================
echo Procurando arquivos .zst em:
echo %CD%
echo =====================================

set "TOTAL=0"

for /r %%F in (*.zst) do (
    set /a TOTAL+=1
    echo.
    echo =====================================
    echo Encontrado: %%F
    echo =====================================

    set "DESTINO=%%~dpnF"

    if not exist "!DESTINO!" (
        mkdir "!DESTINO!"
    )

    "%WINRAR%" x -y "%%F" "!DESTINO!"

    if errorlevel 1 (
        echo ERRO ao extrair: %%F
    ) else (
        echo Extraido com sucesso para: !DESTINO!
    )
)

if "%TOTAL%"=="0" (
    echo.
    echo Nenhum arquivo .zst encontrado neste diretorio ou subdiretorios.
) else (
    echo.
    echo Total de arquivos .zst processados: %TOTAL%
)

echo.
echo Processo concluido.
pause
