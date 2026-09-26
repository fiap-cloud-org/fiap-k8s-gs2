#!/usr/bin/env bash
###############################################################################
# Publica as imagens no Docker Hub
# Uso: DOCKERHUB_USER=<seu-usuario> ./scripts/push-images.sh [RM]
# Faça "docker login" antes. As imagens precisam ter sido geradas com
# DOCKERHUB_USER definido no build-images.sh.
###############################################################################
set -euo pipefail

RM="${1:-556336}"
VERSION="v1.${RM}"
USUARIO="${DOCKERHUB_USER:?defina DOCKERHUB_USER com o seu usuário do Docker Hub}"

for IMG in api-pagamentos auditoria-service; do
  docker push "${USUARIO}/${IMG}:${VERSION}"
done

echo "Publicadas: ${USUARIO}/api-pagamentos:${VERSION} e ${USUARIO}/auditoria-service:${VERSION}"
echo "Para usar no cluster, troque a imagem nos manifestos de k8s/ por ${USUARIO}/<imagem>:${VERSION}"
