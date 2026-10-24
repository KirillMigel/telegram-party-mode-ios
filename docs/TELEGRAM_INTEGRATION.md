# Интеграция в Telegram iOS

Цель передачи — воспроизвести согласованный сценарий в настоящем групповом чате, используя существующие данные, разрешения и сетевые операции Telegram. Этот репозиторий даёт запускаемый образец поведения и исходники эффектов. Адаптер к Telegram здесь не реализован; сборка внутри Telegram не проводилась.

Карта сопоставлена с Telegram-iOS на коммите [`f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`](https://github.com/TelegramMessenger/Telegram-iOS/tree/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838). Это проверенная исходная точка, не обещание совпадения с последней веткой. Перед переносом принимающая команда должна сверить имена и владельцев с целевой ревизией.

## Компоненты и точки подключения

| Возможность | Исходники демо | Подключение в Telegram |
| --- | --- | --- |
| Сбор группы жестом | `GroupingChatList.swift`, `GroupDraft.swift`, `AvatarJourney.swift`, `GenieRowText.swift`, `AvatarGenie.metal` | Список чатов и существующий сценарий создания группы. Сначала подтвердить создание сервером, затем заменить временную композицию настоящим peer |
| Вылет Start, орбиты и пружины | `CraftMotion.swift`, `Motion.swift`, `PartyOrbitPhysics.swift` | Изолированный слой сцены в реальном экране чата; координаты получать из его layout, не из демо-строк |
| Шар, свет и музыкальная плашка | `GroupWelcomeScene.swift`, `ThemeParty.swift`, `DiscoBallGeometry.swift` | Локальный декоративный слой над фоном. Музыкальная плашка не воспроизводит аудио |
| Название группы | `LiquidChatsApp.swift`: `beginGroupNameEditing`, `saveGroupName` | Существующий редактор и операции `context.engine.peers`; права менять название определяет хост |
| Аватарка | `AvatarPhotoLibrary.swift`, `GroupWelcomeScene.swift`: `PortalPhotoPicker`, `AvatarJourney.swift` | Существующий поток выбора, обработки и загрузки аватара; пример владельца — [`PeerInfoScreenAvatarSetup.swift`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenAvatarSetup.swift). В этой ревизии он использует `uploadedPeerPhoto` и `updatePeerPhoto` |
| Тема и ripple | `GroupDraft.swift`: `GroupThemeChoice`, `ThemeRippleTransition`; `ThemeParty.swift`, `ChatPhotoBackdrop.swift`, `WelcomeLens.metal` | Сопоставить локальные пресеты существующим данным обоев/тем. [`ChatControllerThemeManagement.swift`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramUI/Sources/Chat/ChatControllerThemeManagement.swift) содержит `setChatWallpaper` и `setChatTheme`; это ориентир, не готовая взаимозаменяемая сигнатура |
| Стикер на сообщении | `PartyInteraction.swift`: `PartyStickerAttachment`; `GroupOnboarding.swift`: `PartyMessage` | Реальный идентификатор сообщения, поверхность бабла и его жизненный цикл. Хранилище привязок и синхронизацию нужно спроектировать отдельно |
| Активный участник и эмодзи | `PartyInteraction.swift`, `GroupOnboarding.swift`, `AvatarJourney.swift` | Событие фактического входящего сообщения и явный двойной тап по баблу. Не считать демонстрационный таймер событием Telegram |
| Стекло и scroll edge | `ChatPhotoBackdrop.swift`: `ChatScrollEdgeBar`, `ChatScrollEdgeLink`; `WelcomeLens.metal` | Реальный scroll view истории, его viewport, клавиатура, safe areas и hit testing |

[`ChatController.swift`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramUI/Sources/ChatController.swift) и [`ChatControllerNode.swift`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramUI/Sources/ChatControllerNode.swift) — отправные точки для размещения сцены. В проверенном исходнике используются UIKit, AsyncDisplayKit, Postbox и TelegramCore. Не заменяйте ими экран целиком: встраивайте только нужный визуальный слой с корректным containment и передачей layout. Для SwiftUI-поддерева возможен `UIHostingController`; маршрутизацию жестов, clipping и жизненный цикл определяет принимающий экран.

## Предлагаемая граница с хостом

[`PartyModeHostContract.swift`](../Integration/PartyModeHostContract.swift) компилируется отдельно и задаёт DTO и async-протокол для адаптера. Он не зависит от TelegramCore и не притворяется его API. Принимающая команда может заменить этот контракт своим принятым стилем, сохранив следующие правила:

1. `PartyPeerReference` содержит аккаунт и полный кодированный peer ID. `Conversation.id`, индекс строки и только числовая часть peer ID недостаточны.
2. `PartyMessageReference` содержит peer, namespace и ID сообщения. Демо использует ID автора для единственной реплики; переносить эту схему в историю нельзя: у одного автора много сообщений.
3. Координаты стикера нормализованы в пределах бабла: `x/y` от 0 до 1. Пересчитывайте рамки после прокрутки, поворота, изменения шрифта и клавиатуры. Не сохраняйте экранные координаты.
4. `stickerKey` выдаёт хост на основе своей медиамодели. Индекс `party-sticker-0` существует только в демо.
5. Методы изменения группы должны завершаться после подтверждения операции. Ошибка сохраняет возможность повторить действие; серверный отказ не должен выглядеть как успешное сохранение.
6. Хост проверяет право на каждую операцию и поддерживает отмену задач при уходе из чата или смене аккаунта.

В этом репозитории нет конкретной реализации `PartyModeHost`, сетевого транспорта для Party Mode или распространения привязок стикеров. `setPartyEnabled` и `storeStickerPlacement` — потребности фичи, а не существующие методы Telegram Engine.

## Рекомендуемый порядок переноса

1. Запустить демо и пройти [критерии приёмки](FEATURE_SPEC.md). Зафиксировать целевой Telegram commit и минимальную версию iOS.
2. Начать с локальной сцены в одном групповом чате за feature flag: шар, аватары, один стикер и существующая поверхность истории. Проверить касания, прокрутку, клавиатуру и возврат назад.
3. Перенести `Motion`, `CraftMotion` и физику. Заменить фикстуры на реальные модели и изображения, поступающие из существующего image pipeline. `Conversation.reference` и локальные приветствия оставить только в демо.
4. Подключить переименование, выбор аватара и темы через существующие редакторы/операции Telegram. Локальный preview отменяется при Cancel; сохранение подтверждается реальным результатом операции.
5. Подключить входящие сообщения к пульсации автора и добавить двойной тап с учётом уже существующих жестов реакций, ссылок, выделения и контекстного меню.
6. Определить продуктовую модель Party Mode: локальная визуальная настройка или состояние группы. Для общего состояния нужны правила прав, хранения, версии данных, синхронизации и поведения других клиентов. Стикер на бабле не становится вложением или реакцией автоматически.
7. Подключить создание группы жестом после успешного переноса сцены. Серверный peer ID появляется только после завершения штатного создания; при отказе восстановить черновик и исходные строки.
8. Добавить исходники и ресурсы в выбранные Bazel targets; скомпилировать Metal в библиотеку, доступную выбранному renderer. Обновить локализацию, доступность и поддержку версий iOS, затем пройти performance-проверку на устройстве.

## Ресурсы и доступность платформы

- Демо нацелено на **iOS 27**. Уменьшение `IPHONEOS_DEPLOYMENT_TARGET` само по себе не обеспечивает совместимость. Для поддерживаемых Telegram версий нужны availability-проверки и fallback для стекла, scroll edge, SwiftUI Metal-эффектов и RealityKit.
- `ShaderLibrary` сейчас обращается к библиотеке приложения. После переноса в отдельный bundle/module настройте загрузку правильной Metal library. Аналогично замените `Image("...")` на загрузку из host resource bundle или image pipeline.
- Интеграция не должна добавлять второй `@main`, `WindowGroup`, глобальную смену цветовой схемы, новый менеджер аккаунтов или второй слой истории сообщений.
- Для медиатеки используйте согласованную стратегию разрешений приложения-хоста. Собственная сетка демо использует `NSPhotoLibraryUsageDescription` и `PHPhotoLibraryPreventAutomaticLimitedAccessAlert`; не запрашивайте полный доступ автоматически и не переносите эти настройки в Telegram без согласования с его текущим picker flow.
- Из `ThirdParty` в сборку ничего не подключается отдельно: нужные адаптации уже находятся в `LiquidChats`. При переносе сохраняйте соответствующие license notices.

Инструкции по сборке самого Telegram находятся в [официальном README](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/README.md). Этот проект не содержит `api_id`, `api_hash`, сертификатов или provisioning profiles и не требует их для запуска демо.
