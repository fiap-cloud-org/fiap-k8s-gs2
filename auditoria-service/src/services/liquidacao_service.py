"""
Serviço de Liquidação
Responsável por processar e liquidar transações PIX (Simula BACEN/STR)
"""
import os
import json
from datetime import datetime
from src.utils.file_monitor import FileMonitor
from src.utils.logger import setup_logger

logger = setup_logger('liquidacao-service')

class LiquidacaoService:
    def __init__(self):
        self.log_path = os.getenv('LOG_PATH', '/var/logs/api')
        self.instrucoes_file = f'{self.log_path}/instrucoes.log'
        self.liquidacoes_file = f'{self.log_path}/liquidacoes.log'
        
        # Garantir que o diretório existe
        os.makedirs(self.log_path, exist_ok=True)
        
        # Inicializar monitor de arquivo
        self.file_monitor = FileMonitor(self.instrucoes_file)
        
        logger.info("Serviço de Liquidação inicializado")
        logger.info(f"Monitorando: {self.instrucoes_file}")
    
    def processar_liquidacoes(self):
        """
        Processa todas as transações pendentes de liquidação
        
        Lê o livro-razão, identifica transações AGUARDANDO_LIQUIDACAO
        e atualiza o status para LIQUIDADO no próprio arquivo
        
        Returns:
            dict: Resultado do processamento
        """
        resultado = {
            'processadas': 0,
            'erros': 0,
            'detalhes': []
        }
        
        # Ler todas as instruções do arquivo
        instrucoes = self._ler_instrucoes()
        
        if not instrucoes:
            logger.info("Nenhuma instrução encontrada no livro-razão")
            return resultado
        
        logger.info(f"Total de instruções no livro-razão: {len(instrucoes)}")
        
        instrucoes_atualizadas = []
        
        # Processar cada instrução
        for instrucao in instrucoes:
            try:
                if instrucao.get('status') == 'AGUARDANDO_LIQUIDACAO':
                    # Atualizar status para LIQUIDADO
                    instrucao['status'] = 'LIQUIDADO'
                    instrucao['timestamp_liquidacao'] = datetime.now().isoformat()
                    instrucao['sistema_liquidacao'] = 'STR_BACEN_SIMULADO'
                    
                    self._liquidar_transacao(instrucao)
                    resultado['processadas'] += 1
                    resultado['detalhes'].append(instrucao['transacao_id'])
                
                instrucoes_atualizadas.append(instrucao)
                    
            except Exception as e:
                logger.error(f"Erro ao liquidar transação {instrucao.get('transacao_id')}: {str(e)}")
                resultado['erros'] += 1
                instrucoes_atualizadas.append(instrucao)  # Manter original em caso de erro
        
        # Reescrever o arquivo com as transações atualizadas
        if resultado['processadas'] > 0:
            logger.info(f"Atualizando arquivo com {len(instrucoes_atualizadas)} transações...")
            try:
                self._atualizar_arquivo_instrucoes(instrucoes_atualizadas)
                logger.info("✓ Arquivo atualizado com sucesso!")
            except Exception as e:
                logger.error(f"✗ ERRO ao atualizar arquivo: {str(e)}")
                raise
        
        return resultado
    
    def _ler_instrucoes(self):
        """
        Lê todas as instruções do livro-razão
        
        Returns:
            list: Lista de instruções (dicionários)
        """
        instrucoes = []
        
        if not os.path.exists(self.instrucoes_file):
            logger.warning(f"Arquivo de instruções não encontrado: {self.instrucoes_file}")
            return instrucoes
        
        try:
            with open(self.instrucoes_file, 'r') as f:
                for linha in f:
                    linha = linha.strip()
                    if linha:
                        try:
                            instrucao = json.loads(linha)
                            instrucoes.append(instrucao)
                        except json.JSONDecodeError as e:
                            logger.error(f"Erro ao decodificar linha: {linha[:50]}... - {str(e)}")
            
            logger.debug(f"Total de instruções lidas: {len(instrucoes)}")
            
        except Exception as e:
            logger.error(f"Erro ao ler arquivo de instruções: {str(e)}")
            raise
        
        return instrucoes
    
    def _liquidar_transacao(self, instrucao):
        """
        Liquida uma transação individual
        
        Atualiza o status para LIQUIDADO e registra em arquivo separado
        
        Args:
            instrucao: Dicionário com dados da instrução
        """
        transacao_id = instrucao['transacao_id']
        
        # Criar registro de liquidação
        liquidacao = {
            'transacao_id': transacao_id,
            'timestamp_original': instrucao['timestamp'],
            'timestamp_liquidacao': datetime.now().isoformat(),
            'valor': instrucao['valor'],
            'chave_destino': instrucao['chave_destino'],
            'banco_originador': instrucao.get('banco_originador', 'DESCONHECIDO'),
            'status': 'LIQUIDADO',
            'sistema': 'STR_BACEN_SIMULADO'
        }
        
        # Registrar liquidação
        self._registrar_liquidacao(liquidacao)
        
        logger.info(
            f"Transação liquidada: {transacao_id} - "
            f"Valor: R$ {instrucao['valor']} - "
            f"Destino: {instrucao['chave_destino']}"
        )
    
    def _registrar_liquidacao(self, liquidacao):
        """
        Registra a liquidação em arquivo separado
        
        Args:
            liquidacao: Dicionário com dados da liquidação
        """
        try:
            with open(self.liquidacoes_file, 'a') as f:
                f.write(json.dumps(liquidacao) + '\n')
            
            logger.debug(f"Liquidação registrada: {liquidacao['transacao_id']}")
            
        except Exception as e:
            logger.error(f"Erro ao registrar liquidação: {str(e)}")
            raise
    
    def _atualizar_arquivo_instrucoes(self, instrucoes):
        """
        Reescreve o arquivo de instruções com as transações atualizadas
        
        Args:
            instrucoes: Lista de instruções atualizadas
        """
        try:
            with open(self.instrucoes_file, 'w') as f:
                for instrucao in instrucoes:
                    f.write(json.dumps(instrucao) + '\n')
            
            logger.info(f"Arquivo de instruções atualizado: {len(instrucoes)} transações")
            
        except Exception as e:
            logger.error(f"Erro ao atualizar arquivo de instruções: {str(e)}")
            raise
