#!/bin/bash

###############################################################################
# Script de Push das Imagens para Docker Hub
# Uso: ./push-images.sh <SEU_RM>
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
echo -e "${GREEN}Push das Imagens - Docker Hub${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "RM: ${YELLOW}${RM}${NC}"
echo -e "Versão: ${YELLOW}${VERSION}${NC}"
echo -e "Docker Hub User: ${YELLOW}${DOCKERHUB_USER}${NC}"
echo ""

# Verificar se está logado no Docker Hub
echo -e "${YELLOW}Verificando login no Docker Hub...${NC}"
if ! docker info | grep -q "Username"; then
    echo -e "${YELLOW}Faça login no Docker Hub:${NC}"
    docker login
fi

echo ""

# Push da API de Pagamentos
echo -e "${GREEN}[1/2] Pushing api-pagamentos...${NC}"
docker push ${DOCKERHUB_USER}/api-pagamentos:${VERSION}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ api-pagamentos:${VERSION} push concluído${NC}"
else
    echo -e "${RED}✗ Erro no push da api-pagamentos${NC}"
    exit 1
fi

echo ""

# Push do Serviço de Auditoria
echo -e "${GREEN}[2/2] Pushing auditoria-service...${NC}"
docker push ${DOCKERHUB_USER}/auditoria-service:${VERSION}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ auditoria-service:${VERSION} push concluído${NC}"
else
    echo -e "${RED}✗ Erro no push da auditoria-service${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Push concluído com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Imagens disponíveis no Docker Hub:"
echo "  - ${DOCKERHUB_USER}/api-pagamentos:${VERSION}"
echo "  - ${DOCKERHUB_USER}/auditoria-service:${VERSION}"
echo ""
echo -e "${YELLOW}Próximo passo:${NC}"
echo "  Atualize os manifests Kubernetes (k8s/*.yaml) com:"
echo "    - Substitua 'seu-dockerhub-user' por '${DOCKERHUB_USER}'"
echo "    - Substitua 'RM_PLACEHOLDER' por '${RM}'"
echo ""
echo "  Depois execute:"
echo "    ./scripts/deploy-k8s.sh"
