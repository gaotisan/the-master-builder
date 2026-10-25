@echo off
REM EGIPTO, ACTO I (prueba): el peregrino de perfil por las terrazas del Nilo hasta la losa de la cantera.
REM Flechas o WASD andar (doble toque correr), espacio saltar, abajo agacharse, accion para tirar, R recolocar los sillares, Esc salir. No toca el juego.
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/dev/egipto_acto1.tscn
endlocal
