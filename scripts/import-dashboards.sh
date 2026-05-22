#!/bin/bash
# Import Grafana dashboards via API
GRAFANA_URL="http://grafana.kubequest.local"
USER="admin"
PASS="changeme-in-secret"
DATASOURCE="Prometheus"

import_dashboard() {
  local id=$1
  echo "Importing dashboard ID: $id ..."
  JSON=$(curl -s "https://grafana.com/api/dashboards/${id}/revisions/latest/download")
  PAYLOAD=$(echo "$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['id'] = None
print(json.dumps({'dashboard': d, 'overwrite': True, 'inputs': [{'name': 'DS_PROMETHEUS', 'type': 'datasource', 'pluginId': 'prometheus', 'value': 'Prometheus'}, {'name': 'DS_VICTORIAMETRICS-PROD-ALL', 'type': 'datasource', 'pluginId': 'prometheus', 'value': 'Prometheus'}, {'name': 'DS_LOKI', 'type': 'datasource', 'pluginId': 'loki', 'value': 'Loki'}]}))
")
  RESULT=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD" \
    "${GRAFANA_URL}/api/dashboards/import")
  echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  -> OK:', d.get('title', d))" 2>/dev/null || echo "  -> $RESULT"
}

import_dashboard 3119
import_dashboard 6417
import_dashboard 10257
import_dashboard 9614

echo ""
echo "Done ! Ouvre Grafana -> Dashboards pour les voir."
