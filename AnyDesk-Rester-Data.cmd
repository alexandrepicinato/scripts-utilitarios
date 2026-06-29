@echo off
setlocal EnableExtensions
title Resetar AnyDesk
chcp 65001 >nul

set "SERVICE_NAME=AnyDesk"
set "ANYDESK_PROGRAMDATA=%ProgramData%\AnyDesk"
set "ANYDESK_APPDATA=%APPDATA%\AnyDesk"
set "BACKUP_DIR=%TEMP%\AnyDesk_Reset_Backup"
set "WAIT_SERVICE_SECONDS=15"
set "WAIT_ID_SECONDS=60"

call :main
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if "%EXIT_CODE%"=="0" (
    echo Concluido com sucesso.
) else (
    echo Finalizado com erro. Codigo: %EXIT_CODE%
)
pause
exit /b %EXIT_CODE%

:: ============================================================================
:: Fluxo principal
:: ============================================================================
:main
call :require_admin || exit /b 1
call :check_anydesk_service || exit /b 2
call :show_warning || exit /b 3

call :prepare_backup || exit /b 4
call :stop_anydesk || exit /b 5
call :backup_user_files || exit /b 6
call :clean_anydesk_config || exit /b 7
call :start_anydesk || exit /b 8
call :wait_for_anydesk_id || exit /b 9

call :stop_anydesk || exit /b 10
call :restore_user_files || exit /b 11
call :start_anydesk || exit /b 12
call :open_anydesk

exit /b 0

:: ============================================================================
:: Validacoes iniciais
:: ============================================================================
:require_admin
reg query "HKEY_USERS\S-1-5-19" >nul 2>&1
if errorlevel 1 (
    echo Este script precisa ser executado como Administrador.
    echo Clique com o botao direito no arquivo e escolha "Executar como administrador".
    exit /b 1
)
exit /b 0

:check_anydesk_service
sc query "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Servico "%SERVICE_NAME%" nao encontrado.
    echo Verifique se o AnyDesk esta instalado nesta maquina.
    exit /b 1
)
exit /b 0

:show_warning
echo.
echo ATENCAO:
echo Este procedimento vai parar o AnyDesk e limpar arquivos locais de configuracao.
echo Um backup temporario sera criado em:
echo %BACKUP_DIR%
echo.
choice /c SN /n /m "Deseja continuar? [S/N] "
if errorlevel 2 exit /b 1
exit /b 0

:: ============================================================================
:: Backup e limpeza
:: ============================================================================
:prepare_backup
if exist "%BACKUP_DIR%" rd /s /q "%BACKUP_DIR%" >nul 2>&1
mkdir "%BACKUP_DIR%" >nul 2>&1
if errorlevel 1 (
    echo Nao foi possivel criar a pasta de backup: %BACKUP_DIR%
    exit /b 1
)
exit /b 0

:backup_user_files
echo.
echo Salvando preferencias do usuario...

if exist "%ANYDESK_APPDATA%\user.conf" (
    copy /y "%ANYDESK_APPDATA%\user.conf" "%BACKUP_DIR%\user.conf" >nul
)

if exist "%ANYDESK_APPDATA%\thumbnails" (
    xcopy /c /e /h /r /y /i /k "%ANYDESK_APPDATA%\thumbnails" "%BACKUP_DIR%\thumbnails" >nul
)

exit /b 0

:clean_anydesk_config
echo.
echo Limpando configuracoes locais do AnyDesk...

if exist "%ANYDESK_PROGRAMDATA%\service.conf" del /f /q "%ANYDESK_PROGRAMDATA%\service.conf" >nul 2>&1
if exist "%ANYDESK_APPDATA%\service.conf" del /f /q "%ANYDESK_APPDATA%\service.conf" >nul 2>&1

if exist "%ANYDESK_PROGRAMDATA%" del /f /a /q "%ANYDESK_PROGRAMDATA%\*" >nul 2>&1
if exist "%ANYDESK_APPDATA%" del /f /a /q "%ANYDESK_APPDATA%\*" >nul 2>&1

exit /b 0

:restore_user_files
echo.
echo Restaurando preferencias do usuario...

if not exist "%ANYDESK_APPDATA%" mkdir "%ANYDESK_APPDATA%" >nul 2>&1

if exist "%BACKUP_DIR%\user.conf" (
    copy /y "%BACKUP_DIR%\user.conf" "%ANYDESK_APPDATA%\user.conf" >nul
)

if exist "%BACKUP_DIR%\thumbnails" (
    xcopy /c /e /h /r /y /i /k "%BACKUP_DIR%\thumbnails" "%ANYDESK_APPDATA%\thumbnails" >nul
)

exit /b 0

:: ============================================================================
:: Controle do servico AnyDesk
:: ============================================================================
:stop_anydesk
echo.
echo Parando servico AnyDesk...

sc query "%SERVICE_NAME%" | find /i "STOPPED" >nul 2>&1
if not errorlevel 1 goto stop_process

sc stop "%SERVICE_NAME%" >nul 2>&1

set /a COUNT=0
:wait_stop
sc query "%SERVICE_NAME%" | find /i "STOPPED" >nul 2>&1
if not errorlevel 1 goto stop_process

timeout /t 1 /nobreak >nul
set /a COUNT+=1
if %COUNT% lss %WAIT_SERVICE_SECONDS% goto wait_stop

echo O servico nao parou dentro do tempo esperado. Tentando encerrar o processo...

:stop_process
taskkill /f /im "AnyDesk.exe" >nul 2>&1
exit /b 0

:start_anydesk
echo.
echo Iniciando servico AnyDesk...

sc query "%SERVICE_NAME%" | find /i "RUNNING" >nul 2>&1
if not errorlevel 1 exit /b 0

sc start "%SERVICE_NAME%" >nul 2>&1

set /a COUNT=0
:wait_start
sc query "%SERVICE_NAME%" | find /i "RUNNING" >nul 2>&1
if not errorlevel 1 exit /b 0

timeout /t 1 /nobreak >nul
set /a COUNT+=1
if %COUNT% lss %WAIT_SERVICE_SECONDS% goto wait_start

echo Nao foi possivel iniciar o servico AnyDesk dentro do tempo esperado.
exit /b 1

:wait_for_anydesk_id
echo.
echo Aguardando o AnyDesk recriar o arquivo system.conf...

set /a COUNT=0
:wait_id
if exist "%ANYDESK_PROGRAMDATA%\system.conf" (
    findstr /c:"ad.anynet.id=" "%ANYDESK_PROGRAMDATA%\system.conf" >nul 2>&1
    if not errorlevel 1 exit /b 0
)

timeout /t 1 /nobreak >nul
set /a COUNT+=1
if %COUNT% lss %WAIT_ID_SECONDS% goto wait_id

echo O AnyDesk nao gerou o ID dentro de %WAIT_ID_SECONDS% segundos.
echo Verifique manualmente o servico, antivirus ou permissoes da pasta:
echo %ANYDESK_PROGRAMDATA%
exit /b 1

:open_anydesk
echo.
echo Abrindo AnyDesk...

if exist "%ProgramFiles(x86)%\AnyDesk\AnyDesk.exe" (
    start "" "%ProgramFiles(x86)%\AnyDesk\AnyDesk.exe"
    exit /b 0
)

if exist "%ProgramFiles%\AnyDesk\AnyDesk.exe" (
    start "" "%ProgramFiles%\AnyDesk\AnyDesk.exe"
    exit /b 0
)

echo Executavel do AnyDesk nao encontrado nas pastas padrao.
exit /b 0
