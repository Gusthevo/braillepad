import uuid
import datetime
from typing import Optional
from fastapi import HTTPException, status
from ..core.database import get_db_connection
from ..schemas.sessao_schema import (
    SessaoIniciarRequest,
    LeituraFichaRequest,
    SessaoFinalizarRequest,
    SessaoResponse,
    AlertaAtividadeResponse,
)

# In-memory storage for dev mode fallback
_IN_MEMORY_SESSOES = {}


def obter_alvos_da_atividade(cur, atividade_id: str, categoria: str) -> list[str]:
    """Busca dinamicamente os rótulos de alvos cadastrados para a atividade no PostgreSQL."""
    try:
        cur.execute(
            """
            SELECT DISTINCT a.rotulo
            FROM fase_atividade fa
            JOIN fase_alvo f_alvo ON f_alvo.fase_id = fa.id
            JOIN alvo a ON f_alvo.alvo_id = a.id
            WHERE fa.atividade_id::text = %s
            ORDER BY a.rotulo ASC
            """,
            (atividade_id,),
        )
        rows = cur.fetchall()
        if rows:
            return [r[0] for r in rows]
    except Exception:
        pass

    if categoria == 'SILABAS':
        return ['MA', 'ME', 'MI', 'MO', 'MU', 'LA', 'LE', 'LI', 'LO', 'LU']
    elif categoria == 'PALAVRAS':
        return ['MALA', 'LAMA', 'LIMA', 'MULA', 'MOLA', 'LIMAO', 'LEAO']
    else:
        return ['A', 'E', 'I', 'O', 'U']


def gerar_alertas_sessao(leituras: list[dict]) -> list[AlertaAtividadeResponse]:
    """Gera alertas pedagógicos automáticos baseados nas regras da Seção 1.1 do documento YouthTech."""
    alertas = []
    erros_por_vogal = {}
    fichas_apresentadas = {}

    for l in leituras:
        v_alvo = l.get("alvo_id", "desconhecido")
        is_correta = l.get("correta", True)
        f_codigo = l.get("ficha_codigo", "desconhecida")

        if not is_correta:
            erros_por_vogal[v_alvo] = erros_por_vogal.get(v_alvo, 0) + 1
            fichas_apresentadas[f_codigo] = fichas_apresentadas.get(f_codigo, 0) + 1

    for v, num_erros in erros_por_vogal.items():
        if num_erros >= 2:
            alertas.append(
                AlertaAtividadeResponse(
                    tipo="ERROS_RECORRENTES",
                    titulo="Erros Recorrentes na Identificação",
                    mensagem=f"Registradas {num_erros} identificações incorretas para o alvo {v}.",
                )
            )

    for f, count in fichas_apresentadas.items():
        if count >= 2:
            alertas.append(
                AlertaAtividadeResponse(
                    tipo="CONFUSAO_GRAFEMAS",
                    titulo="Confusão Recorrente entre Grafemas",
                    mensagem=f"A ficha {f} foi apresentada incorretamente {count} vezes.",
                )
            )

    return alertas


def encerrar_sessao_ativa_parcial(professor_id: str) -> bool:
    """Encerra garantidamente qualquer sessão ativa do professor em andamento."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE sessao_atividade
                    SET status = 'PARCIAL', encerrada_em = now()
                    WHERE professor_id::text = %s AND status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                conn.commit()
                return True
    except Exception:
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        UPDATE sessao_atividade
                        SET status = 'CONCLUIDA', encerrada_em = now()
                        WHERE professor_id::text = %s AND status = 'EM_ANDAMENTO'
                        """,
                        (professor_id,),
                    )
                    conn.commit()
                    return True
        except Exception:
            for s_id, s in _IN_MEMORY_SESSOES.items():
                if s["professor_id"] == professor_id and s["status"] == "EM_ANDAMENTO":
                    s["status"] = "PARCIAL"
                    s["finalizada_em"] = datetime.datetime.now().isoformat()
            return True


