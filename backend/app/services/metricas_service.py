"""Métricas pedagógicas DTAE (RF-031, RF-032, RF-033).

Regras (docs/03_modelo_relacional.md, seção 6):
- Só entram sessões CONCLUIDAS com nota (avaliacao_sessao); parciais são ignoradas.
- Status: média das últimas `notas_janela` notas; CINZA com menos de `minimo_notas`.
- Limiares e alertas vêm da tabela config_metricas.
"""
import logging
from dataclasses import dataclass
from fastapi import HTTPException
from ..core.database import get_db_connection
from ..schemas.metricas_schema import (
    MetricasAlunoResponse,
    MetricasTurmaResponse,
    AlertaPedagógicoResponse,
    SessaoHistoricoResponse,
)

logger = logging.getLogger(__name__)

HISTORICO_MAXIMO = 10


@dataclass
class _ConfigMetricas:
    notas_janela: int = 3
    minimo_notas: int = 2
    limiar_amarelo: float = 50.0
    limiar_verde: float = 75.0
    alerta_queda: float = 20.0
    alerta_mesma_posicao: int = 3


def _carregar_config(cur) -> _ConfigMetricas:
    cur.execute(
        """
        SELECT notas_janela, minimo_notas, limiar_amarelo, limiar_verde, alerta_queda, alerta_mesma_posicao
        FROM config_metricas WHERE id = 1
        """
    )
    r = cur.fetchone()
    if not r:
        return _ConfigMetricas()
    return _ConfigMetricas(int(r[0]), int(r[1]), float(r[2]), float(r[3]), float(r[4]), int(r[5]))


def _status(media: float | None, quantidade: int, cfg: _ConfigMetricas) -> tuple[str, str]:
    if quantidade == 0:
        return "CINZA", "Nenhuma atividade concluída ainda."
    if quantidade < cfg.minimo_notas:
        faltam = cfg.minimo_notas - quantidade
        return "CINZA", f"Dados insuficientes: falta{'m' if faltam > 1 else ''} {faltam} atividade{'s' if faltam > 1 else ''} concluída{'s' if faltam > 1 else ''} para definir o status."
    if media >= cfg.limiar_verde:
        return "VERDE", "Faz com autonomia; pode avançar."
    if media >= cfg.limiar_amarelo:
        return "AMARELO", "Em desenvolvimento; repetir com dicas."
    return "VERMELHO", "Precisa de mais apoio; voltar uma etapa."


def _alertas_fichas_dificeis(cur, aluno_id: str, cfg: _ConfigMetricas) -> list[AlertaPedagógicoResponse]:
    """Ficha esperada errada em >= alerta_mesma_posicao atividades diferentes."""
    cur.execute(
        """
        WITH erros AS (
            SELECT fe.simbolo AS esperada, fa_.simbolo AS apresentada, s.atividade_id
            FROM leitura_ficha lf
            JOIN tentativa t ON t.id = lf.tentativa_id
            JOIN execucao_alvo ea ON ea.id = t.execucao_alvo_id
            JOIN fase_alvo fa ON fa.id = ea.fase_alvo_id
            JOIN fase_atividade f ON f.id = fa.fase_id
            JOIN sessao_atividade s ON s.id = ea.sessao_id
            JOIN ficha fe ON fe.id = lf.ficha_esperada_id
            JOIN ficha fa_ ON fa_.id = lf.ficha_apresentada_id
            WHERE s.aluno_id::text = %s AND NOT lf.correta AND f.tipo_fase <> 'EXPLORAR'
        )
        SELECT esperada,
               count(DISTINCT atividade_id) AS atividades,
               count(*) AS erros,
               mode() WITHIN GROUP (ORDER BY apresentada) AS troca_mais_comum
        FROM erros
        GROUP BY esperada
        HAVING count(DISTINCT atividade_id) >= %s
        ORDER BY atividades DESC, erros DESC
        """,
        (aluno_id, cfg.alerta_mesma_posicao),
    )
    return [
        AlertaPedagógicoResponse(
            tipo="FICHA_DIFICIL",
            titulo=f"Dificuldade recorrente com a ficha {esperada}",
            mensagem=(
                f"Errou a ficha {esperada} em {atividades} atividades diferentes ({erros} erros). "
                f"Troca mais comum: apresentou {troca} no lugar."
            ),
        )
        for esperada, atividades, erros, troca in cur.fetchall()
    ]


