# Источники, лицензии и изображения

Оригинальный код передаётся без отдельной лицензии по решению владельца репозитория. Это не изменяет разрешения и требования лицензий сторонних компонентов. Перед внедрением согласуйте условия оригинального кода с владельцем.

## Используемые адаптации

| Источник | Использование | Сохранённая лицензия |
| --- | --- | --- |
| [roberthein/Disco-Ball](https://github.com/roberthein/Disco-Ball) | `DiscoBallGeometry.swift`: геометрия и материалы шара; сцена в `ThemeParty.swift` | [MIT](ThirdParty/DiscoBall/LICENSE), Robert-Hein Hooijmans, 2025 |
| [Polarizz/Gelatin](https://github.com/Polarizz/Gelatin) | Адаптация деформации кнопок в `LiquidButtonMotion.swift` | [MIT](ThirdParty/Gelatin/LICENSE), Paul Wong, 2025 |
| [ajagatobby/SwiftMotion](https://github.com/ajagatobby/SwiftMotion) | Пропорции и обратная связь кнопок в `LiquidButtonMotion.swift` | [MIT](ThirdParty/SwiftMotion/LICENSE), Ajaga, 2026 |
| [alexwidua/genie](https://github.com/alexwidua/genie) | Горизонтальная адаптация шейдера в `AvatarGenie.metal` | [MIT](ThirdParty/Genie/LICENSE.md), Alex Widua, 2024; Janum Trivedi, 2023 |
| [eujinco/ripple-image-transition](https://github.com/eujinco/ripple-image-transition) | Адаптации ripple/reveal в `WelcomeLens.metal` | [MIT](ThirdParty/RippleImageTransition/LICENSE), Eujin Nam, 2026 |

Папки `ThirdParty` сохраняют лицензии, provenance и исходники соответствующих reference-примеров. В Xcode target компилируются только адаптации в `LiquidChats`, не дополнительные приложения из `ThirdParty`. Sample media стороннего ripple-проекта не включены.

Анимация текста в `EmotionalText.swift` и `SeregaSelector` в `CraftMotion.swift` опирается на [Serega Emotional](https://github.com/mishanaer/deslop/tree/main/serega/serega-emotional). Ссылка и описание адаптации: [PROVENANCE.md](ThirdParty/SeregaEmotional/PROVENANCE.md). Отдельная лицензия этого reference-пакета при подготовке передачи не установлена. Сам skill и исходный preset JSON не переиздаются; условия использования производной адаптации следует согласовать перед production-переносом или заменить её реализацией команды.

## Демонстрационные изображения

Материалы в `LiquidChats/Assets.xcassets` включены для воспроизведения согласованного прототипа. Владелец одобрил публичную передачу репозитория с демонстрационными изображениями. Это **не является выдачей отдельных прав на изображения для продукта**.

- Портреты Alicia, Thomas, Jessica, John, изображение Study и крупный портрет были восстановлены или реконструированы AI по предоставленным визуальным референсам. Детали не являются точным восстановлением исходной фотографии.
- Фото Ewan и фоны чатов предоставлены пользователем. Кораллово-сиреневый фон находится в `new-year-wallpaper.imageset` по историческому имени пресета.
- Стикеры, frog-reveal и welcome-lemon происходят из предоставленных примеров и генеративной обработки. Они не входят в MIT-лицензии программных компонентов. Для релиза нужны согласованные оригиналы или разрешённые ресурсы Telegram.
- SF Symbols, системные материалы и эмодзи предоставляются платформой и не переиздаются как отдельные наборы ресурсов.

В репозиторий не включены исходные видеозаписи, личная медиатека телефона, локальная история переписки, старые экспериментальные копии Telegram и исходные неиспользуемые кропы портретов. Выбранные пользователем фотографии остаются только на устройстве во время работы демо.

## Связь с Telegram

Этот репозиторий не является форком Telegram-iOS и не содержит его экспериментальные скопированные исходники из рабочей папки прототипа. При переносе в Telegram действуют условия самого Telegram-iOS и совместно используемых компонентов; ориентир — [официальный репозиторий](https://github.com/TelegramMessenger/Telegram-iOS). Название здесь описывает назначение реализации, а не официальное участие Telegram Messenger.
