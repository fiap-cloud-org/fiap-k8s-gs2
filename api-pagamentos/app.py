"""
API de Pagamentos - UniFIAP Pay
Simula o Banco Originador no Sistema SPB
"""
from flask import Flask, request, jsonify
from src.services.reserva_service import ReservaService
from src.utils.logger import setup_logger
import os

app = Flask(__name__)
logger = setup_logger('api-pagamentos')

# Inicializar serviço de reserva
reserva_service = ReservaService()

@app.route('/health', methods=['GET'])
def health():
    """Endpoint de health check"""
    return jsonify({
        'status': 'healthy',
        'service': 'api-pagamentos',
        'reserva_disponivel': reserva_service.get_saldo_reserva()
    }), 200

@app.route('/api/v1/pix', methods=['POST'])
def processar_pix():
    """
    Processa uma transação PIX
    
    Payload esperado:
    {
        "valor": 100.50,
        "chave_destino": "exemplo@email.com",
        "descricao": "Pagamento exemplo"
    }
    """
    try:
        data = request.get_json()
        
        # Validar campos obrigatórios
        if not data or 'valor' not in data or 'chave_destino' not in data:
            return jsonify({
                'erro': 'Campos obrigatórios: valor, chave_destino'
            }), 400
        
        valor = float(data['valor'])
        chave_destino = data['chave_destino']
        descricao = data.get('descricao', '')
        
        # Validar valor
        if valor <= 0:
            return jsonify({
                'erro': 'Valor deve ser maior que zero'
            }), 400
        
        # Processar pagamento através do serviço de reserva
        resultado = reserva_service.processar_pagamento(
            valor=valor,
            chave_destino=chave_destino,
            descricao=descricao
        )
        
        if resultado['sucesso']:
            logger.info(f"PIX processado: {resultado['transacao_id']} - Valor: R$ {valor}")
            return jsonify(resultado), 201
        else:
            logger.warning(f"PIX rejeitado: {resultado['mensagem']}")
            return jsonify(resultado), 400
            
    except ValueError as e:
        logger.error(f"Erro de validação: {str(e)}")
        return jsonify({'erro': 'Valor inválido'}), 400
    except Exception as e:
        logger.error(f"Erro ao processar PIX: {str(e)}")
        return jsonify({'erro': 'Erro interno do servidor'}), 500

@app.route('/api/v1/reserva', methods=['GET'])
def consultar_reserva():
    """Consulta o saldo da reserva bancária"""
    try:
        saldo = reserva_service.get_saldo_reserva()
        return jsonify({
            'reserva_bancaria_saldo': saldo,
            'moeda': 'BRL'
        }), 200
    except Exception as e:
        logger.error(f"Erro ao consultar reserva: {str(e)}")
        return jsonify({'erro': 'Erro ao consultar reserva'}), 500

if __name__ == '__main__':
    port = int(os.getenv('API_PORT', 8080))
    host = os.getenv('API_HOST', '0.0.0.0')
    
    logger.info(f"Iniciando API de Pagamentos em {host}:{port}")
    logger.info(f"Reserva Bancária: R$ {reserva_service.get_saldo_reserva()}")
    
    app.run(host=host, port=port, debug=False)
