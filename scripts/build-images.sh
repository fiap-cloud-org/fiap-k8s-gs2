#!/bin/bash

###############################################################################
# Script de Build das Imagens Docker
# Uso: ./build-images.sh <SEU_RM>
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se RM foi fornecido
if [ -z "$1" ]; then
    echo -e "${RED}Erro: RM não fornecido${NC}"
    echo "Uso: $0 <SEU_RM>"
    echo "Exemplo: $0 12345"
    exit 1
fi

RM=$1
VERSION="v1.${RM}"
DOCKERHUB_USER="${DOCKERHUB_USER:-seu-dockerhub-user}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build das Imagens Docker - UniFIAP Pay${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "RM: ${YELLOW}${RM}${NC}"
echo -e "Versão: ${YELLOW}${VERSION}${NC}"
echo -e "Docker Hub User: ${YELLOW}${DOCKERHUB_USER}${NC}"
echo ""

# Build da API de Pagamentos
echo -e "${GREEN}[1/2] Building api-pagamentos...${NC}"
docker build \
    -t ${DOCKERHUB_USER}/api-pagamentos:${VERSION} \
    -t ${DOCKERHUB_USER}/api-pagamentos:latest \
    ./api-pagamentos

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ api-pagamentos build concluído com sucesso${NC}"
else
    echo -e "${RED}✗ Erro no build da api-pagamentos${NC}"
    exit 1
fi

echo ""

# Build do Serviço de Auditoria
echo -e "${GREEN}[2/2] Building auditoria-service...${NC}"
docker build \
    -t ${DOCKERHUB_USER}/auditoria-service:${VERSION} \
    -t ${DOCKERHUB_USER}/auditoria-service:latest \
    ./auditoria-service

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ auditoria-service build concluído com sucesso${NC}"
else
    echo -e "${RED}✗ Erro no build da auditoria-service${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Build concluído com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Imagens criadas:"
echo "  - ${DOCKERHUB_USER}/api-pagamentos:${VERSION}"
echo "  - ${DOCKERHUB_USER}/auditoria-service:${VERSION}"
echo ""
echo -e "${YELLOW}Próximo passo:${NC}"
echo "  1. Execute docker scout para verificar vulnerabilidades:"
echo "     docker scout cves ${DOCKERHUB_USER}/api-pagamentos:${VERSION}"
echo "     docker scout cves ${DOCKERHUB_USER}/auditoria-service:${VERSION}"
echo ""
echo "  2. Execute o push das imagens:"
echo "     ./scripts/push-images.sh ${RM}"
