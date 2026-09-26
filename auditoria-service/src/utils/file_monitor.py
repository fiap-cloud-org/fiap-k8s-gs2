"""
Monitor de arquivo para detectar mudanças
"""
import os
from src.utils.logger import setup_logger

logger = setup_logger('file-monitor')

class FileMonitor:
    def __init__(self, filepath):
        """
        Inicializa o monitor de arquivo
        
        Args:
            filepath: Caminho do arquivo a monitorar
        """
        self.filepath = filepath
        self.last_position = 0
        
        # Verificar se arquivo existe e obter posição inicial
        if os.path.exists(filepath):
            self.last_position = os.path.getsize(filepath)
            logger.info(f"Monitor inicializado. Arquivo: {filepath}, Posição: {self.last_position}")
        else:
            logger.warning(f"Arquivo não existe ainda: {filepath}")
    
    def get_new_lines(self):
        """
        Retorna novas linhas adicionadas ao arquivo desde a última leitura
        
        Returns:
            list: Lista de novas linhas
        """
        new_lines = []
        
        if not os.path.exists(self.filepath):
            return new_lines
        
        current_size = os.path.getsize(self.filepath)
        
        # Se arquivo cresceu, ler novas linhas
        if current_size > self.last_position:
            try:
                with open(self.filepath, 'r') as f:
                    f.seek(self.last_position)
                    new_lines = f.readlines()
                    self.last_position = f.tell()
                
                logger.debug(f"Novas linhas detectadas: {len(new_lines)}")
                
            except Exception as e:
                logger.error(f"Erro ao ler novas linhas: {str(e)}")
        
        return new_lines
    
    def reset(self):
        """Reset da posição do monitor para o final do arquivo"""
        if os.path.exists(self.filepath):
            self.last_position = os.path.getsize(self.filepath)
            logger.info(f"Monitor resetado. Nova posição: {self.last_position}")
