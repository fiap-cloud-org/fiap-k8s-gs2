"""
Configuração de Logger para os serviços
"""
import logging
import os

def setup_logger(name):
    """
    Configura e retorna um logger
    
    Args:
        name: Nome do logger
        
    Returns:
        logging.Logger: Logger configurado
    """
    log_level = os.getenv('LOG_LEVEL', 'INFO')
    
    # Criar logger
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, log_level))
    
    # Evitar duplicação de handlers
    if logger.handlers:
        return logger
    
    # Criar handler para console
    console_handler = logging.StreamHandler()
    console_handler.setLevel(getattr(logging, log_level))
    
    # Formato do log
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    console_handler.setFormatter(formatter)
    
    # Adicionar handler ao logger
    logger.addHandler(console_handler)
    
    return logger
