"""
Serviço de Reserva Bancária
Responsável por validar e processar pagamentos conforme regras SPB
"""
import os
import json
from datetime import datetime
from src.utils.logger import setup_logger

logger = setup_logger('reserva-service')

class ReservaService:
    def __init__(self):
        # Ler saldo da reserva bancária do ambiente
        self.saldo_reserva = float(os.getenv('RESERVA_BANCARIA_SALDO', 1000000.00))
        self.log_path = os.getenv('LOG_PATH', '/var/logs/api')
        self.instrucoes_file = f'{self.log_path}/instrucoes.log'
        
        # Garantir que o diretório de logs existe
        os.makedirs(self.log_path, exist_ok=True)
        
        logger.info(f"Reserva Bancária inicializada: R$ {self.saldo_reserva}")
    
    def get_saldo_reserva(self):
        """
        Retorna o saldo disponível na reserva bancária
        Calcula dinamicamente baseado nas transações LIQUIDADAS
        """
        return self._calcular_saldo_atual()
    
    def validar_reserva(self, valor):
        """
        Valida se há saldo suficiente na reserva bancária (Regra SPB)
        Calcula o saldo atual dinamicamente antes de validar
        
        Args:
            valor: Valor do pagamento PIX
            
        Returns:
            bool: True se há saldo suficiente, False caso contrário
        """
        saldo_atual = self._calcular_saldo_atual()
        return valor <= saldo_atual
    
    def processar_pagamento(self, valor, chave_destino, descricao=''):
        """
        Processa um pagamento PIX seguindo as regras do SPB
        
        1. Valida se há saldo na reserva bancária
        2. Registra a instrução de pagamento no livro-razão
        3. Retorna o resultado do processamento
        
        Args:
            valor: Valor do pagamento
            chave_destino: Chave PIX de destino
            descricao: Descrição do pagamento
            
        Returns:
            dict: Resultado do processamento
        """
        # 1. PRÉ-VALIDAÇÃO: Verificar reserva bancária (Regra SPB)
        saldo_atual = self._calcular_saldo_atual()
        if not self.validar_reserva(valor):
            logger.warning(
                f"Reserva insuficiente. Solicitado: R$ {valor}, "
                f"Disponível: R$ {saldo_atual}"
            )
            return {
                'sucesso': False,
                'mensagem': 'Reserva bancária insuficiente',
                'valor_solicitado': valor,
                'reserva_disponivel': saldo_atual
            }
        
        # 2. REGISTRO: Criar instrução de pagamento
        transacao_id = self._gerar_transacao_id()
        instrucao = {
            'transacao_id': transacao_id,
            'timestamp': datetime.now().isoformat(),
            'valor': valor,
            'chave_destino': chave_destino,
            'descricao': descricao,
            'status': 'AGUARDANDO_LIQUIDACAO',
            'banco_originador': 'UNIFIAP_PAY'
        }
        
        # 3. PERSISTÊNCIA: Escrever no livro-razão (instrucoes.log)
        self._registrar_instrucao(instrucao)
        
        logger.info(f"Instrução de pagamento registrada: {transacao_id}")
        
        return {
            'sucesso': True,
            'transacao_id': transacao_id,
            'mensagem': 'Pagamento registrado e aguardando liquidação',
            'valor': valor,
            'status': 'AGUARDANDO_LIQUIDACAO'
        }
    
    def _gerar_transacao_id(self):
        """Gera um ID único para a transação"""
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S%f')
        return f'PIX-{timestamp}'
    
    def _registrar_instrucao(self, instrucao):
        """
        Registra a instrução no arquivo de log (Livro-Razão)
        
        Args:
            instrucao: Dicionário com dados da instrução
        """
        try:
            with open(self.instrucoes_file, 'a') as f:
                f.write(json.dumps(instrucao) + '\n')
            logger.debug(f"Instrução gravada: {instrucao['transacao_id']}")
        except Exception as e:
            logger.error(f"Erro ao registrar instrução: {str(e)}")
            raise
    
    def _calcular_saldo_atual(self):
        """
        Calcula o saldo atual da reserva bancária
        Saldo = Reserva Inicial - Soma(Transações LIQUIDADAS)
        
        Returns:
            float: Saldo disponível
        """
        try:
            # Se o arquivo não existir, retornar saldo inicial
            if not os.path.exists(self.instrucoes_file):
                return self.saldo_reserva
            
            total_liquidado = 0.0
            
            # Ler todas as transações do arquivo
            with open(self.instrucoes_file, 'r') as f:
                for linha in f:
                    linha = linha.strip()
                    if not linha:
                        continue
                    
                    try:
                        transacao = json.loads(linha)
                        # Somar apenas transações LIQUIDADAS
                        if transacao.get('status') == 'LIQUIDADO':
                            total_liquidado += float(transacao.get('valor', 0))
                    except json.JSONDecodeError:
                        logger.warning(f"Linha inválida no arquivo de instruções: {linha}")
                        continue
            
            saldo_atual = self.saldo_reserva - total_liquidado
            logger.info(f"💰 Saldo calculado: R$ {saldo_atual:.2f} (Inicial: R$ {self.saldo_reserva:.2f}, Liquidado: R$ {total_liquidado:.2f})")
            
            return saldo_atual
            
        except Exception as e:
            logger.error(f"Erro ao calcular saldo: {str(e)}")
            # Em caso de erro, retornar saldo inicial por segurança
            return self.saldo_reserva
