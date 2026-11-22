# Пульт

iOS-приложение: агент, который живёт на телефоне. Свой UX вместо Fish Pocket —
чёрный/белый, нативный Liquid Glass, пять вкладок: Чаты (проекты), Мини-аппы,
Агенты, Задачи, Профиль.

Сейчас в репозитории каркас: пустые экраны + рабочая сборка `.ipa` через
GitHub Actions. Дальше наращиваем агент, файлы, инструменты.

## Что нужно установить

На Windows — **ничего**. Сборка идёт на macOS-раннере GitHub; локально уже есть
`git`, `gh`, `node`, `python` — для Swift они не нужны.

| Где | Что | Зачем |
| --- | --- | --- |
| Apple | Developer Program (платный) | сертификаты и TestFlight |
| GitHub | репозиторий + секреты | macOS-раннер и ключ |
| iPhone | TestFlight | ставить сборки без провода |

Xcode, Python и прочее на компьютер ставить не надо. Python появится позже —
внутри приложения, как встроенный рантайм, и это будет часть iOS-сборки, а не
установка на телефон.

## Настройка Apple (один раз)

1. **Team ID** — [developer.apple.com/account](https://developer.apple.com/account)
   → Membership → *Team ID* (10 символов).
2. **Ключ App Store Connect** —
   [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Users and Access
   → Integrations → App Store Connect API → **+**:
   - роль **App Manager** (или Admin);
   - скачать `.p8` (файл даётся один раз), записать **Key ID** и **Issuer ID**.
3. **Карточка приложения** — App Store Connect → My Apps → **+** → New App:
   - платформа iOS, имя любое, например «Пульт»;
   - Bundle ID: создать новый `com.manul.pocket` (или свой);
   - SKU — любой, например `pocket001`.

## Секреты GitHub

Settings → Secrets and variables → Actions → New repository secret:

| Имя | Значение |
| --- | --- |
| `APPLE_TEAM_ID` | Team ID из пункта 1 |
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | содержимое `.p8` в base64 |
| `BUNDLE_ID` | *(необязательно)* свой bundle id |

Base64 из Windows:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\путь\AuthKey_XXXX.p8"))
```

## Сборка

```bash
git push origin main
```

Actions → **iOS** → сборка (~5–10 мин) → артефакт `Pocket-ipa` + автоматическая
отправка в TestFlight. На телефоне: TestFlight → установить.

Публичный репозиторий — macOS-минуты бесплатны и без лимита. Приватный — 200
минут в месяц (2000 обычных, macOS считается ×10), примерно 20–30 сборок.

## Структура

```
app/
  project.yml          # проект собирается XcodeGen, .xcodeproj не храним
  Pocket/
    PocketApp.swift
    RootView.swift     # TabView из пяти вкладок
    Screens.swift      # заглушки экранов
design/prototype.html  # кликабельный макет (чёрный/белый, стекло)
.github/workflows/ios.yml
```

Локально проект можно посмотреть так (нужен Mac):

```bash
brew install xcodegen && cd app && xcodegen generate && open Pocket.xcodeproj
```
