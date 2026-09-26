import importlib
import json
import threading

import pytest


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv('LOG_PATH', str(tmp_path))
    monkeypatch.setenv('RESERVA_BANCARIA_SALDO', '1000.00')
    monkeypatch.setenv('LOG_LEVEL', 'WARNING')
    import app as app_module
    importlib.reload(app_module)
    app_module.app.testing = True
    return app_module.app.test_client(), tmp_path


def ler_livro(pasta):
    return [json.loads(l) for l in (pasta / 'instrucoes.log').read_text().splitlines() if l.strip()]


def test_health(client):
    c, _ = client
    r = c.get('/health')
    assert r.status_code == 200
    assert r.json['status'] == 'healthy'
    assert r.json['reserva_disponivel'] == 1000.0


def test_pix_valido_grava_no_livro_razao(client):
    c, pasta = client
    r = c.post('/api/v1/pix', json={'valor': 250, 'chave_destino': 'cliente@exemplo.com'})
    assert r.status_code == 201
    assert r.json['status'] == 'AGUARDANDO_LIQUIDACAO'
    livro = ler_livro(pasta)
    assert len(livro) == 1
    assert livro[0]['transacao_id'] == r.json['transacao_id']
    assert livro[0]['banco_originador'] == 'UNIFIAP_PAY'


@pytest.mark.parametrize('corpo', [{}, {'valor': 10}, {'chave_destino': 'x'}, {'valor': 0, 'chave_destino': 'x'},
                                   {'valor': -5, 'chave_destino': 'x'}, {'valor': 'abc', 'chave_destino': 'x'}])
def test_pix_invalido_retorna_400(client, corpo):
    c, _ = client
    assert c.post('/api/v1/pix', json=corpo).status_code == 400


def test_pix_acima_da_reserva_e_rejeitado(client):
    c, pasta = client
    r = c.post('/api/v1/pix', json={'valor': 1000.01, 'chave_destino': 'x@exemplo.com'})
    assert r.status_code == 400
    assert r.json['status'] == 'REJEITADO'
    assert not (pasta / 'instrucoes.log').exists()


def test_pendentes_comprometem_a_reserva(client):
    c, _ = client
    assert c.post('/api/v1/pix', json={'valor': 600, 'chave_destino': 'a@exemplo.com'}).status_code == 201
    r = c.post('/api/v1/pix', json={'valor': 600, 'chave_destino': 'b@exemplo.com'})
    assert r.status_code == 400
    assert r.json['reserva_disponivel'] == 400.0
    reserva = c.get('/api/v1/reserva').json
    assert reserva == {'reserva_bancaria_saldo': 1000.0, 'reserva_comprometida': 600.0,
                       'reserva_disponivel_para_pix': 400.0, 'moeda': 'BRL'}


def test_saldo_cai_so_depois_da_liquidacao(client):
    c, pasta = client
    c.post('/api/v1/pix', json={'valor': 300, 'chave_destino': 'a@exemplo.com'})
    assert c.get('/api/v1/reserva').json['reserva_bancaria_saldo'] == 1000.0
    # simula a auditoria marcando como liquidado
    livro = ler_livro(pasta)
    livro[0]['status'] = 'LIQUIDADO'
    (pasta / 'instrucoes.log').write_text(json.dumps(livro[0]) + '\n')
    reserva = c.get('/api/v1/reserva').json
    assert reserva['reserva_bancaria_saldo'] == 700.0
    assert reserva['reserva_comprometida'] == 0.0


def test_pix_concorrentes_nao_passam_da_reserva(client):
    c, pasta = client
    from src.services.reserva_service import ReservaService
    servicos = [ReservaService() for _ in range(4)]  # como se fossem 4 réplicas
    resultados = []

    def enviar(s):
        for _ in range(5):
            resultados.append(s.processar_pagamento(100, 'x@exemplo.com')['sucesso'])

    threads = [threading.Thread(target=enviar, args=(s,)) for s in servicos]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert resultados.count(True) == 10  # 10 x R$ 100 = reserva de R$ 1000
    assert len(ler_livro(pasta)) == 10
