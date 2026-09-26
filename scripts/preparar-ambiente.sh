#!/usr/bin/env bash
# Cria os arquivos locais que não vão para o git:
#   docker/.env     a partir do docker/.env.example
#   docker/pix.key  chave PIX de simulação aleatória
set -euo pipefail
cd "$(dirname "$0")/../docker"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "docker/.env criado a partir do .env.example"
else
  echo "docker/.env já existe, mantido"
fi

if [ ! -f pix.key ]; then
  {
    echo "-----BEGIN PIX SIMULATION KEY-----"
    python3 -c "import uuid; print('UNIFIAP-PAY-' + str(uuid.uuid4()).upper())"
    echo "-----END PIX SIMULATION KEY-----"
  } > pix.key
  chmod 600 pix.key
  echo "docker/pix.key gerado (chave aleatória de simulação)"
else
  echo "docker/pix.key já existe, mantido"
fi
