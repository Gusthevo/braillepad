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


def listar_turmas(professor_id: str, incluir_arquivadas: bool = False) -> list[TurmaResponse]:
    """Lista as turmas do professor logado no PostgreSQL com contagem de alunos."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            sql = """
            SELECT
                t.id, t.professor_id, t.nome, t.descricao, t.ano_letivo,
                t.ano_escolar, t.turno, t.criada_em::text, t.arquivada_em::text,
                COUNT(a.id) FILTER (WHERE a.arquivado_em IS NULL) as total_alunos
            FROM turma t
            LEFT JOIN aluno a ON a.turma_atual_id = t.id
            WHERE t.professor_id::text = %s
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


def criar_turma(professor_id: str, request: TurmaCreateRequest) -> TurmaResponse:
    """Cria uma nova turma vinculada ao professor autenticado gravando no PostgreSQL."""
    turma_id = str(uuid.uuid4())
    nome = request.nome.strip()
    descricao = request.descricao.strip() if request.descricao else ""

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO turma (id, professor_id, nome, descricao, ano_letivo, ano_escolar, turno)
                VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s)
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


def obter_turma_detalhada(professor_id: str, turma_id: str) -> TurmaDetailResponse:
    """Obtém detalhes da turma e lista de alunos vinculados."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, professor_id, nome, descricao, ano_letivo, ano_escolar, turno, criada_em::text, arquivada_em::text
                FROM turma
                WHERE id::text = %s AND professor_id::text = %s
                """,
                (turma_id, professor_id),
            )
            r = cur.fetchone()
            if not r:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Turma não encontrada ou acesso não autorizado.",
                )

            cur.execute(
                """
                SELECT id, nome, sobrenome, nivel_braille
                FROM aluno
                WHERE turma_atual_id::text = %s AND arquivado_em IS NULL
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


def atualizar_turma(professor_id: str, turma_id: str, request: TurmaUpdateRequest) -> TurmaResponse:
    """Atualiza dados de uma turma existente."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM turma WHERE id::text = %s AND professor_id::text = %s", (turma_id, professor_id))
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Turma não encontrada.")

            if request.nome:
                cur.execute("UPDATE turma SET nome = %s WHERE id::text = %s", (request.nome.strip(), turma_id))
            if request.descricao is not None:
                cur.execute("UPDATE turma SET descricao = %s WHERE id::text = %s", (request.descricao.strip(), turma_id))
            if request.ano_letivo is not None:
                cur.execute("UPDATE turma SET ano_letivo = %s WHERE id::text = %s", (request.ano_letivo, turma_id))
            if request.ano_escolar is not None:
                cur.execute("UPDATE turma SET ano_escolar = %s WHERE id::text = %s", (request.ano_escolar, turma_id))
            if request.turno is not None:
                cur.execute("UPDATE turma SET turno = %s WHERE id::text = %s", (request.turno, turma_id))

            conn.commit()
            return obter_turma_detalhada(professor_id, turma_id)


def arquivar_turma(professor_id: str, turma_id: str) -> bool:
    """Arquiva uma turma (arquivada_em = now())."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE turma SET arquivada_em = now() WHERE id::text = %s AND professor_id::text = %s AND arquivada_em IS NULL",
                (turma_id, professor_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Turma não encontrada ou já arquivada.")
            conn.commit()
            return True


def desarquivar_turma(professor_id: str, turma_id: str) -> bool:
    """Desarquiva uma turma (arquivada_em = NULL)."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE turma SET arquivada_em = NULL WHERE id::text = %s AND professor_id::text = %s",
                (turma_id, professor_id),
            )
            conn.commit()
            return True
