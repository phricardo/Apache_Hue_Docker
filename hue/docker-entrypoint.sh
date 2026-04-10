#!/usr/bin/env bash
set -euo pipefail

HUE_BIN="/usr/share/hue/build/env/bin/hue"
PYTHON_BIN="/usr/share/hue/build/env/bin/python"

patch_notebook_api() {
  "${PYTHON_BIN}" - <<'PY'
from pathlib import Path

path = Path("/usr/share/hue/desktop/libs/notebook/src/notebook/api.py")
text = path.read_text()
old = """    response = _execute_notebook(request, notebook, snippet)\n\n    span.set_tag('query-id', response.get('handle', {}).get('guid'))\n"""
new = """    response = _execute_notebook(request, notebook, snippet)\n\n    if not isinstance(response, dict):\n      response = {\n        'status': -1,\n        'message': 'Query execution failed to start. Verify the selected interpreter is enabled and reachable.'\n      }\n\n    handle = response.get('handle') or {}\n    if isinstance(handle, dict) and handle.get('guid'):\n      span.set_tag('query-id', handle.get('guid'))\n"""

if old in text and new not in text:
    path.write_text(text.replace(old, new))
PY
}

patch_notebook_conf() {
  "${PYTHON_BIN}" - <<'PY'
from pathlib import Path

path = Path("/usr/share/hue/desktop/libs/notebook/src/notebook/conf.py")
text = path.read_text()

if "import os" not in text:
    text = text.replace("import json\nimport logging\n", "import json\nimport logging\nimport os\n")

old = """    reordered_interpreters = interpreters_shown_on_wheel + [i for i in user_interpreters if i not in interpreters_shown_on_wheel]\n\n    interpreters = [\n"""
new = """    reordered_interpreters = interpreters_shown_on_wheel + [i for i in user_interpreters if i not in interpreters_shown_on_wheel]\n\n    disabled_interpreters = set(filter(None, os.environ.get('HUE_DISABLE_INTERPRETERS', '').split(',')))\n    if disabled_interpreters:\n      reordered_interpreters = [i for i in reordered_interpreters if i not in disabled_interpreters]\n\n    interpreters = [\n"""

if old in text and new not in text:
    text = text.replace(old, new)

path.write_text(text)
PY
}

cleanup_unavailable_hs2_documents() {
  "${PYTHON_BIN}" - <<'PY'
import os
import psycopg2

conn = psycopg2.connect(
    host=os.environ.get("HUE_DB_HOST", "postgres"),
    port=int(os.environ.get("HUE_DB_PORT", "5432")),
    dbname="hue_metastore",
    user="hue",
    password="hue",
)
conn.autocommit = False
cur = conn.cursor()

cur.execute("SELECT id FROM desktop_document2 WHERE type IN ('query-impala', 'query-hive')")
doc2_ids = [row[0] for row in cur.fetchall()]

if doc2_ids:
    cur.execute("SELECT id FROM desktop_document WHERE object_id = ANY(%s)", (doc2_ids,))
    document_ids = [row[0] for row in cur.fetchall()]
    cur.execute("DELETE FROM desktop_document2_dependencies WHERE from_document2_id = ANY(%s) OR to_document2_id = ANY(%s)", (doc2_ids, doc2_ids))
    cur.execute("DELETE FROM desktop_document2permission WHERE doc_id = ANY(%s)", (doc2_ids,))
    if document_ids:
        cur.execute("DELETE FROM desktop_document_tags WHERE document_id = ANY(%s)", (document_ids,))
        cur.execute("DELETE FROM desktop_document WHERE id = ANY(%s)", (document_ids,))
    cur.execute("DELETE FROM desktop_document2 WHERE id = ANY(%s)", (doc2_ids,))

conn.commit()
conn.close()
PY
}

wait_for_port() {
  local host="$1"
  local port="$2"
  local label="$3"

  echo "Aguardando ${label} em ${host}:${port}..."
  for _ in $(seq 1 120); do
    if "${PYTHON_BIN}" -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('${host}', int('${port}'))); s.close()" >/dev/null 2>&1; then
      echo "${label} disponivel."
      return 0
    fi
    sleep 1
  done

  echo "Timeout aguardando ${label} em ${host}:${port}."
  return 1
}

wait_for_port "${HUE_DB_HOST:-postgres}" "${HUE_DB_PORT:-5432}" "PostgreSQL"
wait_for_port "mysql" "3306" "MySQL"

patch_notebook_api
patch_notebook_conf

IMPALA_HOST_RUNTIME="${IMPALA_HOST:-host.docker.internal}"
IMPALA_PORT_RUNTIME="${IMPALA_PORT:-21050}"

if "${PYTHON_BIN}" -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('${IMPALA_HOST_RUNTIME}', int('${IMPALA_PORT_RUNTIME}'))); s.close()" >/dev/null 2>&1; then
  export HUE_DISABLE_INTERPRETERS=""
  echo "Impala disponivel em ${IMPALA_HOST_RUNTIME}:${IMPALA_PORT_RUNTIME}. Habilitando conector Impala."
  cat > /usr/share/hue/desktop/conf/zz-impala-runtime.ini <<EOF
[impala]
server_host=${IMPALA_HOST_RUNTIME}
server_port=${IMPALA_PORT_RUNTIME}

[beeswax]
hive_server_host=${IMPALA_HOST_RUNTIME}
hive_server_port=${IMPALA_PORT_RUNTIME}

[notebook]
[[interpreters]]
[[[impala]]]
is_enabled=true
EOF
else
  export HUE_DISABLE_INTERPRETERS="hive,impala"
  echo "Impala indisponivel em ${IMPALA_HOST_RUNTIME}:${IMPALA_PORT_RUNTIME}. Desabilitando conectores Hive/Impala para evitar erros no Editor."
  cat > /usr/share/hue/desktop/conf/zz-impala-runtime.ini <<EOF
[notebook]
[[interpreters]]
[[[hive]]]
is_enabled=false
[[[impala]]]
is_enabled=false
EOF
  cleanup_unavailable_hs2_documents
fi

"${HUE_BIN}" migrate

if [ -n "${HUE_ADMIN_USER:-}" ] && [ -n "${HUE_ADMIN_PASSWORD:-}" ]; then
  export DJANGO_SUPERUSER_PASSWORD="${HUE_ADMIN_PASSWORD}"
  "${HUE_BIN}" createsuperuser \
    --username "${HUE_ADMIN_USER}" \
    --email "${HUE_ADMIN_EMAIL:-admin@example.com}" \
    --noinput || true
fi

exec "${HUE_BIN}" runserver 0.0.0.0:8888
