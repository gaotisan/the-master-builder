@echo off
REM EGIPTO, ACTO I: el peregrino en lo alto del altar con el video del templo ya visto: el altar baja y saca la losa hasta las ruinas (prueba).
REM Flechas o WASD andar (doble toque correr), espacio saltar, F3 ver lo que se pisa, F4 marcar un fallo, Esc salir. No toca el juego.
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/dev/egipto_losa.tscn
endlocal
