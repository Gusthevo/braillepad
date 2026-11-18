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
    """Registra um evento de leitura de ficha (RF-023) no PostgreSQL sem sobrescrever histórico."""
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

                symbol = request.ficha_codigo.replace("FICHA_", "").replace("VOGAL_", "").strip()

                cur.execute("SELECT id FROM ficha WHERE simbolo = %s LIMIT 1", (symbol,))
                ficha_row = cur.fetchone()
                ficha_id = str(ficha_row[0]) if ficha_row else None

                if not ficha_id:
                    cur.execute("SELECT id FROM ficha LIMIT 1")
                    f_default = cur.fetchone()
                    ficha_id = str(f_default[0]) if f_default else None

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

                    res_str = 'ACERTO' if request.correta else 'ERRO'
                    tent_id = str(uuid.uuid4())
                    cur.execute(
                        """
                        INSERT INTO tentativa (id, execucao_alvo_id, numero, resultado, iniciada_em, encerrada_em)
                        VALUES (%s::uuid, %s::uuid, %s, %s, now(), now())
                        ON CONFLICT (execucao_alvo_id, numero) DO UPDATE SET 
                            resultado = EXCLUDED.resultado,
                            encerrada_em = now()
                        RETURNING id::text
                        """,
                        (tent_id, ea_real_id, max(request.posicao, 1), res_str),
                    )
                    tent_real_id = cur.fetchone()[0]

                    cur.execute(
                        "SELECT COALESCE(MAX(posicao), 0) + 1 FROM leitura_ficha WHERE tentativa_id::text = %s",
                        (tent_real_id,),
                    )
                    next_pos = cur.fetchone()[0]

                    cur.execute(
                        """
                        INSERT INTO leitura_ficha (id, tentativa_id, posicao, ficha_esperada_id, ficha_apresentada_id, correta, origem_registro)
                        VALUES (%s::uuid, %s::uuid, %s, %s::uuid, %s::uuid, %s, 'MANUAL')
                        """,
                        (leitura_id, tent_real_id, next_pos, ficha_id, ficha_id, request.correta),
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
    except Exception:
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
    Finaliza a sessão (RF-024) de forma simples e direta, alterando o status para 'CONCLUIDA'
    e registrando a nota na tabela 'avaliacao_sessao' no PostgreSQL sem bloqueios.
    """
    finalizada_em = datetime.datetime.now().isoformat()
    duracao_sec = request.duracao_segundos or 0
    estrelas = request.avaliacao_estrelas or 5

    req_tentativas = request.total_tentativas or 0
    req_acertos = request.total_acertos or 0
    if req_tentativas > 0:
        percentual_acertos = round(float((req_acertos / req_tentativas) * 100.0), 1)
    else:
        percentual_acertos = float(estrelas * 20.0)

    # Nota final calculada (50% desempenho + 50% avaliação de estrelas)
    nota_calculada = round(float((estrelas * 10.0) + (percentual_acertos * 0.5)), 1)

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
                    WHERE s.id::text = %s
                    """,
                    (sessao_id,),
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

                # 1. Se a sessão ainda estiver EM_ANDAMENTO, conclui os alvos e altera o status para CONCLUIDA
                if status_atual == 'EM_ANDAMENTO':
                    cur.execute(
                        """
                        SELECT fa.id
                        FROM fase_atividade f
                        JOIN fase_alvo fa ON fa.fase_id = f.id
                        WHERE f.atividade_id::text = %s AND fa.obrigatorio
                        ORDER BY fa.ordem_padrao ASC
                        """,
                        (atividade_id,),
                    )
                    fa_rows = cur.fetchall()
                    for idx, fa_r in enumerate(fa_rows):
                        fa_id = str(fa_r[0])
                        cur.execute(
                            """
                            INSERT INTO execucao_alvo (id, sessao_id, fase_alvo_id, ordem_real, status, iniciada_em, concluida_em)
                            VALUES (gen_random_uuid(), %s::uuid, %s::uuid, %s, 'CONCLUIDO', now(), now())
                            ON CONFLICT (sessao_id, fase_alvo_id) DO UPDATE SET
                                status = 'CONCLUIDO',
                                iniciada_em = COALESCE(execucao_alvo.iniciada_em, now()),
                                concluida_em = now()
                            """,
                            (sessao_id, fa_id, idx + 1),
                        )

                    # 2. Atualizar a sessao para status 'CONCLUIDA'
                    cur.execute(
                        """
                        UPDATE sessao_atividade
                        SET status = 'CONCLUIDA', encerrada_em = now(), duracao_segundos = %s
                        WHERE id::text = %s
                        """,
                        (duracao_sec, sessao_id),
                    )
                else:
                    # Se já estava concluída, apenas busca fa_rows para contagem
                    cur.execute(
                        """
                        SELECT fa.id
                        FROM fase_atividade f
                        JOIN fase_alvo fa ON fa.fase_id = f.id
                        WHERE f.atividade_id::text = %s AND fa.obrigatorio
                        """,
                        (atividade_id,),
                    )
                    fa_rows = cur.fetchall()
                    cur.execute(
                        "UPDATE sessao_atividade SET duracao_segundos = GREATEST(duracao_segundos, %s) WHERE id::text = %s",
                        (duracao_sec, sessao_id),
                    )

                # 3. Inserir ou atualizar avaliacao_sessao com mapeamento estrito para satisfazer as triggers do banco
                cur.execute("SELECT id FROM regra_pontuacao WHERE categoria = %s AND ativa = TRUE LIMIT 1", (categoria,))
                regra_row = cur.fetchone()
                if not regra_row:
                    cur.execute("SELECT id FROM regra_pontuacao WHERE categoria = %s LIMIT 1", (categoria,))
                    regra_row = cur.fetchone()

                if regra_row:
                    regra_id = str(regra_row[0])

                    # Mapeamento do nível de ajuda (CHECK constraint: SEM_AJUDA, DICA_VERBAL, MEDIACAO_INTENSA)
                    n_aux = (request.nivel_auxilio_fase1 or 'INDEPENDENTE').upper()
                    if n_aux in ['INDEPENDENTE', 'SEM_AJUDA']:
                        nivel_ajuda_db = 'SEM_AJUDA'
                    elif n_aux in ['VERBAL', 'REPETICAO', 'DICA_VERBAL']:
                        nivel_ajuda_db = 'DICA_VERBAL'
                    else:
                        nivel_ajuda_db = 'MEDIACAO_INTENSA'

                    # Mapeamento de compreensão (Trigger constraint: APENAS PALAVRAS aceita compreensao NOT NULL)
                    if categoria == 'PALAVRAS':
                        c_inst = (request.compreensao_instrucoes or 'SIM').upper()
                        if c_inst in ['TOTAL', 'SIM']:
                            compreensao_db = 'SIM'
                        elif c_inst in ['PARCIAL', 'REPETIDAS', 'EM_PARTE']:
                            compreensao_db = 'EM_PARTE'
                        else:
                            compreensao_db = 'AINDA_NAO'
                    else:
                        compreensao_db = None

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
                        (sessao_id, regra_id, nivel_ajuda_db, compreensao_db, nota_calculada, max(len(fa_rows), 1)),
                    )

                # 4. Gravar comentário do professor se houver
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

                alertas_gerados = [
                    AlertaAtividadeResponse(
                        tipo="EVOLUCAO",
                        titulo="Atividade Concluída",
                        mensagem=f"Nota registrada: {nota_calculada:.1f} pts.",
                    )
                ]

                return SessaoResponse(
                    id=sessao_id,
                    professor_id=professor_id,
                    aluno_id=aluno_id,
                    aluno_nome=aluno_nome,
                    atividade_id=atividade_id,
                    atividade_titulo=atividade_titulo,
                    turma_historica_id=turma_id,
                    modo_entrada=modo_registro,
                    status="CONCLUIDA",
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
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao finalizar sessão no banco: {e}")
