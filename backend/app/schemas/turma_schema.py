from datetime import datetime
from pydantic import BaseModel, Field

class TurmaCreateRequest(BaseModel):
    nome: str = Field(..., min_length=2, example="Turma A - Manhã")
    descricao: str = Field(default="", example="Atendimento Educacional Especializado no turno matutino")
    ano_letivo: int | None = Field(default=2026, ge=2020, le=2200, example=2026)
    ano_escolar: str | None = Field(default="1º Ano", example="1º Ano do Ensino Fundamental")
    turno: str | None = Field(default="MANHA", example="MANHA", description="MANHA, TARDE, NOITE, INTEGRAL")


class TurmaUpdateRequest(BaseModel):
    nome: str | None = None
    descricao: str | None = None
    ano_letivo: int | None = None
    ano_escolar: str | None = None
    turno: str | None = None


class AlunoSimplesResponse(BaseModel):
    id: str
    nome: str
    sobrenome: str
    familiaridade_braille: str | None = None


class TurmaResponse(BaseModel):
    id: str
    professor_id: str
    nome: str
    descricao: str
    ano_letivo: int | None = None
    ano_escolar: str | None = None
    turno: str | None = None
    criada_em: str
    arquivada_em: str | None = None
    total_alunos: int = 0


class TurmaDetailResponse(TurmaResponse):
    alunos: list[AlunoSimplesResponse] = []
