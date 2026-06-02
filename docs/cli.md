# CLI: контекст и инструменты без VS Code

Те же возможности модели доступны из командной строки — для отладки, скриптов, CI и headless-агентов.

## Контекст модели

```bash
node scripts/pflow-context.mjs list                                  # JSON-реестр всех сущностей
node scripts/pflow-context.mjs context --focus all                   # markdown по всему воркспейсу
node scripts/pflow-context.mjs context --focus name --name "<Имя>"   # фокус по имени
node scripts/pflow-context.mjs context --focus canvas --name "<Имя>" # фокус на Канвасе
node scripts/pflow-context.mjs context --workspace path/to/dir ...   # альтернативный воркспейс
```

Флаг `--profile` (любая подкоманда) пишет разбивку по этапам в **stderr** — stdout остаётся чистым:

```bash
node scripts/pflow-context.mjs context --focus all --profile > out.md
```

## Прямой вызов MCP-инструментов (remote / CI без MCP-клиента)

Когда нативного `mcp__pflow__*` нет (CI, headless-агент), JSON-RPC-обёртка не нужна — вендоренный бандл зовёт tool напрямую:

```bash
node .pflow/mcp/pflow-mcp.cjs tools                                      # список tool'ов: имя, описание, аргументы
node .pflow/mcp/pflow-mcp.cjs tool pflow_health_v2 --args '{"severity":"attention"}'
node .pflow/mcp/pflow-mcp.cjs tool pflow_fields    --args '{"entity_type":"услуга"}'
node .pflow/mcp/pflow-mcp.cjs tool pflow_refs      --args '{"name":"<Имя>"}' --workspace path/to/dir
```

`--args` — JSON-аргументы (валидируются zod-схемой tool'а; невалидные → exit 2). stdout — содержимое ответа (тот же текст/JSON, что в нативном MCP), exit 1 если tool вернул ошибку. Воркспейс — `--workspace` или cwd. Полный список инструментов — [mcp.md](mcp.md).

## Гейт корректности в CI

`check`-подкоманда того же бандла — гейт для PR/CI: читает диагностики + health и падает на ошибках/critical, показывая attention в отчёте.

```bash
node .pflow/mcp/pflow-mcp.cjs check .                       # дефолт: валит на error/critical
node .pflow/mcp/pflow-mcp.cjs check . --max-severity attention   # строже: валит и на attention
node .pflow/mcp/pflow-mcp.cjs check . --json                # машиночитаемый отчёт
```

Exit: `0` — чисто (с видимыми attention), `1` — есть error/находки ≥ порога, `2` — внутренняя ошибка/плохой флаг. Готовый GitHub Actions workflow раскатывается вместе с проектом (`.github/workflows/pflow-check.yml`) и постит отчёт комментарием в PR.
