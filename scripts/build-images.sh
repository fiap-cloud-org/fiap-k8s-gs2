#!/usr/bin/env bash
###############################################################################
# Build das imagens (multi-stage) com a tag v1.<RM>
# Uso: ./scripts/build-images.sh [RM]          (padrão: 556336)
#
# Variáveis opcionais:
#   DOCKERHUB_USER  também marca as imagens como <usuario>/<imagem>:v1.<RM>
#   KIND_CLUSTER    carrega as imagens no cluster kind com esse nome
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

RM="${1:-556336}"
VERSION="v1.${RM}"

for IMG in api-pagamentos auditoria-service; do
  TAGS=(-t "${IMG}:${VERSION}")
  [ -n "${DOCKERHUB_USER:-}" ] && TAGS+=(-t "${DOCKERHUB_USER}/${IMG}:${VERSION}")
  echo "Build de ${IMG}:${VERSION}"
  docker build "${TAGS[@]}" "./${IMG}"
done

if [ -n "${KIND_CLUSTER:-}" ]; then
  echo "Carregando as imagens no kind (${KIND_CLUSTER})"
  kind load docker-image "api-pagamentos:${VERSION}" "auditoria-service:${VERSION}" --name "${KIND_CLUSTER}"
fi

docker images --filter "reference=*:${VERSION}" --filter "reference=*/*:${VERSION}"
