from fastapi import HTTPException, status
from ..core.database import get_db_connection
from ..schemas.atividade_schema import (
    ModuloResponse,
    AtividadeResponse,
    AtividadeDetailResponse,
    FaseResponse,
    AlvoResponse,
    FichaResponse,
)

# In-memory storage for dev mode fallback
_IN_MEMORY_MODULOS = [
    {
        "id": 1,
        "numero": 1,
        "categoria": "VOGAIS",
        "nome": "Módulo 1 — Vogais",
        "descricao": "Atividades pedagógicas focadas nas vogais A, E, I, O, U.",
        "total_atividades": 10,
    },
    {
        "id": 2,
        "numero": 2,
        "categoria": "SILABAS",
        "nome": "Módulo 2 — Sílabas",
        "descricao": "Combinações das consoantes M e L com as vogais A, E, I, O, U.",
        "total_atividades": 10,
    },
    {
        "id": 3,
        "numero": 3,
        "categoria": "PALAVRAS",
        "nome": "Módulo 3 — Palavras",
        "descricao": "Formação de palavras completas com sequências de fichas Braille.",
        "total_atividades": 10,
    },
]


def _limpar_titulo(titulo: str) -> str:
    """Remove prefixos técnicos como [DEMONSTRACAO] do título."""
    if not titulo:
        return ""
    return titulo.replace("[DEMONSTRACAO] ", "").replace("[DEMONSTRACAO]", "").strip()


def listar_modulos() -> list[ModuloResponse]:
    """Lista os 3 Módulos fixos do catálogo DTAE (RF-012)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT m.id, m.numero, m.categoria, m.nome, m.descricao,
                           COUNT(a.id) as total_atividades
                    FROM modulo m
                    LEFT JOIN atividade a ON a.modulo_id = m.id AND a.ativa = TRUE
                    WHERE m.ativo = TRUE
                    GROUP BY m.id, m.numero, m.categoria, m.nome, m.descricao
                    ORDER BY m.numero ASC
                    """
                )
                rows = cur.fetchall()
                if rows:
                    return [
                        ModuloResponse(
                            id=r[0],
                            numero=r[1],
                            categoria=r[2],
                            nome=r[3],
                            descricao=r[4] or "",
                            total_atividades=r[5] if r[5] > 0 else 10,
                        )
                        for r in rows
                    ]
    except Exception:
        pass

    return [ModuloResponse(**m) for m in _IN_MEMORY_MODULOS]


def listar_atividades_por_modulo(modulo_id: int) -> list[AtividadeResponse]:
    """Lista as 10 Atividades numeradas do módulo informado (RF-013)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, modulo_id, numero, titulo, descricao, objetivo, obrigatoria, publicada
                    FROM atividade
                    WHERE modulo_id = %s AND ativa = TRUE
                    ORDER BY numero ASC
                    """,
                    (modulo_id,),
                )
                rows = cur.fetchall()
                if rows:
                    return [
                        AtividadeResponse(
                            id=str(r[0]),
                            modulo_id=r[1],
                            numero=r[2],
                            titulo=_limpar_titulo(r[3]),
                            descricao=r[4] or "",
                            objetivo=r[5],
                            obrigatoria=r[6],
                            publicada=True,
                        )
                        for r in rows
                    ]
    except Exception:
        pass

    nomes_mod = {1: "Vogais", 2: "Sílabas", 3: "Palavras"}
    prefixo = nomes_mod.get(modulo_id, "Atividade")

    resultado = []
    for num in range(1, 11):
        resultado.append(
            AtividadeResponse(
                id=f"mod{modulo_id}_atv{num:02d}",
                modulo_id=modulo_id,
                numero=num,
                titulo=f"Atividade {num:02d} — Prática de {prefixo}",
                descricao=f"Exercício pedagógico {num:02d} do Módulo {modulo_id} do DTAE.",
                objetivo=f"Reconhecer e montar alvos do Módulo {modulo_id}.",
                obrigatoria=True,
                publicada=True,
            )
        )
    return resultado


