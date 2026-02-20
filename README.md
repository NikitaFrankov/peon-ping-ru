# 🎮 peon-ping-ru

<div align="center">

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![Windows](https://img.shields.io/badge/Windows-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Language](https://img.shields.io/badge/язык-русский-red)

**🇷🇺 Форк [PeonPing/peon-ping](https://github.com/PeonPing/peon-ping) с русской озвучкой!**

</div>

---

## 🇬🇧 This is a fork

This is a Russian localized fork of [peon-ping](https://github.com/PeonPing/peon-ping) with Warcraft III Russian voice packs. For the original English version, see [PeonPing/peon-ping](https://github.com/PeonPing/peon-ping).

---

## 📖 О проекте

**peon-ping** — это уведомления голосами игровых персонажей для AI-ассистентов. Когда Claude Code, Gemini CLI или другой AI-агент завершает задачу или ждёт подтверждения — вы услышите знаменитые фразы из Warcraft III!

---

## ✨ Особенности форка

- 🇷🇺 **Русские звуковые паки** — peonRu и peasantRu по умолчанию
- 📝 **Русские тексты уведомлений** — "Работа завершена, хозяин", "Че делать, хозяин?", "Жду разрешения, хозяин"
- 🎯 **task.acknowledge включён** — звук при получении задачи
- 🔄 **Своё обновление** — `peon update` обновляет из этого форка

---

## 🚀 Установка

### Быстрая установка (macOS, Linux, WSL2)

```bash
curl -fsSL https://raw.githubusercontent.com/NikitaFrankov/peon-ping-ru/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NikitaFrankov/peon-ping-ru/main/install.ps1" -UseBasicParsing | Invoke-Expression
```

### Клонирование и проверка

```bash
git clone https://github.com/NikitaFrankov/peon-ping-ru.git
cd peon-ping-ru
./install.sh
```

---

## 🎵 Русские звуковые пакы

В этом форке доступны два русских пака:

### 🟢 Orc Peon (RU) — peonRu
Рабочий орк из Warcraft III с русской озвучкой

```
peonRu/
├── sounds/
│   ├── PeonReady1Ru.wav      # "Готов вкалывать"
│   ├── PeonYes1Ru.wav        # "Да-да"
│   ├── PeonYes2Ru.wav        # "С удовольствием"
│   ├── PeonAngry1Ru.wav      # "Чего?!!"
│   └── ... (13 звуков)
└── openpeon.json
```

### 🔵 Human Peasant (RU) — peasantRu
Крестьянин из Warcraft III с русской озвучкой

```
peasantRu/
├── sounds/
│   ├── PeasantReady_ru.wav   # "Я готов."
│   ├── PeasantYes1_ru.wav    # "Да."
│   ├── PeasantAngry1_ru.wav  # "Ты что-ль король? А я за тебя не голосовал."
│   └── ... (18 звуков)
└── openpeon.json
```

---

## 🎛️ Управление

### Включение/выключение звуков

| Метод | Команда |
|-------|---------|
| Slash команда | `/peon-ping-toggle` |
| Терминал | `peon toggle` |

### Смена озвучки на лету

| Метод | Команда |
|-------|---------|
| Slash команда | `/peon-ping-use peonRu` |
| Терминал | `peon packs use peonRu` |

### Полезные команды

```bash
peon status               # Проверить статус
peon volume 0.7           # Установить громкость (0.0–1.0)
peon packs list           # Список установленных паков
peon packs use peonRu     # Выбрать пак
peon preview              # Прослушать звуки
peon update               # Обновить хук из форка
```

---

## 📋 Требования

- **macOS** (Terminal, iTerm2, Warp, etc.)
- **Linux** (с `paplay`, `aplay` или `mpv`)
- **Windows** (WSL2 с PulseAudio)
- **Claude Code**, **Gemini CLI**, **Cursor**, **Codex** или другой AI-ассистент

---

## 📜 Лицензия

Этот проект является форком [PeonPing/peon-ping](https://github.com/PeonPing/peon-ping), распространяемым под лицензией **MIT**.

### Оригинальный проект

- **Автор:** [tonyyont](https://github.com/tonyyont)
- **Репозиторий:** [https://github.com/PeonPing/peon-ping](https://github.com/PeonPing/peon-ping)
- **Лицензия:** MIT

### Звуковые файлы

Звуковые файлы из Warcraft III являются собственностью **Blizzard Entertainment** и используются в образовательных и некоммерческих целях согласно принципу добросовестного использования (fair use).

---

## 🔗 Ссылки

- 🏠 **Оригинальный проект:** [PeonPing/peon-ping](https://github.com/PeonPing/peon-ping)
- 🌐 **Официальный сайт:** [peonping.com](https://peonping.com/)
- 📦 **OpenPeon спецификация:** [CESP](https://github.com/PeonPing/openpeon)
- 🎯 **Реестр паков:** [PeonPing/registry](https://github.com/PeonPing/registry)

---

## 🤝 Вклад

Если хотите добавить больше русских паков — welcome! Создайте issue или pull request.

---
