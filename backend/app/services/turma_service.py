import uuid
from typing import Optional
from fastapi import HTTPException, status
from ..core.database import get_db_connection
from ..schemas.turma_schema import (
    TurmaCreateRequest,
    TurmaUpdateRequest,
    TurmaResponse,
    TurmaDetailResponse,
    AlunoSimplesResponse,
)

# In-memory storage for dev mode fallback
_IN_MEMORY_TURMAS = {}


def listar_turmas(professor_id: str, incluir_arquivadas: bool = False) -> list[TurmaResponse]:
    """Lista as turmas do professor logado com contagem de alunos."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                sql = """
                SELECT
                    t.id, t.professor_id, t.nome, t.descricao, t.ano_letivo,
                    t.ano_escolar, t.turno, t.criada_em::text, t.arquivada_em::text,
                    COUNT(a.id) FILTER (WHERE a.arquivado_em IS NULL) as total_alunos
                FROM turma t
                LEFT JOIN aluno a ON a.turma_atual_id = t.id
                WHERE t.professor_id = %s
                """
                if not incluir_arquivadas:
                    sql += " AND t.arquivada_em IS NULL"

                sql += " GROUP BY t.id ORDER BY t.criada_em DESC"

                cur.execute(sql, (professor_id,))
                rows = cur.fetchall()

                return [
                    TurmaResponse(
                        id=str(r[0]),
                        professor_id=str(r[1]),
                        nome=r[2],
                        descricao=r[3] or "",
                        ano_letivo=r[4],
                        ano_escolar=r[5],
                        turno=r[6],
                        criada_em=r[7],
                        arquivada_em=r[8],
                        total_alunos=r[9],
                    )
                    for r in rows
                ]
    except Exception as e:
        # Fallback dev mode
        resultado = []
        for t_id, t in _IN_MEMORY_TURMAS.items():
            if t["professor_id"] == professor_id:
                if not incluir_arquivadas and t.get("arquivada_em") is not None:
                    continue
                resultado.append(
                    TurmaResponse(
                        id=t["id"],
                        professor_id=t["professor_id"],
                        nome=t["nome"],
                        descricao=t.get("descricao", ""),
                        ano_letivo=t.get("ano_letivo"),
                        ano_escolar=t.get("ano_escolar"),
                        turno=t.get("turno"),
                        criada_em=t["criada_em"],
                        arquivada_em=t.get("arquivada_em"),
                        total_alunos=len(t.get("alunos", [])),
                    )
                )
        return resultado


def criar_turma(professor_id: str, request: TurmaCreateRequest) -> TurmaResponse:
    """Cria uma nova turma vinculada ao professor autenticado."""
    turma_id = str(uuid.uuid4())
    nome = request.nome.strip()
    descricao = request.descricao.strip()

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO turma (id, professor_id, nome, descricao, ano_letivo, ano_escolar, turno)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING criada_em::text
                    """,
                    (turma_id, professor_id, nome, descricao, request.ano_letivo, request.ano_escolar, request.turno),
                )
                criada_em = cur.fetchone()[0]
                conn.commit()

                return TurmaResponse(
                    id=turma_id,
                    professor_id=professor_id,
                    nome=nome,
                    descricao=descricao,
                    ano_letivo=request.ano_letivo,
                    ano_escolar=request.ano_escolar,
                    turno=request.turno,
                    criada_em=criada_em,
                    arquivada_em=None,
                    total_alunos=0,
                )
    except Exception:
        # Fallback dev mode
        import datetime
        criada_em = datetime.datetime.now().isoformat()
        turma_dict = {
            "id": turma_id,
            "professor_id": professor_id,
            "nome": nome,
            "descricao": descricao,
            "ano_letivo": request.ano_letivo,
            "ano_escolar": request.ano_escolar,
            "turno": request.turno,
            "criada_em": criada_em,
            "arquivada_em": None,
            "alunos": [],
        }
        _IN_MEMORY_TURMAS[turma_id] = turma_dict
        return TurmaResponse(**turma_dict, total_alunos=0)


