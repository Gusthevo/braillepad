import uuid
import base64
import os
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

router = APIRouter(prefix="/api/auth", tags=["Autenticação e Configurações"])

# In-memory storage para fallback em modo dev sem Docker DB
_IN_MEMORY_PROFESSORES = {}
_IN_MEMORY_PREFERENCIAS = {}


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


@router.get("/preferencias", response_model=PreferenciaResponse)
def get_preferencias_professor(prof_id: str = Depends(get_current_professor_id)):
    """Obtém as preferências reais do professor salvas na tabela 'preferencia_professor' do PostgreSQL."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT professor_id, tema, escala_fonte, alto_contraste, som_ativo, vibracao_ativa, volume_som, modo_execucao_padrao
                    FROM preferencia_professor
                    WHERE professor_id::text = %s
                    """,
                    (prof_id,),
                )
                row = cur.fetchone()
                if not row:
                    cur.execute(
                        "INSERT INTO preferencia_professor (professor_id) VALUES (%s::uuid) ON CONFLICT DO NOTHING",
                        (prof_id,),
                    )
                    conn.commit()
                    return PreferenciaResponse(professor_id=prof_id)

                return PreferenciaResponse(
                    professor_id=str(row[0]),
                    tema=row[1],
                    escala_fonte=float(row[2]),
                    alto_contraste=row[3],
                    som_ativo=row[4],
                    vibracao_ativa=row[5],
                    volume_som=row[6],
                    modo_execucao_padrao=row[7],
                )
    except Exception:
        pref = _IN_MEMORY_PREFERENCIAS.get(prof_id, PreferenciaResponse(professor_id=prof_id).dict())
        return PreferenciaResponse(**pref)


@router.patch("/preferencias", response_model=PreferenciaResponse)
def update_preferencias_professor(
    request: PreferenciaUpdateRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Atualiza as preferências reais do professor salvas na tabela 'preferencia_professor' do PostgreSQL."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO preferencia_professor (professor_id) VALUES (%s::uuid) ON CONFLICT DO NOTHING",
                    (prof_id,),
                )
                if request.tema:
                    cur.execute("UPDATE preferencia_professor SET tema = %s WHERE professor_id::text = %s", (request.tema, prof_id))
                if request.escala_fonte is not None:
                    cur.execute("UPDATE preferencia_professor SET escala_fonte = %s WHERE professor_id::text = %s", (request.escala_fonte, prof_id))
                if request.alto_contraste is not None:
                    cur.execute("UPDATE preferencia_professor SET alto_contraste = %s WHERE professor_id::text = %s", (request.alto_contraste, prof_id))
                if request.som_ativo is not None:
                    cur.execute("UPDATE preferencia_professor SET som_ativo = %s WHERE professor_id::text = %s", (request.som_ativo, prof_id))
                if request.vibracao_ativa is not None:
                    cur.execute("UPDATE preferencia_professor SET vibracao_ativa = %s WHERE professor_id::text = %s", (request.vibracao_ativa, prof_id))
                if request.volume_som is not None:
                    cur.execute("UPDATE preferencia_professor SET volume_som = %s WHERE professor_id::text = %s", (request.volume_som, prof_id))
                if request.modo_execucao_padrao:
                    cur.execute("UPDATE preferencia_professor SET modo_execucao_padrao = %s WHERE professor_id::text = %s", (request.modo_execucao_padrao, prof_id))

                conn.commit()
                return get_preferencias_professor(prof_id=prof_id)
    except HTTPException:
        raise
    except Exception:
        pref = _IN_MEMORY_PREFERENCIAS.get(prof_id, PreferenciaResponse(professor_id=prof_id).dict())
        if request.tema: pref["tema"] = request.tema
        if request.escala_fonte is not None: pref["escala_fonte"] = request.escala_fonte
        if request.alto_contraste is not None: pref["alto_contraste"] = request.alto_contraste
        if request.som_ativo is not None: pref["som_ativo"] = request.som_ativo
        if request.vibracao_ativa is not None: pref["vibracao_ativa"] = request.vibracao_ativa
        if request.volume_som is not None: pref["volume_som"] = request.volume_som
        if request.modo_execucao_padrao: pref["modo_execucao_padrao"] = request.modo_execucao_padrao
        _IN_MEMORY_PREFERENCIAS[prof_id] = pref
        return PreferenciaResponse(**pref)
