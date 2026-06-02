# MCP: агент-редактор модели

**80%+ изменений модели делает агент** (Claude Code, Cursor и совместимые с Model Context Protocol). Расширение настраивает связку из коробки, а агент работает с моделью через набор MCP-инструментов — не читая `.pflow`/`.sflow` напрямую.

> Полный список сущностей и брифы «как назвать / что писать» — [dsl-guide.md](dsl-guide.md) и [dsl-reference.md](dsl-reference.md). Рабочие сценарии — [use-cases.md](use-cases.md).

## Подключение

Две команды в палитре VS Code:

- **ProductFlow: Инициализировать проект для агента** — для **пустого** воркспейса: раскатывает стартовый каркас (один файл = одна сущность) + `AGENTS.md` + `CLAUDE.md` + `.mcp.json`.
- **ProductFlow: Подключить MCP-сервер к текущему проекту** — для **существующего** проекта: кладёт только `.mcp.json` + `AGENTS.md` + `CLAUDE.md`, не трогая `.pflow`.

Агент подхватывает `.mcp.json` автоматически — после команды его достаточно перезапустить.

## Инструменты

### Дискавери / контекст
| Инструмент | Что возвращает |
|---|---|
| `pflow_overview` | **Стартовый вызов.** Спайн проекта (Юнит/Канвасы/Сегменты), счётчики сущностей, health-сводка, статус нарратива, карта «куда дальше». Заменяет ритуал из нескольких тяжёлых вызовов |
| `pflow_list` | Реестр всех сущностей с именами/типами/файлами — для дискавери имён |
| `pflow_context { focus, name? }` | Markdown-срез: `all` — весь воркспейс, `name` — сущность по имени, `canvas\|segment\|job` — типизированный поиск |
| `pflow_locate { name, type? }` | `file`/`uri`/`range` определения — чтобы читать нужный фрагмент точечно |

### Валидация и пробелы
| Инструмент | Что возвращает |
|---|---|
| `pflow_validate` | Все диагностики (parser + валидаторы): `{ has_errors, error_count, warning_count, diagnostics }`. `has_errors=true` — модель сломана |
| `pflow_validate_graph` | Cross-layer: orphan-Предложения без `Реализует:`, Канвасы/VPC без Услуг, Услуги без `Реализует:` |
| `pflow_coverage { stale_months?, entity_type? }` | Отчёт о пробелах: + `signal_missing`, `signal_stale`, `orphan_job` |
| `pflow_impact { name, type? }` | Каскад зависимостей перед переименованием/удалением |
| `pflow_health_v2 { aspect_id?, severity?, entity_type? }` | Все health-чекеры (orphans, broken-refs, unfounded, unit-economics, naming…). Каждая находка с `fix` (как починить) и `location`. Отдельный от narrative род — без него агент не видит orphans/unfounded. Те же находки видны в дереве «🩺 Здоровье» — см. [ide.md](ide.md) |

### Графовые срезы
| Инструмент | Что возвращает |
|---|---|
| `pflow_refs { name, type? }` | Incoming/outgoing cross-refs (impact-граф) — обязателен перед переименованием |
| `pflow_jobs_map { name? }` | Карта переиспользования JTBD: для каждой Работы — Канвасы/Switches/Services/Contexts |
| `pflow_signals { target?, field?, vector?, since?, until?, … }` | Плоский список Сигналов с фильтрами по цели/полю/дате/вектору |
| `pflow_enums { entity?, field?, language? }` | Все enum-поля обоих DSL с допустимыми значениями. Зови до записи enum-литерала |
| `pflow_fields { entity_type }` | Допустимые поля сущности (keyword, тип, enum, doc) в каноническом порядке. Зови, когда не уверен, какое поле писать |
| `pflow_guide { entity_type? }` | Бриф на тип (**Зачем/Имя/Что писать/На чём основываться/Антипаттерны**) — свериться при правке, особенно как НАЗВАТЬ. Человеческий рендер — [dsl-reference.md](dsl-reference.md) |

### Скафолдинг
| Инструмент | Что возвращает |
|---|---|
| `pflow_scaffold { entity_type, language, name, write?, dry_run? }` | DSL-заготовка по типу/имени/языку (`language` обязателен). Возвращает `dsl`, `suggested_path`, `agent_prompt`. При `write=true` пишет файл + валидирует; `dry_run` — только превью |

### Narrative-аспекты (рассказ про проект для Canvas-view)
| Инструмент | Что возвращает |
|---|---|
| `pflow_aspect_v2_status` | Все narrative-аспекты (project + per-canvas) + summary `{ total, fresh, stale, missing }` |
| `pflow_aspect_v2_context { aspect_id, scope }` | Срез аспекта: `blocks` (с цитатами Сигналов/Развилок/Премисс), `data_sources` (whitelist — не упоминай сущности вне списка), `sibling_summaries`, `input_hash` |
| `pflow_aspect_v2_save { aspect_id, scope, text, input_hash, … }` | Атомарная запись summary. `input_hash` должен совпадать с тем, что вернул `_context` — иначе `stale` (модель изменилась пока агент думал) |

## AGENTS.md и CLAUDE.md

`AGENTS.md` в корне проекта — инструкция агенту: роль, инструменты, шпаргалка по DSL, чек-лист «зелёной» модели. Парный `CLAUDE.md` фиксирует правило **«MCP first»** (на запросы про модель агент стартует с `pflow_overview`, а не с чтения `.pflow` через `Read`/`Glob`) и через `@AGENTS.md` подтягивает остальное. Claude Code грузит `CLAUDE.md` + `@`-includes; Codex/Cursor — `AGENTS.md` напрямую. Поэтому кладутся оба.

> Без VS Code MCP-инструменты доступны и из командной строки — см. [cli.md](cli.md).
