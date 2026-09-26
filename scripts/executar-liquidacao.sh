#!/bin/bash

###############################################################################
# Script para Executar Liquidação Manualmente
# Simula o que o CronJob faria no Kubernetes
###############################################################################

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Executando Processo de Liquidação${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd "$(dirname "$0")/../docker"

echo -e "${BLUE}[1/4] Verificando transações pendentes...${NC}"
echo ""
docker exec api-pagamentos cat /var/logs/api/instrucoes.log 2>/dev/null | grep "AGUARDANDO_LIQUIDACAO" || echo "Nenhuma transação pendente"
echo ""

echo -e "${BLUE}[2/4] Parando container auditoria-service...${NC}"
docker compose stop auditoria-service 2>/dev/null || true
echo -e "${GREEN}✓ Container parado${NC}"
echo ""

echo -e "${BLUE}[3/4] Executando processo de liquidação...${NC}"
docker compose run --rm auditoria-service python app.py
echo ""

echo -e "${BLUE}[4/4] Verificando transações após liquidação...${NC}"
echo ""
docker exec api-pagamentos cat /var/logs/api/instrucoes.log 2>/dev/null || echo "Erro ao ler arquivo"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Liquidação concluída!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Verificando saldo da reserva após liquidação:${NC}"
curl -s http://localhost:8080/api/v1/reserva | jq .