def _metricas_aluno(cur, aluno_id: str, aluno_nome: str, turma_nome: str, cfg: _ConfigMetricas) -> MetricasAlunoResponse:
    cur.execute(
        """
        SELECT count(*) FROM sessao_atividade s
        JOIN avaliacao_sessao av ON av.sessao_id = s.id
        WHERE s.aluno_id::text = %s AND s.status = 'CONCLUIDA'
        """,
        (aluno_id,),
    )
    total_concluidas = int(cur.fetchone()[0])

    cur.execute(
        """
        SELECT s.id::text, at.titulo, m.nome, s.encerrada_em, av.nota,
               (SELECT round(100.0 * count(*) FILTER (WHERE lf.correta) / NULLIF(count(*), 0), 1)
                FROM leitura_ficha lf
                JOIN tentativa t ON t.id = lf.tentativa_id
                JOIN execucao_alvo ea ON ea.id = t.execucao_alvo_id
                JOIN fase_alvo fa ON fa.id = ea.fase_alvo_id
                JOIN fase_atividade f ON f.id = fa.fase_id
                WHERE ea.sessao_id = s.id AND f.pontuavel)
        FROM sessao_atividade s
        JOIN avaliacao_sessao av ON av.sessao_id = s.id
        JOIN atividade at ON at.id = s.atividade_id
        JOIN modulo m ON m.id = at.modulo_id
        WHERE s.aluno_id::text = %s AND s.status = 'CONCLUIDA'
        ORDER BY s.encerrada_em DESC, s.id DESC
        LIMIT %s
        """,
        (aluno_id, max(HISTORICO_MAXIMO, cfg.notas_janela)),
    )
    historico = [
        SessaoHistoricoResponse(
            sessao_id=r[0],
            atividade_titulo=(r[1] or "").replace("[DEMONSTRACAO]", "").strip(),
            modulo_nome=r[2],
            data=r[3].isoformat() if r[3] else "",
            nota=float(r[4]),
            percentual_acertos=float(r[5]) if r[5] is not None else None,
        )
        for r in cur.fetchall()
    ]

    ultimas_notas = [h.nota for h in historico[: cfg.notas_janela]]
    media = round(sum(ultimas_notas) / len(ultimas_notas), 1) if ultimas_notas else None
    status_colorido, descricao = _status(media, len(ultimas_notas), cfg)

    alertas: list[AlertaPedagógicoResponse] = []
    if len(ultimas_notas) >= 2 and (ultimas_notas[1] - ultimas_notas[0]) >= cfg.alerta_queda:
        alertas.append(
            AlertaPedagógicoResponse(
                tipo="QUEDA_RECENTE",
                titulo="Queda recente no desempenho",
                mensagem=(
                    f"A última nota ({ultimas_notas[0]:.1f}) caiu {ultimas_notas[1] - ultimas_notas[0]:.1f} pontos "
                    f"em relação à anterior ({ultimas_notas[1]:.1f})."
                ),
            )
        )
    if len(ultimas_notas) >= 3 and ultimas_notas[0] > ultimas_notas[1] > ultimas_notas[2]:
        alertas.append(
            AlertaPedagógicoResponse(
                tipo="EVOLUCAO",
                titulo="Evolução contínua",
                mensagem="As 3 últimas notas foram crescentes.",
            )
        )
    alertas.extend(_alertas_fichas_dificeis(cur, aluno_id, cfg))

    return MetricasAlunoResponse(
        aluno_id=aluno_id,
        aluno_nome=aluno_nome,
        turma_nome=turma_nome,
        status_colorido=status_colorido,
        descricao_status=descricao,
        media_notas=media,
        total_sessoes_concluidas=total_concluidas,
        ultimas_notas=ultimas_notas,
        historico=historico,
        notas_janela=cfg.notas_janela,
        minimo_notas=cfg.minimo_notas,
        alertas=alertas,
    )


def _erro_banco(e: Exception) -> HTTPException:
    logger.exception("Falha ao calcular métricas: %s", e)
    return HTTPException(
        status_code=503,
        detail="Não foi possível calcular as métricas: banco de dados indisponível.",
    )


def calcular_metricas_aluno(professor_id: str, aluno_id: str) -> MetricasAlunoResponse:
    """Status colorido, histórico e alertas de um aluno (RF-031, RF-032)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT a.nome || ' ' || a.sobrenome, t.nome
                    FROM aluno a
                    JOIN turma t ON a.turma_atual_id = t.id
                    WHERE a.id::text = %s AND t.professor_id::text = %s
                    """,
                    (aluno_id, professor_id),
                )
                aluno_row = cur.fetchone()
                if not aluno_row:
                    raise HTTPException(status_code=404, detail="Aluno não encontrado.")
                cfg = _carregar_config(cur)
                return _metricas_aluno(cur, aluno_id, aluno_row[0], aluno_row[1], cfg)
    except HTTPException:
        raise
    except Exception as e:
        raise _erro_banco(e)


def calcular_metricas_turma(professor_id: str, turma_id: str) -> MetricasTurmaResponse:
    """Relatório coletivo da turma e distribuição por status colorido (RF-033)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT nome FROM turma WHERE id::text = %s AND professor_id::text = %s",
                    (turma_id, professor_id),
                )
                turma_row = cur.fetchone()
                if not turma_row:
                    raise HTTPException(status_code=404, detail="Turma não encontrada.")
                turma_nome = turma_row[0]
                cfg = _carregar_config(cur)

                cur.execute(
                    """
                    SELECT id::text, nome || ' ' || sobrenome FROM aluno
                    WHERE turma_atual_id::text = %s AND arquivado_em IS NULL
                    ORDER BY nome, sobrenome
                    """,
                    (turma_id,),
                )
                alunos = cur.fetchall()
                metricas_alunos = [_metricas_aluno(cur, a_id, nome, turma_nome, cfg) for a_id, nome in alunos]

        contagem = {"VERDE": 0, "AMARELO": 0, "VERMELHO": 0, "CINZA": 0}
        for m in metricas_alunos:
            contagem[m.status_colorido] = contagem.get(m.status_colorido, 0) + 1

        # Média da turma só com alunos que já têm status definido (não cinza)
        medias = [m.media_notas for m in metricas_alunos if m.status_colorido != "CINZA" and m.media_notas is not None]
        media_turma = round(sum(medias) / len(medias), 1) if medias else None

        return MetricasTurmaResponse(
            turma_id=turma_id,
            turma_nome=turma_nome,
            total_alunos=len(metricas_alunos),
            media_turma=media_turma,
            alunos_verde=contagem["VERDE"],
            alunos_amarelo=contagem["AMARELO"],
            alunos_vermelho=contagem["VERMELHO"],
            alunos_cinza=contagem["CINZA"],
            alunos_metricas=metricas_alunos,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise _erro_banco(e)
