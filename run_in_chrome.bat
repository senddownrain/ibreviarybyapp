@echo off
chcp 65001 > nul
echo ====================================================
echo Запуск Flutter проекта в браузере Google Chrome...
echo ====================================================

:: 1. Проверяем, есть ли поддержка Web в самом проекте
if not exist "web" (
    echo [1/3] Добавление поддержки Web-платформы в проект...
    call flutter create --platforms=web .
) else (
    echo [1/3] Поддержка Web уже есть в проекте.
)

:: 2. Обновляем зависимости
echo [2/3] Обновление пакетов (flutter pub get)...
call flutter pub get

:: 3. Запуск в Chrome
echo [3/3] Запуск приложения в Chrome...
echo Ожидайте, компиляция может занять около минуты.
call flutter run -d chrome

pause
