#!/bin/bash

###############################################################################
# Teste do Fluxo Completo SPB - UniFIAP Pay
# Testa: Reserva → PIX → Liquidação → Saldo Atualizado
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

API_URL="http://localhost:8080"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Teste Fluxo Completo SPB${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. Verificar saldo inicial
echo -e "${BLUE}[1/7] Consultando saldo inicial...${NC}"
SALDO_INICIAL=$(curl -s ${API_URL}/api/v1/reserva | jq -r '.reserva_bancaria_saldo')
echo -e "${YELLOW}Saldo Inicial: R\$ ${SALDO_INICIAL}${NC}"
echo ""

# 2. Enviar PIX #1
echo -e "${BLUE}[2/7] Enviando PIX #1 (R\$ 250,00)...${NC}"
PIX1=$(curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{"valor": 250.00, "chave_destino": "cliente.a@exemplo.com", "descricao": "Primeiro PIX"}')
echo "$PIX1" | jq .
TRANSACAO1=$(echo "$PIX1" | jq -r '.transacao_id')
echo -e "${GREEN}✓ Transação criada: ${TRANSACAO1}${NC}"
echo ""

# 3. Verificar saldo (não deve ter mudado ainda)
echo -e "${BLUE}[3/7] Verificando saldo (antes da liquidação)...${NC}"
SALDO_ANTES=$(curl -s ${API_URL}/api/v1/reserva | jq -r '.reserva_bancaria_saldo')
echo -e "${YELLOW}Saldo Atual: R\$ ${SALDO_ANTES} (deve ser igual ao inicial)${NC}"
echo ""

# 4. Executar liquidação
echo -e "${BLUE}[4/7] Executando processo de liquidação...${NC}"
cd "$(dirname "$0")/../docker"
docker compose run --rm auditoria-service python app.py
echo ""

# 5. Verificar saldo após liquidação
echo -e "${BLUE}[5/7] Verificando saldo (após liquidação)...${NC}"
SALDO_DEPOIS=$(curl -s ${API_URL}/api/v1/reserva | jq -r '.reserva_bancaria_saldo')
echo -e "${YELLOW}Saldo Atualizado: R\$ ${SALDO_DEPOIS}${NC}"
echo ""

# 6. Enviar PIX #2
echo -e "${BLUE}[6/7] Enviando PIX #2 (R\$ 150,00)...${NC}"
PIX2=$(curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{"valor": 150.00, "chave_destino": "cliente.b@exemplo.com", "descricao": "Segundo PIX"}')
echo "$PIX2" | jq .
echo ""

# 7. Verificar arquivo de instruções
echo -e "${BLUE}[7/7] Verificando livro-razão (instrucoes.log)...${NC}"
docker exec api-pagamentos cat /var/logs/api/instrucoes.log
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Teste Completo Finalizado!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Resumo:${NC}"
echo "  • Saldo Inicial:     R\$ ${SALDO_INICIAL}"
echo "  • Saldo Antes Liq.:  R\$ ${SALDO_ANTES}"
echo "  • Saldo Após Liq.:   R\$ ${SALDO_DEPOIS}"
echo "  • Diferença:         R\$ $(echo "$SALDO_INICIAL - $SALDO_DEPOIS" | bc)"
echo ""

if [ "$SALDO_DEPOIS" != "$SALDO_INICIAL" ]; then
    echo -e "${GREEN}✓ SUCESSO: Saldo foi atualizado corretamente!${NC}"
else
    echo -e "${RED}✗ ERRO: Saldo não foi atualizado${NC}"
fi
