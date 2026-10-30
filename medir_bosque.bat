@echo off
REM Mide un plano del bosque (scripts/dev/medir_bosque.gd): capa a capa sin vsync y la cadencia andando con vsync.
REM medir_bosque.bat                 -> camino derecho
REM medir_bosque.bat res://scenes/game/camino_bosque.tscn
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
"%GODOT%" --path "%PROJECT_DIR%." res://scenes/dev/medir_bosque.tscn -- %*
endlocal