def obter_atividade_detalhada(atividade_id: str) -> AtividadeDetailResponse:
    """Obtém detalhes da atividade, suas fases e alvos/fichas esperados (RF-014)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, modulo_id, numero, titulo, descricao, objetivo, obrigatoria, publicada
                    FROM atividade
                    WHERE id::text = %s AND ativa = TRUE
                    """,
                    (atividade_id,),
                )
                r = cur.fetchone()
                if not r:
                    raise HTTPException(status_code=404, detail="Atividade não encontrada.")

                atv_data = {
                    "id": str(r[0]),
                    "modulo_id": r[1],
                    "numero": r[2],
                    "titulo": _limpar_titulo(r[3]),
                    "descricao": r[4] or "",
                    "objetivo": r[5],
                    "obrigatoria": r[6],
                    "publicada": True,
                }

                cur.execute(
                    """
                    SELECT id, ordem, titulo, tipo_fase, pontuavel, sequenciamento
                    FROM fase_atividade
                    WHERE atividade_id::text = %s
                    ORDER BY ordem ASC
                    """,
                    (atividade_id,),
                )
                fases_rows = cur.fetchall()

                fases_list = []
                for f_row in fases_rows:
                    fase_id = str(f_row[0])

                    cur.execute(
                        """
                        SELECT a.id, a.tipo, a.rotulo, fa.ordem_padrao
                        FROM fase_alvo fa
                        JOIN alvo a ON fa.alvo_id = a.id
                        WHERE fa.fase_id = %s
                        ORDER BY fa.ordem_padrao ASC
                        """,
                        (fase_id,),
                    )
                    alvos_rows = cur.fetchall()

                    alvos_list = []
                    for a_row in alvos_rows:
                        alvo_id = str(a_row[0])

                        cur.execute(
                            """
                            SELECT f.id, f.simbolo, f.tipo, f.simbolo, f.simbolo
                            FROM alvo_ficha af
                            JOIN ficha f ON af.ficha_id = f.id
                            WHERE af.alvo_id = %s
                            ORDER BY af.posicao ASC
                            """,
                            (alvo_id,),
                        )
                        fichas_rows = cur.fetchall()
                        fichas_list = [
                            FichaResponse(
                                id=str(fc[0]),
                                codigo=fc[1],
                                tipo=fc[2],
                                representacao=fc[3],
                                descricao=fc[4],
                            )
                            for fc in fichas_rows
                        ]

                        alvos_list.append(
                            AlvoResponse(
                                id=alvo_id,
                                tipo_alvo=a_row[1],
                                valor_esperado=a_row[2],
                                ordem=a_row[3],
                                fichas_esperadas=fichas_list,
                            )
                        )

                    fases_list.append(
                        FaseResponse(
                            id=fase_id,
                            ordem=f_row[1],
                            titulo=f_row[2],
                            tipo_fase=f_row[3],
                            pontuavel=f_row[4],
                            sequenciamento=f_row[5],
                            alvos=alvos_list,
                        )
                    )

                return AtividadeDetailResponse(**atv_data, fases=fases_list)

    except HTTPException:
        raise
    except Exception:
        pass

    return AtividadeDetailResponse(
        id=atividade_id,
        modulo_id=1,
        numero=1,
        titulo="Atividade 01 — Vogais",
        descricao="Apresentação técnica das vogais A, E, I, O, U.",
        objetivo="Explorar e formar a sequência de vogais em ordem e embaralhada.",
        obrigatoria=True,
        publicada=True,
        fases=[
            FaseResponse(
                id="fase_01",
                ordem=1,
                titulo="Fase 1: Tutorial",
                tipo_fase="EXPLORAR",
                pontuavel=False,
                sequenciamento="FIXO",
            ),
            FaseResponse(
                id="fase_02",
                ordem=2,
                titulo="Fase 2: Vogais em Ordem",
                tipo_fase="ORDEM",
                pontuavel=True,
                sequenciamento="FIXO",
            ),
            FaseResponse(
                id="fase_03",
                ordem=3,
                titulo="Fase 3: Vogais Embaralhadas",
                tipo_fase="EMBARALHADA",
                pontuavel=True,
                sequenciamento="ALEATORIO",
            ),
        ],
    )