def iniciar_sessao(professor_id: str, request: SessaoIniciarRequest) -> SessaoResponse:
    """Abre uma nova sessão pedagógica individual (RF-020). Regra RN-09: encerra anterior se solicitado."""
    if request.encerrar_anterior:
        encerrar_sessao_ativa_parcial(professor_id)

    sessao_id = str(uuid.uuid4())

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id FROM sessao_atividade
                    WHERE professor_id::text = %s AND status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                if cur.fetchone():
                    encerrar_sessao_ativa_parcial(professor_id)

                cur.execute(
                    """
                    SELECT a.nome || ' ' || a.sobrenome as aluno_nome, at.titulo as atividade_titulo, m.categoria
                    FROM aluno a
                    JOIN turma t ON a.turma_atual_id = t.id
                    JOIN atividade at ON at.id::text = %s OR at.id = %s::uuid
                    JOIN modulo m ON at.modulo_id = m.id
                    WHERE a.id::text = %s AND t.professor_id::text = %s
                    """,
                    (request.atividade_id, request.atividade_id, request.aluno_id, professor_id),
                )
                info_row = cur.fetchone()
                aluno_nome = info_row[0] if info_row else "Aluno DTAE"
                atividade_titulo = info_row[1] if info_row else "Atividade DTAE"
                categoria = info_row[2] if info_row else "VOGAIS"

                alvos = obter_alvos_da_atividade(cur, request.atividade_id, categoria)
                modo_reg = request.modo_entrada if request.modo_entrada in ['MANUAL', 'SIMULACAO', 'PAD'] else 'MANUAL'

                cur.execute(
                    """
                    INSERT INTO sessao_atividade (
                        id, professor_id, turma_id, aluno_id, atividade_id, modo_registro, status
                    )
                    VALUES (%s::uuid, %s::uuid, %s::uuid, %s::uuid, %s::uuid, %s, 'EM_ANDAMENTO')
                    RETURNING iniciada_em::text
                    """,
                    (sessao_id, professor_id, request.turma_id, request.aluno_id, request.atividade_id, modo_reg),
                )
                iniciada_em = cur.fetchone()[0]
                conn.commit()

                return SessaoResponse(
                    id=sessao_id,
                    professor_id=professor_id,
                    aluno_id=request.aluno_id,
                    aluno_nome=aluno_nome,
                    atividade_id=request.atividade_id,
                    atividade_titulo=atividade_titulo,
                    turma_historica_id=request.turma_id,
                    modo_entrada=modo_reg,
                    status="EM_ANDAMENTO",
                    iniciada_em=iniciada_em,
                    modulo_categoria=categoria,
                    alvos_esperados=alvos,
                )
    except HTTPException:
        raise
    except Exception:
        iniciada_em = datetime.datetime.now().isoformat()
        sessao_dict = {
            "id": sessao_id,
            "professor_id": professor_id,
            "aluno_id": request.aluno_id,
            "aluno_nome": "Aluno DTAE",
            "atividade_id": request.atividade_id,
            "atividade_titulo": "Atividade 01 - Vogais",
            "turma_historica_id": request.turma_id,
            "modo_entrada": request.modo_entrada,
            "status": "EM_ANDAMENTO",
            "iniciada_em": iniciada_em,
            "total_tentativas": 1,
            "comentarios": [],
            "modulo_categoria": "VOGAIS",
            "alvos_esperados": ["A", "E", "I", "O", "U"],
        }
        _IN_MEMORY_SESSOES[sessao_id] = sessao_dict
        return SessaoResponse(**sessao_dict)


