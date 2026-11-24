import uuid
import base64
import os
import logging
from fastapi import APIRouter, HTTPException, Depends, File, UploadFile, status
from ..core.database import get_db_connection
from ..core.security import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_professor_id,
)
from ..schemas.auth_schema import (
    RegisterRequest,
    LoginRequest,
    UpdateProfileRequest,
    ProfessorResponse,
    AuthTokenResponse,
)
from ..schemas.preferencia_schema import PreferenciaResponse, PreferenciaUpdateRequest

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Autenticação e Configurações"])

# In-memory storage para fallback em modo dev sem Docker DB
_IN_MEMORY_PROFESSORES = {}


@router.post("/register", response_model=AuthTokenResponse)
def register_professor(request: RegisterRequest):
    email_lower = request.email.lower().strip()
    senha_hashed = hash_password(request.senha)

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id FROM professor WHERE lower(email) = %s", (email_lower,))
                if cur.fetchone():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Este e-mail já está cadastrado no sistema.",
                    )

                prof_id = str(uuid.uuid4())
                cur.execute(
                    """
                    INSERT INTO professor (id, nome, sobrenome, email, senha_hash, instituicao, especialidade)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (prof_id, request.nome, request.sobrenome, email_lower, senha_hashed, request.instituicao, request.especialidade),
                )
                cur.execute(
                    """
                    INSERT INTO preferencia_professor (professor_id)
                    VALUES (%s::uuid)
                    ON CONFLICT (professor_id) DO NOTHING
                    """,
                    (prof_id,),
                )
                conn.commit()

                professor_data = ProfessorResponse(
                    id=prof_id,
                    nome=request.nome,
                    sobrenome=request.sobrenome,
                    email=email_lower,
                    instituicao=request.instituicao,
                    especialidade=request.especialidade,
                )
                token = create_access_token({"sub": prof_id, "email": email_lower})
                return AuthTokenResponse(access_token=token, professor=professor_data)

    except HTTPException:
        raise
    except Exception:
        prof_id = str(uuid.uuid4())
        prof_dict = {
            "id": prof_id,
            "nome": request.nome,
            "sobrenome": request.sobrenome,
            "email": email_lower,
            "senha_hash": senha_hashed,
            "foto_url": None,
            "instituicao": request.instituicao,
            "especialidade": request.especialidade,
        }
        _IN_MEMORY_PROFESSORES[prof_id] = prof_dict

        professor_data = ProfessorResponse(
            id=prof_id,
            nome=request.nome,
            sobrenome=request.sobrenome,
            email=email_lower,
            instituicao=request.instituicao,
            especialidade=request.especialidade,
        )
        token = create_access_token({"sub": prof_id, "email": email_lower})
        return AuthTokenResponse(access_token=token, professor=professor_data)


@router.post("/login", response_model=AuthTokenResponse)
def login_professor(request: LoginRequest):
    email_lower = request.email.lower().strip()

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, nome, sobrenome, email, senha_hash, foto_url, instituicao, especialidade FROM professor WHERE lower(email) = %s AND ativo = TRUE",
                    (email_lower,),
                )
                row = cur.fetchone()
                if not row or not verify_password(request.senha, row[4]):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="E-mail ou senha incorretos.",
                    )

                prof_id = str(row[0])
                nome = row[1]
                sobrenome = row[2]
                email = row[3]
                foto_url = row[5]
                instituicao = row[6]
                especialidade = row[7]

                professor_data = ProfessorResponse(
                    id=prof_id,
                    nome=nome,
                    sobrenome=sobrenome,
                    email=email,
                    foto_url=foto_url,
                    instituicao=instituicao,
                    especialidade=especialidade,
                )
                token = create_access_token({"sub": prof_id, "email": email})
                return AuthTokenResponse(access_token=token, professor=professor_data)

    except HTTPException:
        raise
    except Exception:
        for prof_id, p in _IN_MEMORY_PROFESSORES.items():
            if p["email"] == email_lower and verify_password(request.senha, p["senha_hash"]):
                professor_data = ProfessorResponse(
                    id=prof_id,
                    nome=p["nome"],
                    sobrenome=p["sobrenome"],
                    email=p["email"],
                    foto_url=p.get("foto_url"),
                    instituicao=p.get("instituicao"),
                    especialidade=p.get("especialidade"),
                )
                token = create_access_token({"sub": prof_id, "email": email_lower})
                return AuthTokenResponse(access_token=token, professor=professor_data)

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha incorretos.",
        )


@router.get("/me", response_model=ProfessorResponse)
def get_current_user_profile(prof_id: str = Depends(get_current_professor_id)):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, nome, sobrenome, email, foto_url, instituicao, especialidade FROM professor WHERE id::text = %s",
                    (prof_id,),
                )
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=404, detail="Professor não encontrado.")
                return ProfessorResponse(
                    id=str(row[0]),
                    nome=row[1],
                    sobrenome=row[2],
                    email=row[3],
                    foto_url=row[4],
                    instituicao=row[5],
                    especialidade=row[6],
                )
    except HTTPException:
        raise
    except Exception:
        if prof_id in _IN_MEMORY_PROFESSORES:
            p = _IN_MEMORY_PROFESSORES[prof_id]
            return ProfessorResponse(
                id=p["id"],
                nome=p["nome"],
                sobrenome=p["sobrenome"],
                email=p["email"],
                foto_url=p.get("foto_url"),
                instituicao=p.get("instituicao"),
                especialidade=p.get("especialidade"),
            )
        raise HTTPException(status_code=404, detail="Professor não encontrado.")


@router.patch("/me", response_model=ProfessorResponse)
def update_user_profile(
    request: UpdateProfileRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                if request.nome:
                    cur.execute("UPDATE professor SET nome = %s WHERE id::text = %s", (request.nome, prof_id))
                if request.sobrenome:
                    cur.execute("UPDATE professor SET sobrenome = %s WHERE id::text = %s", (request.sobrenome, prof_id))
                if request.foto_url:
                    cur.execute("UPDATE professor SET foto_url = %s WHERE id::text = %s", (request.foto_url, prof_id))
                if request.instituicao:
                    cur.execute("UPDATE professor SET instituicao = %s WHERE id::text = %s", (request.instituicao, prof_id))
                if request.especialidade:
                    cur.execute("UPDATE professor SET especialidade = %s WHERE id::text = %s", (request.especialidade, prof_id))

                cur.execute("UPDATE professor SET atualizado_em = now() WHERE id::text = %s", (prof_id,))
                conn.commit()

                cur.execute(
                    "SELECT id, nome, sobrenome, email, foto_url, instituicao, especialidade FROM professor WHERE id::text = %s",
                    (prof_id,),
                )
                row = cur.fetchone()
                return ProfessorResponse(
                    id=str(row[0]),
                    nome=row[1],
                    sobrenome=row[2],
                    email=row[3],
                    foto_url=row[4],
                    instituicao=row[5],
                    especialidade=row[6],
                )
    except HTTPException:
        raise
    except Exception:
        if prof_id in _IN_MEMORY_PROFESSORES:
            p = _IN_MEMORY_PROFESSORES[prof_id]
            if request.nome: p["nome"] = request.nome
            if request.sobrenome: p["sobrenome"] = request.sobrenome
            if request.foto_url: p["foto_url"] = request.foto_url
            if request.instituicao: p["instituicao"] = request.instituicao
            if request.especialidade: p["especialidade"] = request.especialidade
            return ProfessorResponse(
                id=p["id"],
                nome=p["nome"],
                sobrenome=p["sobrenome"],
                email=p["email"],
                foto_url=p.get("foto_url"),
                instituicao=p.get("instituicao"),
                especialidade=p.get("especialidade"),
            )
        raise HTTPException(status_code=404, detail="Professor não encontrado.")


_COLUNAS_PREFERENCIA = (
    "tema", "escala_fonte", "alto_contraste", "som_ativo", "vibracao_ativa",
    "volume_som", "modo_execucao_padrao", "volume_voz", "velocidade_fala",
)


def _ler_preferencias(cur, prof_id: str) -> PreferenciaResponse:
    cur.execute(
        "INSERT INTO preferencia_professor (professor_id) VALUES (%s::uuid) ON CONFLICT DO NOTHING",
        (prof_id,),
    )
    cur.execute(
        f"SELECT {', '.join(_COLUNAS_PREFERENCIA)} FROM preferencia_professor WHERE professor_id = %s::uuid",
        (prof_id,),
    )
    valores = dict(zip(_COLUNAS_PREFERENCIA, cur.fetchone()))
    valores["escala_fonte"] = float(valores["escala_fonte"])
    valores["velocidade_fala"] = float(valores["velocidade_fala"])
    return PreferenciaResponse(professor_id=prof_id, **valores)


def _erro_banco_preferencias() -> HTTPException:
    # Sem fallback em memória: o app precisa saber que a preferência NÃO foi salva.
    logger.exception("Falha ao acessar preferencia_professor")
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Banco de dados indisponível. As preferências não foram lidas/salvas.",
    )


@router.get("/preferencias", response_model=PreferenciaResponse)
def get_preferencias_professor(prof_id: str = Depends(get_current_professor_id)):
    """Obtém as preferências do professor (tabela preferencia_professor)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                pref = _ler_preferencias(cur, prof_id)
            conn.commit()
            return pref
    except Exception:
        raise _erro_banco_preferencias()


@router.patch("/preferencias", response_model=PreferenciaResponse)
def update_preferencias_professor(
    request: PreferenciaUpdateRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Atualiza somente os campos enviados e devolve as preferências gravadas."""
    alteracoes = {c: v for c, v in request.model_dump(exclude_none=True).items() if c in _COLUNAS_PREFERENCIA}
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO preferencia_professor (professor_id) VALUES (%s::uuid) ON CONFLICT DO NOTHING",
                    (prof_id,),
                )
                if alteracoes:
                    atribuicoes = ", ".join(f"{c} = %s" for c in alteracoes)
                    cur.execute(
                        f"UPDATE preferencia_professor SET {atribuicoes} WHERE professor_id = %s::uuid",
                        (*alteracoes.values(), prof_id),
                    )
                pref = _ler_preferencias(cur, prof_id)
            conn.commit()
            return pref
    except Exception:
        raise _erro_banco_preferencias()
