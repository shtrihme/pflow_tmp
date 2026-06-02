#!/bin/bash
# Проверяет видимость репозитория GitHub.
# Если репо публичное — выводит предупреждение агенту.
# При любой ошибке (нет gh, нет auth, не GitHub) — молча завершается.

set -uo pipefail

# Извлекаем owner/repo из remote origin.
# Поддерживаем три формата:
#   1. SSH:   git@github.com:owner/repo.git
#   2. HTTPS: https://github.com/owner/repo.git
#   3. Proxy: http://user@127.0.0.1:PORT/git/owner/repo  (Claude Code on the web)
REMOTE_URL=$(git remote get-url origin 2>/dev/null) || exit 0

if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
  REPO="${BASH_REMATCH[1]}"
elif [[ "$REMOTE_URL" =~ /([^/]+/[^/]+)/?$ ]]; then
  # Прокси-формат: берём два последних сегмента пути
  REPO="${BASH_REMATCH[1]}"
  REPO="${REPO%.git}"
else
  exit 0
fi

IS_PRIVATE=""

# Попытка 1: gh CLI (локальная среда с авторизованным gh)
if command -v gh &>/dev/null; then
  IS_PRIVATE=$(gh api "repos/${REPO}" --jq '.private' 2>/dev/null) || true
fi

# Попытка 2: curl с GITHUB_TOKEN (CI/CD, GitHub Actions)
if [ -z "$IS_PRIVATE" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  IS_PRIVATE=$(curl -sf \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}" 2>/dev/null \
    | grep -o '"private":[^,}]*' | grep -o 'true\|false') || true
fi

# Попытка 3: Claude Code on the web — gh недоступен, прокси-URL.
# Хук не может вызвать MCP, поэтому передаём агенту инструкцию проверить самому.
if [ -z "$IS_PRIVATE" ] && [[ "$REMOTE_URL" =~ 127\.0\.0\.1 ]]; then
  echo "HOOK session-start: gh CLI недоступен (Claude Code on the web)."
  echo "Агент ОБЯЗАН: вызови mcp__github__search_repositories с query 'repo:${REPO}'"
  echo "и minimal_output=false, проверь поле 'private'."
  echo "Если false — немедленно предупреди пользователя что репозиторий публичный:"
  echo "pflow-проекты содержат конфиденциальную стратегию (сегменты, гипотезы, юнит-экономику)."
  echo "Рекомендуй: GitHub → Settings → Danger Zone → Change visibility → Private."
  exit 0
fi

if [ "$IS_PRIVATE" = "false" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  ⚠️  ВНИМАНИЕ: РЕПОЗИТОРИЙ ПУБЛИЧНЫЙ                        ║"
  echo "╠══════════════════════════════════════════════════════════════╣"
  echo "║  pflow-проекты содержат конфиденциальную продуктовую         ║"
  echo "║  стратегию (сегменты, гипотезы, юнит-экономику).             ║"
  echo "║                                                              ║"
  echo "║  Сделайте репозиторий приватным:                             ║"
  echo "║  GitHub → Settings → Danger Zone → Change visibility         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi
