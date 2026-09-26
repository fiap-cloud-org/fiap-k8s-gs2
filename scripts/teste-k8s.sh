#!/usr/bin/env bash
###############################################################################
# Teste ponta a ponta no Kubernetes (depois do ./scripts/deploy-k8s.sh):
#   1. PIX pela API (Service via port-forward)
#   2. Livro-razão igual nos dois Pods da API e no Pod da auditoria (PVC)
#   3. Job manual a partir do CronJob liquida as pendências
#   4. Saldo da reserva cai só depois da liquidação
#   5. Escala da API para 3 réplicas
#
# Com EVIDENCIAS=1, grava as saídas em evidencias/etapa3-k8s.
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

NS=unifiapay
PORTA="${PORTA_LOCAL:-18090}"
API="http://localhost:${PORTA}"
EV=evidencias/etapa3-k8s
[ "${EVIDENCIAS:-0}" = 1 ] && mkdir -p "$EV"
salvar() { if [ "${EVIDENCIAS:-0}" = 1 ]; then tee "$EV/$1"; else cat; fi; }
falha() { echo "FALHOU: $*" >&2; exit 1; }

echo "== Pods"
kubectl -n "$NS" get pods -o wide | salvar 01-pods-running.txt

# A auditoria contínua liquidaria sozinha a cada 5 min: pausa durante o teste
kubectl -n "$NS" scale deployment auditoria-service --replicas=0 >/dev/null
kubectl -n "$NS" wait --for=delete pod -l app=auditoria-service --timeout=60s >/dev/null 2>&1 || true

kubectl -n "$NS" port-forward svc/api-pagamentos-service "${PORTA}:8080" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
for _ in $(seq 1 30); do curl -fs "$API/health" >/dev/null 2>&1 && break; sleep 1; done

echo "== Reserva antes"
ANTES=$(curl -fs "$API/api/v1/reserva")
echo "$ANTES"
SALDO_ANTES=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['reserva_bancaria_saldo'])" "$ANTES")

echo "== Enviando 3 PIX"
for v in 120.50 300 79.50; do
  curl -fs -X POST "$API/api/v1/pix" -H 'Content-Type: application/json' \
    -d "{\"valor\": $v, \"chave_destino\": \"cliente@exemplo.com\", \"descricao\": \"teste k8s\"}"
  echo
done

echo "== PIX acima da reserva (deve ser recusado)"
CODIGO=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/api/v1/pix" -H 'Content-Type: application/json' \
  -d '{"valor": 99999999, "chave_destino": "cliente@exemplo.com"}')
echo "HTTP $CODIGO"
[ "$CODIGO" = 400 ] || falha "PIX acima da reserva não foi recusado"

echo "== Livro-razão visto por cada Pod da API (mesmo PVC)"
PODS=$(kubectl -n "$NS" get pods -l app=api-pagamentos -o jsonpath='{.items[*].metadata.name}')
REF=""
for p in $PODS; do
  CONTEUDO=$(kubectl -n "$NS" exec "$p" -- cat /var/logs/api/instrucoes.log)
  echo "--- $p"
  echo "$CONTEUDO"
  [ -z "$REF" ] && REF="$CONTEUDO"
  [ "$CONTEUDO" = "$REF" ] || falha "Pods da API veem arquivos diferentes"
done 2>&1 | salvar 02-volume-compartilhado-api.txt
PENDENTES=$(kubectl -n "$NS" exec "${PODS%% *}" -- grep -c AGUARDANDO_LIQUIDACAO /var/logs/api/instrucoes.log || true)
[ "$PENDENTES" -ge 3 ] || falha "esperava ao menos 3 PIX pendentes, achei $PENDENTES"

echo "== Job manual a partir do CronJob"
JOB="fechamento-manual-$(date +%s)"
kubectl -n "$NS" create job "$JOB" --from=cronjob/cronjob-fechamento-reserva
kubectl -n "$NS" wait --for=condition=complete "job/$JOB" --timeout=120s
{
  kubectl -n "$NS" get cronjob
  echo
  kubectl -n "$NS" get jobs
  echo
  kubectl -n "$NS" logs "job/$JOB"
} | salvar 03-cronjob-e-job.txt

echo "== Livro-razão depois da liquidação"
DEPOIS_LIVRO=$(kubectl -n "$NS" exec "${PODS%% *}" -- cat /var/logs/api/instrucoes.log)
echo "$DEPOIS_LIVRO" | salvar 04-livro-razao-liquidado.txt
grep -q AGUARDANDO_LIQUIDACAO <<<"$DEPOIS_LIVRO" && falha "ainda há PIX pendentes"

echo "== Reserva depois"
DEPOIS=$(curl -fs "$API/api/v1/reserva")
echo "$DEPOIS"
python3 - "$SALDO_ANTES" "$DEPOIS" <<'PY'
import json, sys
antes = float(sys.argv[1]); depois = json.loads(sys.argv[2])
esperado = round(antes - 500.0, 2)
assert depois['reserva_bancaria_saldo'] == esperado, (depois, esperado)
assert depois['reserva_comprometida'] == 0.0, depois
print(f"saldo {antes} -> {depois['reserva_bancaria_saldo']} (liquidados R$ 500,00)")
PY

echo "== Escala da API para 3 réplicas"
kubectl -n "$NS" scale deployment api-pagamentos --replicas=3
kubectl -n "$NS" rollout status deployment/api-pagamentos --timeout=120s
kubectl -n "$NS" get pods -l app=api-pagamentos -o wide | salvar 05-scale-3-replicas.txt
kubectl -n "$NS" scale deployment api-pagamentos --replicas=2 >/dev/null

kubectl -n "$NS" scale deployment auditoria-service --replicas=1 >/dev/null
kubectl -n "$NS" rollout status deployment/auditoria-service --timeout=120s >/dev/null
kubectl -n "$NS" get pvc | salvar 06-pvc-bound.txt

echo "Teste no Kubernetes concluído."
