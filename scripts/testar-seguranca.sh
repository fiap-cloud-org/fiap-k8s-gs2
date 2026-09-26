#!/usr/bin/env bash
# Evidências da Etapa 4: bloqueio de Pod inseguro, securityContext e RBAC restrito.
set -uo pipefail
cd "$(dirname "$0")/.."
NS=unifiapay
SA=system:serviceaccount:unifiapay:unifiapay-sa

echo "1) Tentativa de deploy inseguro (deve ser recusada)"
if kubectl apply -f k8s/exemplos/pod-inseguro.yaml 2>&1; then
  echo "ERRO: o Pod inseguro foi aceito" >&2
  kubectl -n "$NS" delete pod pod-inseguro --ignore-not-found
  exit 1
fi

echo
echo "2) securityContext aplicado nos Pods da API"
kubectl -n "$NS" get deploy api-pagamentos \
  -o jsonpath='{.spec.template.spec.securityContext}{"\n"}{.spec.template.spec.containers[0].securityContext}{"\n"}'

echo
echo "3) Permissões da ServiceAccount unifiapay-sa"
for teste in "list pods" "get configmaps" "get secrets" "delete pods" "create deployments" "list secrets"; do
  printf '   can-i %-22s -> ' "$teste"
  # shellcheck disable=SC2086
  kubectl auth can-i $teste -n "$NS" --as "$SA" 2>/dev/null || true
done