def obter_sessao_ativa(professor_id: str) -> Optional[SessaoResponse]:
    """Retorna a sessão atualmente EM_ANDAMENTO do professor logado (se houver)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT 
                        s.id, s.professor_id, s.aluno_id, a.nome || ' ' || a.sobrenome,
                        s.atividade_id, at.titulo, s.turma_id, s.modo_registro,
                        s.status, s.iniciada_em::text, m.categoria
                    FROM sessao_atividade s
                    JOIN aluno a ON s.aluno_id = a.id
                    JOIN atividade at ON s.atividade_id = at.id
                    JOIN modulo m ON at.modulo_id = m.id
                    WHERE s.professor_id::text = %s AND s.status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                r = cur.fetchone()
                if r:
                    atv_id = str(r[4])
                    cat = r[10]
                    alvos = obter_alvos_da_atividade(cur, atv_id, cat)

                    return SessaoResponse(
                        id=str(r[0]),
                        professor_id=str(r[1]),
                        aluno_id=str(r[2]),
                        aluno_nome=r[3],
                        atividade_id=atv_id,
                        atividade_titulo=r[5],
                        turma_historica_id=str(r[6]),
                        modo_entrada=r[7],
                        status=r[8],
                        iniciada_em=r[9],
                        modulo_categoria=cat,
                        alvos_esperados=alvos,
                    )
                return None
    except Exception:
        for s_id, s in _IN_MEMORY_SESSOES.items():
            if s["professor_id"] == professor_id and s["status"] == "EM_ANDAMENTO":
                return SessaoResponse(**s)
        return None


def registrar_leitura_ficha(
    professor_id: str, sessao_id: str, request: LeituraFichaRequest
) -> dict:
    """Registra um evento de leitura de ficha (RF-023) gravando a tentativa no PostgreSQL."""
    leitura_id = str(uuid.uuid4())

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM sessao_atividade WHERE id::text = %s AND professor_id::text = %s AND status = 'EM_ANDAMENTO'",
                    (sessao_id, professor_id),
                )
                if not cur.fetchone():
                    raise HTTPException(
                        status_code=404, detail="Sessão ativa em andamento não encontrada."
                    )

                # 1. Buscar ou criar execucao_alvo e tentativa no PostgreSQL para registrar a leitura
                symbol = request.ficha_codigo.replace("FICHA_", "").replace("VOGAL_", "").strip()

                cur.execute("SELECT id FROM ficha WHERE simbolo = %s LIMIT 1", (symbol,))
                ficha_row = cur.fetchone()
                ficha_id = str(ficha_row[0]) if ficha_row else None

                if not ficha_id:
                    cur.execute("SELECT id FROM ficha LIMIT 1")
                    f_default = cur.fetchone()
                    ficha_id = str(f_default[0]) if f_default else None

                # Buscar primeira fase_alvo_id para o vinculo de execucao_alvo
                cur.execute(
                    """
                    SELECT fa.id
                    FROM sessao_atividade s
                    JOIN fase_atividade f ON f.atividade_id = s.atividade_id
                    JOIN fase_alvo fa ON fa.fase_id = f.id
                    WHERE s.id::text = %s
                    LIMIT 1
                    """,
                    (sessao_id,),
                )
                fa_row = cur.fetchone()
                fa_id = str(fa_row[0]) if fa_row else None

                if fa_id and ficha_id:
                    ea_id = str(uuid.uuid4())
                    cur.execute(
                        """
                        INSERT INTO execucao_alvo (id, sessao_id, fase_alvo_id, ordem_real, status)
                        VALUES (%s::uuid, %s::uuid, %s::uuid, 1, 'EM_ANDAMENTO')
                        ON CONFLICT (sessao_id, fase_alvo_id) DO UPDATE SET status = 'EM_ANDAMENTO'
                        RETURNING id::text
                        """,
                        (ea_id, sessao_id, fa_id),
                    )
                    ea_real_id = cur.fetchone()[0]

                    tent_id = str(uuid.uuid4())
                    cur.execute(
                        """
                        INSERT INTO tentativa (id, execucao_alvo_id, numero, resultado)
                        VALUES (%s::uuid, %s::uuid, %s, %s)
                        ON CONFLICT (execucao_alvo_id, numero) DO UPDATE SET resultado = EXCLUDED.resultado
                        RETURNING id::text
                        """,
                        (tent_id, ea_real_id, max(request.posicao, 1), 'ACERTO' if request.correta else 'ERRO'),
                    )
                    tent_real_id = cur.fetchone()[0]

                    cur.execute(
                        """
                        INSERT INTO leitura_ficha (id, tentativa_id, posicao, ficha_esperada_id, ficha_apresentada_id, correta, origem_registro)
                        VALUES (%s::uuid, %s::uuid, %s, %s::uuid, %s::uuid, %s, 'MANUAL')
                        ON CONFLICT (tentativa_id, posicao) DO UPDATE SET correta = EXCLUDED.correta
                        """,
                        (leitura_id, tent_real_id, max(request.posicao, 1), ficha_id, ficha_id, request.correta),
                    )

                conn.commit()
                return {
                    "leitura_id": leitura_id,
                    "sessao_id": sessao_id,
                    "alvo_id": request.alvo_id,
                    "posicao": request.posicao,
                    "ficha_codigo": request.ficha_codigo,
                    "correta": request.correta,
                    "mensagem": "Leitura gravada" if request.correta else "Erro registrado.",
                }
    except HTTPException:
        raise
    except Exception as e:
        if sessao_id in _IN_MEMORY_SESSOES:
            s = _IN_MEMORY_SESSOES[sessao_id]
            if "leituras" not in s:
                s["leituras"] = []
            s["leituras"].append({"correta": request.correta, "ficha_codigo": request.ficha_codigo})
            s["total_tentativas"] = len(s["leituras"])
        return {
            "leitura_id": leitura_id,
            "sessao_id": sessao_id,
            "correta": request.correta,
            "mensagem": "Leitura registrada.",
        }


def finalizar_sessao(
    professor_id: str, sessao_id: str, request: SessaoFinalizarRequest
) -> SessaoResponse:
    """
    Finaliza a sessão (RF-024) calculando a taxa real de acertos das fichas e gravando no PostgreSQL.
    """
    finalizada_em = datetime.datetime.now().isoformat()
    duracao_sec = request.duracao_segundos or 0
    estrelas = request.avaliacao_estrelas or 5

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.id, s.aluno_id, a.nome || ' ' || a.sobrenome, s.atividade_id, at.titulo, s.turma_id, s.modo_registro, s.iniciada_em::text, s.status, m.categoria
                    FROM sessao_atividade s
                    JOIN aluno a ON s.aluno_id = a.id
                    JOIN atividade at ON s.atividade_id = at.id
                    JOIN modulo m ON at.modulo_id = m.id
                    WHERE s.id::text = %s AND s.professor_id::text = %s
                    """,
                    (sessao_id, professor_id),
                )
                r = cur.fetchone()
                if not r:
                    raise HTTPException(status_code=404, detail="Sessão não encontrada.")

                aluno_id = str(r[1])
                aluno_nome = r[2]
                atividade_id = str(r[3])
                atividade_titulo = r[4]
                turma_id = str(r[5])
                modo_registro = r[6]
                iniciada_em = r[7]
                status_atual = r[8]
                categoria = r[9]

                alvos = obter_alvos_da_atividade(cur, atividade_id, categoria)

                # 1. Calcular a taxa real de acertos das leituras de fichas gravadas no PostgreSQL
                cur.execute(
                    """
                    SELECT count(*),
                           count(*) FILTER (WHERE correta = TRUE)
                    FROM leitura_ficha lf
                    JOIN tentativa t ON lf.tentativa_id = t.id
                    JOIN execucao_alvo ea ON t.execucao_alvo_id = ea.id
                    WHERE ea.sessao_id::text = %s
                    """,
                    (sessao_id,),
                )
                read_row = cur.fetchone()
                tot_reads = read_row[0] if read_row else 0
                tot_hits = read_row[1] if read_row else 0

                # Se a consulta no banco não encontrou (dev mode fallback), usa os dados do request enviados pelo Flutter
                if tot_reads == 0 and (request.total_tentativas or 0) > 0:
                    tot_reads = request.total_tentativas or 0
                    tot_hits = request.total_acertos or 0

                if tot_reads > 0:
                    percentual_acertos = round(float((tot_hits / tot_reads) * 100.0), 1)
                else:
                    percentual_acertos = float(estrelas * 20.0)

                # Nota final calculada pela média da taxa de acertos real (50%) e estrelas do professor (50%)
                nota_calculada = round(float((estrelas * 10.0) + (percentual_acertos * 0.5)), 1)

                cur.execute(
                    """
                    SELECT count(*)
                    FROM fase_atividade f
                    JOIN fase_alvo fa ON fa.fase_id = f.id
                    WHERE f.atividade_id::text = %s AND fa.obrigatorio
                    """,
                    (atividade_id,),
                )
                total_alvos_row = cur.fetchone()
                v_total = total_alvos_row[0] if total_alvos_row else 0

                cur.execute(
                    """
                    SELECT count(*)
                    FROM execucao_alvo ea
                    JOIN fase_alvo fa ON fa.id = ea.fase_alvo_id
                    WHERE ea.sessao_id::text = %s AND fa.obrigatorio AND ea.status = 'CONCLUIDO'
                    """,
                    (sessao_id,),
                )
                concluidos_row = cur.fetchone()
                v_concluidos = concluidos_row[0] if concluidos_row else 0

                status_novo = 'CONCLUIDA' if (v_total > 0 and v_concluidos == v_total) else 'PARCIAL'

                # 2. Atualizar status e duração na tabela 'sessao_atividade'
                if status_atual == 'EM_ANDAMENTO':
                    cur.execute(
                        """
                        UPDATE sessao_atividade
                        SET status = %s, encerrada_em = now(), duracao_segundos = %s
                        WHERE id::text = %s
                        """,
                        (status_novo, duracao_sec, sessao_id),
                    )

                # 3. Gravar nota na tabela 'avaliacao_sessao' somente se status_novo for CONCLUIDA (Trigger dtae_validar_avaliacao)
                if status_novo == 'CONCLUIDA':
                    try:
                        cur.execute(
                            "SELECT id FROM regra_pontuacao WHERE categoria = %s AND ativa = TRUE LIMIT 1",
                            (categoria,),
                        )
                        regra_row = cur.fetchone()
                        if regra_row:
                            regra_id = str(regra_row[0])
                            compreensao_db = ('SIM' if request.compreensao_instrucoes in ['TOTAL', 'SIM'] else 'EM_PARTE') if categoria == 'PALAVRAS' else None

                            cur.execute(
                                """
                                INSERT INTO avaliacao_sessao (sessao_id, regra_id, nivel_ajuda, compreensao, nota, alvos_pontuados)
                                VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s)
                                ON CONFLICT (sessao_id) DO UPDATE
                                SET nivel_ajuda = EXCLUDED.nivel_ajuda,
                                    compreensao = EXCLUDED.compreensao,
                                    nota = EXCLUDED.nota,
                                    avaliada_em = now()
                                """,
                                (sessao_id, regra_id, 'SEM_AJUDA', compreensao_db, nota_calculada, max(v_concluidos, 1)),
                            )
                    except Exception:
                        pass

                # 4. Gravar comentário do professor (RF-026)
                if request.comentario and request.comentario.strip():
                    cur.execute(
                        """
                        INSERT INTO comentario_professor (sessao_id, professor_id, texto)
                        VALUES (%s::uuid, %s::uuid, %s)
                        """,
                        (sessao_id, professor_id, request.comentario.strip()),
                    )

                conn.commit()

                cur.execute(
                    "SELECT texto FROM comentario_professor WHERE sessao_id::text = %s ORDER BY criado_em ASC",
                    (sessao_id,),
                )
                comentarios_list = [c[0] for c in cur.fetchall()]

                alertas_gerados = []
                if duracao_sec > 180:
                    alertas_gerados.append(
                        AlertaAtividadeResponse(
                            tipo="TEMPO_EXCEDIDO",
                            titulo="Tempo Excedido (> 3 min)",
                            mensagem=f"A criança levou {duracao_sec // 60}m {duracao_sec % 60}s para concluir a atividade (parâmetro inicial: 3 minutos).",
                        )
                    )
                else:
                    alertas_gerados.append(
                        AlertaAtividadeResponse(
                            tipo="EVOLUCAO",
                            titulo="Evolução Demonstrada",
                            mensagem="O aluno completou a identificação com autonomia.",
                        )
                    )

                return SessaoResponse(
                    id=sessao_id,
                    professor_id=professor_id,
                    aluno_id=aluno_id,
                    aluno_nome=aluno_nome,
                    atividade_id=atividade_id,
                    atividade_titulo=atividade_titulo,
                    turma_historica_id=turma_id,
                    modo_entrada=modo_registro,
                    status=status_novo,
                    iniciada_em=iniciada_em,
                    finalizada_em=finalizada_em,
                    duracao_segundos=duracao_sec,
                    nota=nota_calculada,
                    percentual_acertos=percentual_acertos,
                    avaliacao_estrelas=estrelas,
                    nivel_auxilio_fase1=request.nivel_auxilio_fase1,
                    nivel_auxilio_fase2=request.nivel_auxilio_fase2,
                    compreensao_instrucoes=request.compreensao_instrucoes,
                    autonomia_exploracao=request.autonomia_exploracao,
                    comentarios=comentarios_list,
                    alertas_gerados=alertas_gerados,
                    modulo_categoria=categoria,
                    alvos_esperados=alvos,
                )
    except HTTPException:
        raise
    except Exception:
        if sessao_id in _IN_MEMORY_SESSOES:
            s = _IN_MEMORY_SESSOES[sessao_id]
            s["status"] = "CONCLUIDA"
            s["finalizada_em"] = finalizada_em
            s["duracao_segundos"] = duracao_sec
            s["nota"] = nota_calculada
            s["avaliacao_estrelas"] = estrelas
            s["nivel_auxilio_fase1"] = request.nivel_auxilio_fase1
            s["nivel_auxilio_fase2"] = request.nivel_auxilio_fase2
            s["compreensao_instrucoes"] = request.compreensao_instrucoes
            s["autonomia_exploracao"] = request.autonomia_exploracao
            if request.comentario and request.comentario.strip():
                s["comentarios"] = [request.comentario.strip()]
            return SessaoResponse(**s)

        raise HTTPException(status_code=500, detail="Erro ao finalizar sessão.")
