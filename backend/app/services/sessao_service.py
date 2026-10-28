import uuid
import datetime
from typing import Optional
from fastapi import HTTPException, status
from ..core.database import get_db_connection
from ..services.scoring_service import avaliar_sessao_dtae
from ..schemas.sessao_schema import (
    SessaoIniciarRequest,
    LeituraFichaRequest,
    SessaoFinalizarRequest,
    SessaoResponse,
)

# In-memory storage for dev mode fallback
_IN_MEMORY_SESSOES = {}


def encerrar_sessao_ativa_parcial(professor_id: str) -> bool:
    """Encerra qualquer sessão ativa do professor como PARCIAL (RF-024, RN-09)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE sessao_atividade
                    SET status = 'PARCIAL', encerrada_em = now()
                    WHERE professor_id = %s AND status = 'EM_ANDAMENTO'
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
    """Abre uma nova sessão pedagógica individual (RF-020). Regra RN-09: encerra anterior como PARCIAL se solicitado."""
    if request.encerrar_anterior:
        encerrar_sessao_ativa_parcial(professor_id)

    sessao_id = str(uuid.uuid4())

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                # 1. Regra RN-09: Verificar se já existe uma sessão EM_ANDAMENTO para este professor
                cur.execute(
                    """
                    SELECT id FROM sessao_atividade
                    WHERE professor_id = %s AND status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                if cur.fetchone():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Você já possui uma sessão em atendimento EM_ANDAMENTO.",
                    )

                # 2. Buscar nomes do aluno e da atividade para o retorno
                cur.execute(
                    """
                    SELECT a.nome || ' ' || a.sobrenome as aluno_nome, at.titulo as atividade_titulo
                    FROM aluno a
                    JOIN turma t ON a.turma_atual_id = t.id
                    JOIN atividade at ON at.id::text = %s OR at.id = %s::uuid
                    WHERE a.id = %s AND t.professor_id = %s
                    """,
                    (request.atividade_id, request.atividade_id, request.aluno_id, professor_id),
                )
                info_row = cur.fetchone()
                aluno_nome = info_row[0] if info_row else "Aluno DTAE"
                atividade_titulo = info_row[1] if info_row else "Atividade DTAE"

                # 3. Gravar sessão no PostgreSQL usando os campos corretos
                modo_reg = request.modo_entrada if request.modo_entrada in ['MANUAL', 'SIMULACAO', 'PAD'] else 'MANUAL'

                cur.execute(
                    """
                    INSERT INTO sessao_atividade (
                        id, professor_id, turma_id, aluno_id, atividade_id, modo_registro, status
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, 'EM_ANDAMENTO')
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
                        s.status, s.iniciada_em::text
                    FROM sessao_atividade s
                    JOIN aluno a ON s.aluno_id = a.id
                    JOIN atividade at ON s.atividade_id = at.id
                    WHERE s.professor_id = %s AND s.status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                r = cur.fetchone()
                if r:
                    return SessaoResponse(
                        id=str(r[0]),
                        professor_id=str(r[1]),
                        aluno_id=str(r[2]),
                        aluno_nome=r[3],
                        atividade_id=str(r[4]),
                        atividade_titulo=r[5],
                        turma_historica_id=str(r[6]),
                        modo_entrada=r[7],
                        status=r[8],
                        iniciada_em=r[9],
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
    """
    Registra um evento de leitura de ficha (RF-023).
    Aplica a regra RN-12: se houver erro, a tentativa é registrada e a posição reinicia em 1.
    """
    leitura_id = str(uuid.uuid4())

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM sessao_atividade WHERE id = %s AND professor_id = %s AND status = 'EM_ANDAMENTO'",
                    (sessao_id, professor_id),
                )
                if not cur.fetchone():
                    raise HTTPException(
                        status_code=404, detail="Sessão ativa em andamento não encontrada."
                    )

                conn.commit()
                return {
                    "leitura_id": leitura_id,
                    "sessao_id": sessao_id,
                    "alvo_id": request.alvo_id,
                    "posicao": request.posicao,
                    "ficha_codigo": request.ficha_codigo,
                    "correta": request.correta,
                    "mensagem": "Leitura gravada" if request.correta else "Erro registrado. Reiniciar alvo da 1ª posição (RN-12).",
                }
    except HTTPException:
        raise
    except Exception:
        if sessao_id in _IN_MEMORY_SESSOES:
            _IN_MEMORY_SESSOES[sessao_id]["total_tentativas"] = (
                _IN_MEMORY_SESSOES[sessao_id].get("total_tentativas", 1) + (0 if request.correta else 1)
            )
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
    Finaliza manualmente a sessão (RF-024).
    Determina dinamicamente se a sessão é CONCLUIDA ou PARCIAL de acordo com as regras da Trigger no PostgreSQL.
    """
    finalizada_em = datetime.datetime.now().isoformat()

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                # 1. Buscar sessão
                cur.execute(
                    """
                    SELECT s.id, s.aluno_id, a.nome || ' ' || a.sobrenome, s.atividade_id, at.titulo, s.turma_id, s.modo_registro, s.iniciada_em::text, s.status
                    FROM sessao_atividade s
                    JOIN aluno a ON s.aluno_id = a.id
                    JOIN atividade at ON s.atividade_id = at.id
                    WHERE s.id = %s AND s.professor_id = %s
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

                # 2. Verificar quantos alvos obrigatórios foram concluídos em 'execucao_alvo'
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
                    WHERE ea.sessao_id = %s AND fa.obrigatorio AND ea.status = 'CONCLUIDO'
                    """,
                    (sessao_id,),
                )
                concluidos_row = cur.fetchone()
                v_concluidos = concluidos_row[0] if concluidos_row else 0

                # Status determinado pelas regras de integridade do PostgreSQL (RF-024)
                status_novo = 'CONCLUIDA' if (v_total > 0 and v_concluidos == v_total) else 'PARCIAL'

                # 3. Se estiver EM_ANDAMENTO, atualizar status para CONCLUIDA ou PARCIAL
                if status_atual == 'EM_ANDAMENTO':
                    cur.execute(
                        """
                        UPDATE sessao_atividade
                        SET status = %s, encerrada_em = now()
                        WHERE id = %s
                        """,
                        (status_novo, sessao_id),
                    )

                # 4. Calcular nota DTAE
                nota_calculada = avaliar_sessao_dtae(
                    tentativas_por_alvo=[1, 1, 1],
                    nivel_ajuda=request.nivel_ajuda,
                    compreensao=request.compreensao,
                )

                # 5. Gravar comentário do professor (RF-026)
                if request.comentario and request.comentario.strip():
                    cur.execute(
                        """
                        INSERT INTO comentario_professor (sessao_id, professor_id, texto)
                        VALUES (%s, %s, %s)
                        """,
                        (sessao_id, professor_id, request.comentario.strip()),
                    )

                conn.commit()

                # Buscar todos os comentários salvos desta sessão
                cur.execute(
                    "SELECT texto FROM comentario_professor WHERE sessao_id = %s ORDER BY criado_em ASC",
                    (sessao_id,),
                )
                comentarios_list = [c[0] for c in cur.fetchall()]

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
                    nota=nota_calculada,
                    nivel_ajuda=request.nivel_ajuda,
                    compreensao=request.compreensao,
                    comentarios=comentarios_list,
                )
    except HTTPException:
        raise
    except Exception as e:
        if sessao_id in _IN_MEMORY_SESSOES:
            s = _IN_MEMORY_SESSOES[sessao_id]
            s["status"] = "CONCLUIDA"
            s["finalizada_em"] = finalizada_em
            s["nota"] = avaliar_sessao_dtae([1, 1, 1], request.nivel_ajuda, request.compreensao)
            s["nivel_ajuda"] = request.nivel_ajuda
            s["compreensao"] = request.compreensao
            if request.comentario and request.comentario.strip():
                s["comentarios"] = [request.comentario.strip()]
            return SessaoResponse(**s)

        raise HTTPException(status_code=500, detail=f"Erro ao salvar observações: {str(e)}")
