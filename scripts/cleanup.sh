#!/bin/bash

###############################################################################
# Script de Cleanup - Remove todos os recursos do Kubernetes
# Uso: ./cleanup.sh
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Cleanup - UniFIAP Pay SPB${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${RED}ATENÇÃO: Isso irá remover todos os recursos do namespace unifiapay${NC}"
echo ""
read -p "Tem certeza? (digite 'yes' para confirmar): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Cancelado pelo usuário${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Removendo recursos...${NC}"

# Deletar namespace (isso remove todos os recursos dentro dele)
kubectl delete namespace unifiapay --ignore-not-found=true

echo ""
echo -e "${GREEN}✓ Cleanup concluído!${NC}"
echo ""
echo "Todos os recursos do namespace 'unifiapay' foram removidos."
