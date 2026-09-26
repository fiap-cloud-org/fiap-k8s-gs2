"""
Trava de arquivo para o livro-razão (instrucoes.log).

A api-pagamentos acrescenta linhas enquanto a auditoria reescreve o arquivo
inteiro na liquidação. Sem trava, um PIX gravado no meio da reescrita some.
As duas pontas usam o mesmo arquivo de trava no volume compartilhado.
"""
import fcntl
from contextlib import contextmanager


@contextmanager
def trava_livro(caminho_livro, exclusiva=True):
    """Segura uma trava (flock) em <caminho_livro>.lock durante o bloco."""
    with open(f'{caminho_livro}.lock', 'a') as trava:
        fcntl.flock(trava, fcntl.LOCK_EX if exclusiva else fcntl.LOCK_SH)
        try:
            yield
        finally:
            fcntl.flock(trava, fcntl.LOCK_UN)
