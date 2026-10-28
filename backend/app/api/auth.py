import uuid
import base64
import os
from fastapi import APIRouter, HTTPException, Depends, File, UploadFile, status
from ..core.database import get_db_connection
from ..core.config import settings
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

router = APIRouter(prefix="/api/auth", tags=["Autenticação"])

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
                cur.execute("INSERT INTO preferencia_professor (professor_id) VALUES (%s)", (prof_id,))
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

                prof_id, nome, sobrenome, email, _, foto_url, instituicao, especialidade = row
                prof_id = str(prof_id)

                cur.execute(
                    "INSERT INTO sessao_autenticacao (professor_id, refresh_token_hash, expira_em) VALUES (%s, %s, now() + interval '30 days')",
                    (prof_id, str(uuid.uuid4())),
                )
                conn.commit()

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
                    "SELECT id, nome, sobrenome, email, foto_url, instituicao, especialidade FROM professor WHERE id = %s",
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
                    cur.execute("UPDATE professor SET nome = %s WHERE id = %s", (request.nome, prof_id))
                if request.sobrenome:
                    cur.execute("UPDATE professor SET sobrenome = %s WHERE id = %s", (request.sobrenome, prof_id))
                if request.foto_url:
                    cur.execute("UPDATE professor SET foto_url = %s WHERE id = %s", (request.foto_url, prof_id))
                if request.instituicao:
                    cur.execute("UPDATE professor SET instituicao = %s WHERE id = %s", (request.instituicao, prof_id))
                if request.especialidade:
                    cur.execute("UPDATE professor SET especialidade = %s WHERE id = %s", (request.especialidade, prof_id))

                cur.execute("UPDATE professor SET atualizado_em = now() WHERE id = %s", (prof_id,))
                conn.commit()

                cur.execute(
                    "SELECT id, nome, sobrenome, email, foto_url, instituicao, especialidade FROM professor WHERE id = %s",
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
    except Exception as e:
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
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/me/photo", response_model=ProfessorResponse)
async def upload_profile_photo(
    file: UploadFile = File(...),
    prof_id: str = Depends(get_current_professor_id),
):
    try:
        content = await file.read()
        file_ext = file.filename.split(".")[-1] if file.filename and "." in file.filename else "jpg"
        filename = f"avatar_{prof_id}.{file_ext}"
        filepath = os.path.join(settings.UPLOAD_DIR, filename)

        with open(filepath, "wb") as f:
            f.write(content)

        foto_url = f"/static/uploads/{filename}"

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("UPDATE professor SET foto_url = %s, atualizado_em = now() WHERE id = %s", (foto_url, prof_id))
                conn.commit()

                cur.execute(
                    "SELECT id, nome, sobrenome, email, foto_url, instituicao, especialidade FROM professor WHERE id = %s",
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
    except Exception as e:
        encoded = base64.b64encode(content).decode("utf-8")
        foto_url = f"data:image/png;base64,{encoded}"
        if prof_id in _IN_MEMORY_PROFESSORES:
            _IN_MEMORY_PROFESSORES[prof_id]["foto_url"] = foto_url
            p = _IN_MEMORY_PROFESSORES[prof_id]
            return ProfessorResponse(
                id=p["id"],
                nome=p["nome"],
                sobrenome=p["sobrenome"],
                email=p["email"],
                foto_url=foto_url,
                instituicao=p.get("instituicao"),
                especialidade=p.get("especialidade"),
            )
        raise HTTPException(status_code=500, detail=str(e))
