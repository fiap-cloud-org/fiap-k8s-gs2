"""
Serviço de Reserva Bancária
Responsável por validar e processar pagamentos conforme regras SPB
"""
import os
import json
from datetime import datetime
from src.utils.logger import setup_logger
from src.utils.file_lock import trava_livro

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
        with trava_livro(self.instrucoes_file, exclusiva=False):
            return self._calcular_saldo_atual()

    def validar_reserva(self, valor):
        """
        Valida se há saldo suficiente na reserva bancária (Regra SPB)

        Args:
            valor: Valor do pagamento PIX

        Returns:
            bool: True se há saldo suficiente, False caso contrário
        """
        return valor <= self.get_resumo_reserva()['disponivel']

    def processar_pagamento(self, valor, chave_destino, descricao=''):
        """
        Processa um pagamento PIX seguindo as regras do SPB

        1. Valida se há saldo na reserva bancária
        2. Registra a instrução de pagamento no livro-razão
        3. Retorna o resultado do processamento

        A validação e o registro acontecem com a trava exclusiva do livro-razão:
        duas réplicas da API não aprovam, ao mesmo tempo, PIX que juntos
        passariam da reserva, e a auditoria não reescreve o arquivo no meio.

        Args:
            valor: Valor do pagamento
            chave_destino: Chave PIX de destino
            descricao: Descrição do pagamento

        Returns:
            dict: Resultado do processamento
        """
        with trava_livro(self.instrucoes_file):
            # 1. PRÉ-VALIDAÇÃO: Verificar reserva bancária (Regra SPB).
            # PIX que ainda aguardam liquidação já estão comprometidos com a
            # reserva: sem descontá-los, vários PIX seguidos passariam do saldo.
            total_liquidado, total_pendente = self._totais_livro()
            disponivel = self.saldo_reserva - total_liquidado - total_pendente
            if valor > disponivel:
                logger.warning(
                    f"Reserva insuficiente. Solicitado: R$ {valor}, "
                    f"Disponível: R$ {disponivel}"
                )
                return {
                    'sucesso': False,
                    'status': 'REJEITADO',
                    'mensagem': 'Reserva bancária insuficiente',
                    'valor_solicitado': valor,
                    'reserva_disponivel': round(disponivel, 2)
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
        Registra a instrução no arquivo de log (Livro-Razão).
        Quem chama já segura a trava exclusiva.

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

    def _totais_livro(self):
        """
        Soma o livro-razão: (total LIQUIDADO, total AGUARDANDO_LIQUIDACAO).
        Quem chama já segura a trava do livro-razão.
        """
        total_liquidado = 0.0
        total_pendente = 0.0
        if not os.path.exists(self.instrucoes_file):
            return total_liquidado, total_pendente

        with open(self.instrucoes_file, 'r') as f:
            for linha in f:
                linha = linha.strip()
                if not linha:
                    continue
                try:
                    transacao = json.loads(linha)
                except json.JSONDecodeError:
                    logger.warning(f"Linha inválida no arquivo de instruções: {linha}")
                    continue
                valor = float(transacao.get('valor', 0))
                if transacao.get('status') == 'LIQUIDADO':
                    total_liquidado += valor
                elif transacao.get('status') == 'AGUARDANDO_LIQUIDACAO':
                    total_pendente += valor
        return total_liquidado, total_pendente

    def _calcular_saldo_atual(self):
        """
        Calcula o saldo atual da reserva bancária.
        Saldo = Reserva Inicial - Soma(Transações LIQUIDADAS)
        Quem chama já segura a trava do livro-razão.

        Returns:
            float: Saldo disponível
        """
        try:
            total_liquidado, _ = self._totais_livro()
            saldo_atual = self.saldo_reserva - total_liquidado
            logger.info(f"Saldo calculado: R$ {saldo_atual:.2f} (Inicial: R$ {self.saldo_reserva:.2f}, Liquidado: R$ {total_liquidado:.2f})")
            return saldo_atual
        except Exception as e:
            logger.error(f"Erro ao calcular saldo: {str(e)}")
            # Em caso de erro, retornar saldo inicial por segurança
            return self.saldo_reserva

    def get_resumo_reserva(self):
        """
        Saldo da reserva, valor já comprometido com PIX aguardando liquidação
        e quanto ainda pode ser usado em novos PIX.
        """
        with trava_livro(self.instrucoes_file, exclusiva=False):
            total_liquidado, total_pendente = self._totais_livro()
        saldo = self.saldo_reserva - total_liquidado
        return {
            'saldo': round(saldo, 2),
            'comprometido': round(total_pendente, 2),
            'disponivel': round(saldo - total_pendente, 2),
        }
