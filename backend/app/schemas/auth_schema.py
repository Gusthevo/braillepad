from pydantic import BaseModel, EmailStr, Field

class RegisterRequest(BaseModel):
    nome: str = Field(..., min_length=2, example="Maria")
    sobrenome: str = Field(..., min_length=2, example="Silva")
    email: EmailStr = Field(..., example="professora.maria@escola.edu.br")
    senha: str = Field(..., min_length=6, example="SenhaForte123")
    instituicao: str | None = Field(default=None, example="Escola Municipal AEE")
    especialidade: str | None = Field(default=None, example="Educação Especial")


class LoginRequest(BaseModel):
    email: EmailStr = Field(..., example="professora.maria@escola.edu.br")
    senha: str = Field(..., example="SenhaForte123")


class UpdateProfileRequest(BaseModel):
    nome: str | None = None
    sobrenome: str | None = None
    foto_url: str | None = None
    instituicao: str | None = None
    especialidade: str | None = None


class ProfessorResponse(BaseModel):
    id: str
    nome: str
    sobrenome: str
    email: str
    foto_url: str | None = None
    instituicao: str | None = None
    especialidade: str | None = None


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    professor: ProfessorResponse
