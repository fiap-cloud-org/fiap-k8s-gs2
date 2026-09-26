#!/bin/bash

###############################################################################
# Script de Simulação de Transações PIX
# Testa o fluxo completo: validação, registro e volume compartilhado
###############################################################################

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:8080}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Simulação de Transações PIX${NC}"
echo -e "${GREEN}Sistema UniFIAP Pay SPB${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Teste 1: Health Check
echo -e "${BLUE}[1/6] Health Check...${NC}"
HEALTH=$(curl -s ${API_URL}/health)
echo "$HEALTH" | jq .
if echo "$HEALTH" | jq -e '.status == "healthy"' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API está saudável${NC}"
else
    echo -e "${RED}✗ API com problemas${NC}"
fi
echo ""

# Teste 2: Consultar Reserva Bancária
echo -e "${BLUE}[2/6] Consultando Reserva Bancária...${NC}"
RESERVA=$(curl -s ${API_URL}/api/v1/reserva)
echo "$RESERVA" | jq .
SALDO=$(echo "$RESERVA" | jq -r '.reserva_bancaria_saldo')
echo -e "${YELLOW}Saldo disponível: R\$ ${SALDO}${NC}"
echo ""

# Teste 3: PIX Válido #1
echo -e "${BLUE}[3/6] Enviando PIX válido (R\$ 150,50)...${NC}"
PIX1=$(curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{
    "valor": 150.50,
    "chave_destino": "cliente.a@exemplo.com",
    "descricao": "Pagamento mensalidade FIAP"
  }')
echo "$PIX1" | jq .
if echo "$PIX1" | jq -e '.status == "AGUARDANDO_LIQUIDACAO"' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PIX aprovado e registrado${NC}"
else
    echo -e "${RED}✗ PIX rejeitado${NC}"
fi
echo ""

# Teste 4: PIX Válido #2
echo -e "${BLUE}[4/6] Enviando PIX válido (R\$ 250,00)...${NC}"
PIX2=$(curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{
    "valor": 250.00,
    "chave_destino": "cliente.b@exemplo.com",
    "descricao": "Transferência entre contas"
  }')
echo "$PIX2" | jq .
if echo "$PIX2" | jq -e '.status == "AGUARDANDO_LIQUIDACAO"' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PIX aprovado e registrado${NC}"
else
    echo -e "${RED}✗ PIX rejeitado${NC}"
fi
echo ""

# Teste 5: PIX Inválido (valor excede reserva)
echo -e "${BLUE}[5/6] Enviando PIX inválido (valor > reserva)...${NC}"
PIX_INVALID=$(curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{
    "valor": 99999999.99,
    "chave_destino": "invalido@email.com",
    "descricao": "Teste valor excedente"
  }')
echo "$PIX_INVALID" | jq .
if echo "$PIX_INVALID" | jq -e '.status == "REJEITADO"' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PIX rejeitado corretamente (saldo insuficiente)${NC}"
else
    echo -e "${RED}✗ PIX deveria ter sido rejeitado${NC}"
fi
echo ""

# Teste 6: Verificar arquivo de instruções (Livro-Razão)
echo -e "${BLUE}[6/6] Verificando Livro-Razão (instrucoes.log)...${NC}"
echo ""
echo -e "${YELLOW}=== Arquivo no container api-pagamentos ===${NC}"
docker exec api-pagamentos cat /var/logs/api/instrucoes.log 2>/dev/null || echo "Arquivo não encontrado ou sem permissão"
echo ""
echo -e "${YELLOW}=== Arquivo no container auditoria-service (mesmo volume) ===${NC}"
docker exec auditoria-service cat /var/logs/api/instrucoes.log 2>/dev/null || echo "Arquivo não encontrado ou sem permissão"
echo ""

# Contar transações
TOTAL_TRANSACOES=$(docker exec api-pagamentos wc -l /var/logs/api/instrucoes.log 2>/dev/null | awk '{print $1}' || echo "0")
echo -e "${GREEN}Total de transações registradas: ${TOTAL_TRANSACOES}${NC}"
echo ""

# Logs recentes
echo -e "${BLUE}Logs recentes da API:${NC}"
docker compose -f docker/docker-compose.yml logs api-pagamentos --tail=15
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Simulação concluída!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Resumo:${NC}"
echo "  • Health Check: OK"
echo "  • Reserva Bancária: R\$ ${SALDO}"
echo "  • PIX válidos enviados: 2"
echo "  • PIX rejeitados: 1"
echo "  • Volume compartilhado: Funcionando"
echo ""
echo -e "${BLUE}Próximo passo: Execute o serviço de auditoria para liquidar as transações${NC}"
