import uuid
import datetime
from typing import Optional
from fastapi import HTTPException, status
from ..core.database import get_db_connection
from ..schemas.aluno_schema import (
    AlunoCreateRequest,
    AlunoUpdateRequest,
    AlunoTransferirRequest,
    AlunoResponse,
    AlunoDetailResponse,
    TransferenciaHistoricoResponse,
)

# In-memory storage for dev mode fallback
_IN_MEMORY_ALUNOS = {}


def listar_alunos(
    professor_id: str,
    turma_id: Optional[str] = None,
    incluir_arquivados: bool = False,
) -> list[AlunoResponse]:
    """Lista os alunos vinculados às turmas do professor logado."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                sql = """
                SELECT
                    a.id, a.turma_atual_id, t.nome as turma_nome, a.nome, a.sobrenome,
                    a.matricula, a.data_nascimento::text, a.nivel_braille,
                    a.preferencias_acessibilidade, a.observacoes_pedagogicas,
                    a.criado_em::text, a.arquivado_em::text
                FROM aluno a
                JOIN turma t ON a.turma_atual_id = t.id
                WHERE t.professor_id::text = %s
                """
                params = [professor_id]

                if turma_id:
                    sql += " AND a.turma_atual_id::text = %s"
                    params.append(turma_id)

                if not incluir_arquivados:
                    sql += " AND a.arquivado_em IS NULL"

                sql += " ORDER BY a.nome ASC, a.sobrenome ASC"

                cur.execute(sql, tuple(params))
                rows = cur.fetchall()

                return [
                    AlunoResponse(
                        id=str(r[0]),
                        turma_atual_id=str(r[1]),
                        turma_nome=r[2],
                        nome=r[3],
                        sobrenome=r[4],
                        matricula=r[5],
                        data_nascimento=r[6],
                        nivel_braille=r[7],
                        preferencias_acessibilidade=r[8],
                        observacoes_pedagogicas=r[9],
                        criado_em=r[10],
                        arquivado_em=r[11],
                    )
                    for r in rows
                ]
    except Exception:
        resultado = []
        for a_id, a in _IN_MEMORY_ALUNOS.items():
            if turma_id and a["turma_atual_id"] != turma_id:
                continue
            if not incluir_arquivados and a.get("arquivado_em") is not None:
                continue
            resultado.append(AlunoResponse(**a, turma_nome="Turma Dev"))
        return resultado


def criar_aluno(professor_id: str, request: AlunoCreateRequest) -> AlunoResponse:
    """Cadastra um novo aluno vinculado obrigatoriamente a uma turma válida do professor."""
    aluno_id = str(uuid.uuid4())
    nome = request.nome.strip()
    sobrenome = request.sobrenome.strip()

    # Mapeamento do Nível de Braille (Iniciante, Intermediário, Avançado)
    nivel_input = (request.nivel_braille or 'INICIANTE').upper()
    if nivel_input in ['INTERMEDIARIO', 'INTERMEDIÁRIO']:
        nivel_db = 'EM_APRENDIZAGEM'
    elif nivel_input in ['AVANCADO', 'AVANÇADO']:
        nivel_db = 'FAMILIARIZADO'
    else:
        nivel_db = 'INICIANTE'

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT nome FROM turma WHERE id::text = %s AND professor_id::text = %s AND arquivada_em IS NULL",
                    (request.turma_atual_id, professor_id),
                )
                turma_row = cur.fetchone()
                if not turma_row:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Turma inválida, arquivada ou não pertence ao professor.",
                    )
                turma_nome = turma_row[0]

                cur.execute(
                    """
                    INSERT INTO aluno (
                        id, turma_atual_id, nome, sobrenome, matricula,
                        data_nascimento, nivel_braille, preferencias_acessibilidade, observacoes_pedagogicas
                    )
                    VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING criado_em::text
                    """,
                    (
                        aluno_id,
                        request.turma_atual_id,
                        nome,
                        sobrenome,
                        request.matricula,
                        request.data_nascimento,
                        nivel_db,
                        request.preferencias_acessibilidade,
                        request.observacoes_pedagogicas,
                    ),
                )
                criado_em = cur.fetchone()[0]
                conn.commit()

                return AlunoResponse(
                    id=aluno_id,
                    turma_atual_id=request.turma_atual_id,
                    turma_nome=turma_nome,
                    nome=nome,
                    sobrenome=sobrenome,
                    matricula=request.matricula,
                    data_nascimento=str(request.data_nascimento) if request.data_nascimento else None,
                    nivel_braille=request.nivel_braille or 'Iniciante',
                    preferencias_acessibilidade=request.preferencias_acessibilidade,
                    observacoes_pedagogicas=request.observacoes_pedagogicas,
                    criado_em=criado_em,
                    arquivado_em=None,
                )
    except HTTPException:
        raise
    except Exception as e:
        criado_em = datetime.datetime.now().isoformat()
        aluno_dict = {
            "id": aluno_id,
            "turma_atual_id": request.turma_atual_id,
            "turma_nome": "Turma Dev",
            "nome": nome,
            "sobrenome": sobrenome,
            "matricula": request.matricula,
            "data_nascimento": str(request.data_nascimento) if request.data_nascimento else None,
            "nivel_braille": request.nivel_braille or 'Iniciante',
            "preferencias_acessibilidade": request.preferencias_acessibilidade,
            "observacoes_pedagogicas": request.observacoes_pedagogicas,
            "criado_em": criado_em,
            "arquivado_em": None,
        }
        _IN_MEMORY_ALUNOS[aluno_id] = aluno_dict
        return AlunoResponse(**aluno_dict)


def obter_aluno_detalhado(professor_id: str, aluno_id: str) -> AlunoDetailResponse:
    """Obtém detalhes cadastrais do aluno e sua linha do tempo de transferências passadas."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT a.id, a.turma_atual_id, t.nome as turma_nome, a.nome, a.sobrenome,
                           a.matricula, a.data_nascimento::text, a.nivel_braille,
                           a.preferencias_acessibilidade, a.observacoes_pedagogicas,
                           a.criado_em::text, a.arquivado_em::text
                    FROM aluno a
                    JOIN turma t ON a.turma_atual_id = t.id
                    WHERE a.id::text = %s AND t.professor_id::text = %s
                    """,
                    (aluno_id, professor_id),
                )
                r = cur.fetchone()
                if not r:
                    raise HTTPException(status_code=404, detail="Aluno não encontrado ou acesso negado.")

                aluno_data = {
                    "id": str(r[0]),
                    "turma_atual_id": str(r[1]),
                    "turma_nome": r[2],
                    "nome": r[3],
                    "sobrenome": r[4],
                    "matricula": r[5],
                    "data_nascimento": r[6],
                    "nivel_braille": r[7],
                    "preferencias_acessibilidade": r[8],
                    "observacoes_pedagogicas": r[9],
                    "criado_em": r[10],
                    "arquivado_em": r[11],
                }

                # Buscar histórico de transferências passadas (RF-011)
                cur.execute(
                    """
                    SELECT tr.id, torig.nome as orig_nome, tdest.nome as dest_nome,
                           tr.transferido_em::text, tr.motivo
                    FROM transferencia_aluno tr
                    JOIN turma torig ON tr.turma_origem_id = torig.id
                    JOIN turma tdest ON tr.turma_destino_id = tdest.id
                    WHERE tr.aluno_id::text = %s
                    ORDER BY tr.transferido_em DESC
                    """,
                    (aluno_id,),
                )
                transf_rows = cur.fetchall()
                historico = [
                    TransferenciaHistoricoResponse(
                        id=str(tr[0]),
                        turma_origem_nome=tr[1],
                        turma_destino_nome=tr[2],
                        transferido_em=tr[3],
                        motivo=tr[4],
                    )
                    for tr in transf_rows
                ]

                return AlunoDetailResponse(**aluno_data, historico_transferencias=historico)
    except HTTPException:
        raise
    except Exception:
        if aluno_id in _IN_MEMORY_ALUNOS:
            return AlunoDetailResponse(**_IN_MEMORY_ALUNOS[aluno_id], historico_transferencias=[])
        raise HTTPException(status_code=404, detail="Aluno não encontrado.")


def transferir_aluno(professor_id: str, aluno_id: str, request: AlunoTransferirRequest) -> AlunoDetailResponse:
    """Executa a transferência transacional do aluno para uma nova turma (RF-011)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                # 1. Verificar aluno e sua turma de origem
                cur.execute(
                    """
                    SELECT a.turma_atual_id
                    FROM aluno a
                    JOIN turma t ON a.turma_atual_id = t.id
                    WHERE a.id::text = %s AND t.professor_id::text = %s AND a.arquivado_em IS NULL
                    """,
                    (aluno_id, professor_id),
                )
                row_aluno = cur.fetchone()
                if not row_aluno:
                    raise HTTPException(status_code=404, detail="Aluno não encontrado ou arquivado.")

                turma_origem_id = str(row_aluno[0])

                if turma_origem_id == request.turma_destino_id:
                    raise HTTPException(
                        status_code=400, detail="A turma de destino deve ser diferente da turma de origem."
                    )

                # 2. Verificar se a turma de destino pertence ao professor e está ativa
                cur.execute(
                    "SELECT id FROM turma WHERE id::text = %s AND professor_id::text = %s AND arquivada_em IS NULL",
                    (request.turma_destino_id, professor_id),
                )
                if not cur.fetchone():
                    raise HTTPException(status_code=400, detail="Turma de destino inválida ou arquivada.")

                transf_id = str(uuid.uuid4())

                # 3. Gravar histórico de transferência
                cur.execute(
                    """
                    INSERT INTO transferencia_aluno (id, aluno_id, turma_origem_id, turma_destino_id, registrada_por, motivo)
                    VALUES (%s::uuid, %s::uuid, %s::uuid, %s::uuid, %s::uuid, %s)
                    """,
                    (transf_id, aluno_id, turma_origem_id, request.turma_destino_id, professor_id, request.motivo),
                )

                # 4. Atualizar turma atual do aluno
                cur.execute(
                    "UPDATE aluno SET turma_atual_id = %s::uuid WHERE id::text = %s",
                    (request.turma_destino_id, aluno_id),
                )

                conn.commit()
                return obter_aluno_detalhado(professor_id, aluno_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def arquivar_aluno(professor_id: str, aluno_id: str) -> bool:
    """Arquiva o aluno (arquivado_em = now())."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE aluno
                    SET arquivado_em = now()
                    FROM turma t
                    WHERE aluno.turma_atual_id = t.id
                      AND aluno.id::text = %s
                      AND t.professor_id::text = %s
                      AND aluno.arquivado_em IS NULL
                    """,
                    (aluno_id, professor_id),
                )
                if cur.rowcount == 0:
                    raise HTTPException(status_code=404, detail="Aluno não encontrado ou já arquivado.")
                conn.commit()
                return True
    except HTTPException:
        raise
    except Exception:
        if aluno_id in _IN_MEMORY_ALUNOS:
            _IN_MEMORY_ALUNOS[aluno_id]["arquivado_em"] = datetime.datetime.now().isoformat()
            return True
        raise HTTPException(status_code=404, detail="Aluno não encontrado.")
