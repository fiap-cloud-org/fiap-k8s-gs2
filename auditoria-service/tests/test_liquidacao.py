import json
import threading

import pytest


@pytest.fixture
def servico(tmp_path, monkeypatch):
    monkeypatch.setenv('LOG_PATH', str(tmp_path))
    monkeypatch.setenv('LOG_LEVEL', 'WARNING')
    from src.services.liquidacao_service import LiquidacaoService
    return LiquidacaoService(), tmp_path


def instrucao(i, status='AGUARDANDO_LIQUIDACAO'):
    return {'transacao_id': f'PIX-{i}', 'timestamp': '2025-11-10T10:00:00', 'valor': 10.0 * i,
            'chave_destino': f'c{i}@exemplo.com', 'status': status, 'banco_originador': 'UNIFIAP_PAY'}


def escrever(pasta, itens):
    (pasta / 'instrucoes.log').write_text(''.join(json.dumps(i) + '\n' for i in itens))


def ler(pasta, nome='instrucoes.log'):
    return [json.loads(l) for l in (pasta / nome).read_text().splitlines() if l.strip()]


def test_sem_livro_nao_faz_nada(servico):
    s, _ = servico
    assert s.processar_liquidacoes() == {'processadas': 0, 'erros': 0, 'detalhes': []}


def test_liquida_so_as_pendentes(servico):
    s, pasta = servico
    escrever(pasta, [instrucao(1), instrucao(2, 'LIQUIDADO'), instrucao(3)])
    r = s.processar_liquidacoes()
    assert r['processadas'] == 2
    assert r['detalhes'] == ['PIX-1', 'PIX-3']
    livro = ler(pasta)
    assert [i['status'] for i in livro] == ['LIQUIDADO'] * 3
    assert livro[0]['sistema_liquidacao'] == 'STR_BACEN_SIMULADO'
    assert [l['transacao_id'] for l in ler(pasta, 'liquidacoes.log')] == ['PIX-1', 'PIX-3']


def test_segunda_execucao_nao_liquida_de_novo(servico):
    s, pasta = servico
    escrever(pasta, [instrucao(1)])
    s.processar_liquidacoes()
    assert s.processar_liquidacoes()['processadas'] == 0


def test_pix_gravado_durante_a_liquidacao_nao_se_perde(servico):
    """Com a trava, a API espera a reescrita terminar antes de acrescentar a linha."""
    s, pasta = servico
    escrever(pasta, [instrucao(i) for i in range(1, 200)])
    from src.utils.file_lock import trava_livro
    livro = str(pasta / 'instrucoes.log')

    def api_grava():
        for i in range(200, 260):
            with trava_livro(livro), open(livro, 'a') as f:
                f.write(json.dumps(instrucao(i)) + '\n')

    t = threading.Thread(target=api_grava)
    t.start()
    for _ in range(5):
        s.processar_liquidacoes()
    t.join()
    ids = [i['transacao_id'] for i in ler(pasta)]
    assert len(ids) == 259
    assert len(set(ids)) == 259