def obter_turma_detalhada(professor_id: str, turma_id: str) -> TurmaDetailResponse:
    """Obtém detalhes da turma e lista de alunos vinculados."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, professor_id, nome, descricao, ano_letivo, ano_escolar, turno, criada_em::text, arquivada_em::text
                    FROM turma
                    WHERE id = %s AND professor_id = %s
                    """,
                    (turma_id, professor_id),
                )
                r = cur.fetchone()
                if not r:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Turma não encontrada ou acesso não autorizado.",
                    )

                # Buscar alunos da turma
                cur.execute(
                    """
                    SELECT id, nome, sobrenome, nivel_braille
                    FROM aluno
                    WHERE turma_atual_id = %s AND arquivado_em IS NULL
                    ORDER BY nome ASC
                    """,
                    (turma_id,),
                )
                alunos_rows = cur.fetchall()
                alunos_list = [
                    AlunoSimplesResponse(
                        id=str(a[0]),
                        nome=a[1],
                        sobrenome=a[2],
                        familiaridade_braille=a[3],
                    )
                    for a in alunos_rows
                ]

                return TurmaDetailResponse(
                    id=str(r[0]),
                    professor_id=str(r[1]),
                    nome=r[2],
                    descricao=r[3] or "",
                    ano_letivo=r[4],
                    ano_escolar=r[5],
                    turno=r[6],
                    criada_em=r[7],
                    arquivada_em=r[8],
                    total_alunos=len(alunos_list),
                    alunos=alunos_list,
                )
    except HTTPException:
        raise
    except Exception:
        if turma_id in _IN_MEMORY_TURMAS:
            t = _IN_MEMORY_TURMAS[turma_id]
            if t["professor_id"] == professor_id:
                return TurmaDetailResponse(
                    id=t["id"],
                    professor_id=t["professor_id"],
                    nome=t["nome"],
                    descricao=t["descricao"],
                    ano_letivo=t.get("ano_letivo"),
                    ano_escolar=t.get("ano_escolar"),
                    turno=t.get("turno"),
                    criada_em=t["criada_em"],
                    arquivada_em=t.get("arquivada_em"),
                    total_alunos=len(t.get("alunos", [])),
                    alunos=t.get("alunos", []),
                )
        raise HTTPException(status_code=404, detail="Turma não encontrada.")


def atualizar_turma(professor_id: str, turma_id: str, request: TurmaUpdateRequest) -> TurmaResponse:
    """Atualiza dados de uma turma existente."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id FROM turma WHERE id = %s AND professor_id = %s", (turma_id, professor_id))
                if not cur.fetchone():
                    raise HTTPException(status_code=404, detail="Turma não encontrada.")

                if request.nome:
                    cur.execute("UPDATE turma SET nome = %s WHERE id = %s", (request.nome.strip(), turma_id))
                if request.descricao is not None:
                    cur.execute("UPDATE turma SET descricao = %s WHERE id = %s", (request.descricao.strip(), turma_id))
                if request.ano_letivo is not None:
                    cur.execute("UPDATE turma SET ano_letivo = %s WHERE id = %s", (request.ano_letivo, turma_id))
                if request.ano_escolar is not None:
                    cur.execute("UPDATE turma SET ano_escolar = %s WHERE id = %s", (request.ano_escolar, turma_id))
                if request.turno is not None:
                    cur.execute("UPDATE turma SET turno = %s WHERE id = %s", (request.turno, turma_id))

                conn.commit()
                return obter_turma_detalhada(professor_id, turma_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def arquivar_turma(professor_id: str, turma_id: str) -> bool:
    """Arquiva uma turma (arquivada_em = now())."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE turma SET arquivada_em = now() WHERE id = %s AND professor_id = %s AND arquivada_em IS NULL",
                    (turma_id, professor_id),
                )
                if cur.rowcount == 0:
                    raise HTTPException(status_code=404, detail="Turma não encontrada ou já arquivada.")
                conn.commit()
                return True
    except HTTPException:
        raise
    except Exception:
        if turma_id in _IN_MEMORY_TURMAS:
            import datetime
            _IN_MEMORY_TURMAS[turma_id]["arquivada_em"] = datetime.datetime.now().isoformat()
            return True
        raise HTTPException(status_code=404, detail="Turma não encontrada.")


def desarquivar_turma(professor_id: str, turma_id: str) -> bool:
    """Desarquiva uma turma (arquivada_em = NULL)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE turma SET arquivada_em = NULL WHERE id = %s AND professor_id = %s",
                    (turma_id, professor_id),
                )
                conn.commit()
                return True
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
