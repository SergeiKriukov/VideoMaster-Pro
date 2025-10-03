#!/bin/bash

# Скрипт для сборки и подписания VideoMaster Pro для распространения

echo "🚀 Начинаем сборку VideoMaster Pro для распространения..."

# Очистка предыдущих сборок
echo "🧹 Очистка предыдущих сборок..."
xcodebuild clean -project "VideoMaster Pro.xcodeproj" -scheme "VideoMaster Pro"

# Сборка архива
echo "📦 Создание архива..."
xcodebuild -project "VideoMaster Pro.xcodeproj" -scheme "VideoMaster Pro" -configuration Release -archivePath "VideoMaster Pro.xcarchive" archive

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при создании архива"
    exit 1
fi

echo "✅ Архив создан успешно"

# Создание DMG
echo "💿 Создание DMG файла..."
hdiutil create -volname "VideoMaster Pro" -srcfolder "VideoMaster Pro.xcarchive/Products/Applications/VideoMaster Pro.app" -ov -format UDZO "VideoMaster_Pro.dmg"

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при создании DMG"
    exit 1
fi

echo "✅ DMG файл создан: VideoMaster_Pro.dmg"
echo ""
echo "📋 Инструкции для тестирования:"
echo "1. Скопируйте DMG на другой Mac"
echo "2. Откройте DMG и перетащите приложение в Applications"
echo "3. При первом запуске удерживайте Ctrl и кликните по приложению"
echo "4. Выберите 'Открыть' в контекстном меню"
echo "5. Подтвердите запуск в диалоге безопасности"
echo ""
echo "🔧 Для полноценного решения проблемы распространения:"
echo "- Получите Apple Developer Program аккаунт"
echo "- Создайте Distribution Certificate"
echo "- Нотаризуйте приложение через Apple"

