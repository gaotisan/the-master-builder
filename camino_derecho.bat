@echo off
REM Abre el camino derecho, frontal, aparte del juego (scenes/game/camino_derecho.tscn):
REM el contraplano del camino del bosque, recto y de espaldas hasta la verja de la casa. Sin escena de antes, el peregrino esta quieto con el
REM baston en la mano; para probarlo guardado: camino_derecho.bat espalda
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/game/camino_derecho.tscn -- %*
endlocal
