#!/usr/bin/env bash
# Cria (ou atualiza) o Secret unifiapay-secrets no namespace unifiapay a partir
# do docker/pix.key local. Se o arquivo não existir, gera uma chave aleatória.
# O valor nunca fica versionado: o manifesto k8s/03-secret.example.yaml é só referência.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f docker/pix.key ] || ./scripts/preparar-ambiente.sh >/dev/null

kubectl create secret generic unifiapay-secrets \
  --namespace unifiapay \
  --from-file=pix.key=docker/pix.key \
  --dry-run=client -o yaml \
  | kubectl label --local -f - app=unifiapay -o yaml \
  | kubectl apply -f -
