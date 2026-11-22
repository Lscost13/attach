# Attach

iOS-приложение: агент, который живёт на телефоне. Свой UX вместо Fish Pocket —
чёрный/белый, нативный Liquid Glass, пять вкладок: Чаты (проекты), Мини-аппы,
Агенты, Задачи, Профиль.

Сейчас в репозитории каркас: пять экранов-заглушек и рабочая сборка `.ipa` через
GitHub Actions. Дальше наращиваем агент, файлы, инструменты.

## Как это работает

Xcode на компьютере не нужен и Apple Developer Program для сборки не нужен.

```
push в main → GitHub Actions (macOS) → xcodegen → xcodebuild (без подписи)
            → Attach.ipa → артефакт для скачивания
```

Сборка **неподписанная**: её нельзя запустить сразу, зато её подписывает любой
инструмент на телефоне или на ПК твоим сертификатом. Это и есть схема
«скачал IPA — поставил».

## Установка на телефон

1. Actions → последняя сборка → **Artifacts** → `Attach-ipa` → распаковать,
   внутри `Attach.ipa`.
2. Подписать и установить одним из способов:
   - **eSign / Feather** — на телефоне, нужен `.p12` + `.mobileprovision`;
   - **AltStore / SideStore** — на телефоне, нужен Apple ID;
   - **Sideloadly** — на Windows, по кабелю, Apple ID или сертификат.
3. Если инструмент просит bundle id — он должен совпадать с App ID в профиле.
   По умолчанию в проекте `com.manul.attach`; поменять можно секретом
   `BUNDLE_ID` (Settings → Secrets → Actions) без правки кода.

Позже можно подписывать прямо в CI: положить `.p12` и `.mobileprovision` в
секреты и отдавать готовый к установке IPA. Это имеет смысл, когда появятся
расширения (виджеты, Live Activity) — им нужны entitlements из профиля.

## Секреты

Сейчас обязательных нет. Необязательный:

| Имя | Значение |
| --- | --- |
| `BUNDLE_ID` | свой bundle id, если отличается от `com.manul.attach` |

Публичный репозиторий — macOS-минуты бесплатны и без лимита. Приватный — 200
минут в месяц (2000 обычных, macOS считается ×10), примерно 20–30 сборок.

## Структура

```
app/
  project.yml          # проект собирается XcodeGen, .xcodeproj не храним
  Attach/
    AttachApp.swift
    RootView.swift     # TabView из пяти вкладок (на iOS 26 — нативное стекло)
    Screens.swift      # заглушки экранов
    Assets.xcassets    # иконка
design/prototype.html  # кликабельный макет
.github/workflows/ios.yml
```

Локально посмотреть проект можно только на Mac:

```bash
brew install xcodegen && cd app && xcodegen generate && open Attach.xcodeproj
```
