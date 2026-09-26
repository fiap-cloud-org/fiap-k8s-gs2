"""
Serviço de Auditoria - UniFIAP Pay
Simula o Sistema de Liquidação (BACEN/STR) no SPB
"""
import time
import os
from src.services.liquidacao_service import LiquidacaoService
from src.utils.logger import setup_logger

logger = setup_logger('auditoria-service')

def main():
    """
    Processo principal de auditoria e liquidação
    
    Executado periodicamente via CronJob (a cada 6h)
    Monitora o livro-razão e processa liquidações
    """
    logger.info("=== Iniciando Serviço de Auditoria e Liquidação ===")
    
    # Inicializar serviço de liquidação
    liquidacao_service = LiquidacaoService()
    
    # Verificar modo de execução
    modo = os.getenv('EXECUTION_MODE', 'once')
    intervalo = int(os.getenv('MONITORING_INTERVAL', 300))  # 5 minutos padrão
    
    if modo == 'continuous':
        # Modo contínuo (para testes locais)
        logger.info(f"Modo contínuo ativado. Intervalo: {intervalo}s")
        
        while True:
            try:
                processar_liquidacoes(liquidacao_service)
                time.sleep(intervalo)
            except KeyboardInterrupt:
                logger.info("Serviço interrompido pelo usuário")
                break
            except Exception as e:
                logger.error(f"Erro no loop contínuo: {str(e)}")
                time.sleep(intervalo)
    else:
        # Modo single execution (para CronJob)
        logger.info("Modo execução única (CronJob)")
        processar_liquidacoes(liquidacao_service)
    
    logger.info("=== Serviço de Auditoria Finalizado ===")

def processar_liquidacoes(liquidacao_service):
    """
    Processa as liquidações pendentes
    
    Args:
        liquidacao_service: Instância do serviço de liquidação
    """
    try:
        resultado = liquidacao_service.processar_liquidacoes()
        
        logger.info(f"Liquidações processadas: {resultado['processadas']}")
        logger.info(f"Erros encontrados: {resultado['erros']}")
        
        if resultado['detalhes']:
            logger.info("Transações liquidadas:")
            for transacao in resultado['detalhes']:
                logger.info(f"  - {transacao}")
        else:
            logger.info("Nenhuma transação pendente de liquidação")
            
    except Exception as e:
        logger.error(f"Erro ao processar liquidações: {str(e)}")
        raise

if __name__ == '__main__':
    main()
