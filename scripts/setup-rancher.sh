#!/usr/bin/env bash
###############################################################################
# Sobe o Rancher em Docker para acompanhar o namespace unifiapay pelo painel.
#
# Uso:
#   RANCHER_BOOTSTRAP_PASSWORD='<senha-forte>' ./scripts/setup-rancher.sh
#
# Variáveis:
#   RANCHER_BOOTSTRAP_PASSWORD  obrigatória: senha do primeiro login (troque no painel)
#   RANCHER_HTTP_PORT           padrão 8081 (a 8080 fica com a api-pagamentos)
#   RANCHER_HTTPS_PORT          padrão 8443
#   RANCHER_VERSION             tag da imagem rancher/rancher (padrão latest)
#
# A senha não é gravada em arquivo nem impressa.
###############################################################################
set -euo pipefail

SENHA="${RANCHER_BOOTSTRAP_PASSWORD:?defina RANCHER_BOOTSTRAP_PASSWORD com a senha do primeiro login}"
HTTP_PORT="${RANCHER_HTTP_PORT:-8081}"
HTTPS_PORT="${RANCHER_HTTPS_PORT:-8443}"
VERSAO="${RANCHER_VERSION:-latest}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker não está rodando" >&2
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx rancher; then
  echo "Container rancher já existe: iniciando"
  docker start rancher >/dev/null
else
  echo "Criando o container rancher (rancher/rancher:${VERSAO})"
  docker run -d \
    --name rancher \
    --restart=unless-stopped \
    -p "${HTTP_PORT}:80" -p "${HTTPS_PORT}:443" \
    -e CATTLE_BOOTSTRAP_PASSWORD="${SENHA}" \
    --privileged \
    "rancher/rancher:${VERSAO}" >/dev/null
fi

echo "Aguardando o Rancher responder em https://localhost:${HTTPS_PORT} (1 a 3 minutos)"
for _ in $(seq 1 60); do
  curl -ksf "https://localhost:${HTTPS_PORT}/ping" >/dev/null 2>&1 && break
  sleep 5
done

cat <<INFO

Rancher em https://localhost:${HTTPS_PORT}
  1. Aceite o certificado autoassinado.
  2. Entre com a senha definida em RANCHER_BOOTSTRAP_PASSWORD e troque-a.
  3. Cluster Management > Import Existing > Generic, nome unifiapay-kind.
  4. Rode no terminal (contexto do kind) o comando kubectl apply gerado pelo painel.
  5. Workloads > Pods e CronJobs, namespace unifiapay.

Parar: docker stop rancher    Remover: docker rm -f rancher
INFO
