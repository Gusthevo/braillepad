from datetime import date
from pydantic import BaseModel, Field

class AlunoCreateRequest(BaseModel):
    turma_atual_id: str = Field(..., example="uuid-da-turma", description="ID da turma atual obrigatória")
    nome: str = Field(..., min_length=2, example="João")
    sobrenome: str = Field(..., min_length=2, example="Oliveira")
    matricula: str | None = Field(default=None, example="2026-001")
    data_nascimento: date | None = Field(default=None, example="2018-05-12")
    nivel_braille: str | None = Field(default="INICIANTE", example="INICIANTE", description="INICIANTE, EM_APRENDIZAGEM, FAMILIARIZADO")
    preferencias_acessibilidade: str | None = Field(default=None, example="Alto contraste e áudio reforçado")
    observacoes_pedagogicas: str | None = Field(default=None, example="Apresenta boa percepção tátil na mão direita")


class AlunoUpdateRequest(BaseModel):
    nome: str | None = None
    sobrenome: str | None = None
    matricula: str | None = None
    data_nascimento: date | None = None
    nivel_braille: str | None = None
    preferencias_acessibilidade: str | None = None
    observacoes_pedagogicas: str | None = None


class AlunoTransferirRequest(BaseModel):
    turma_destino_id: str = Field(..., example="uuid-da-nova-turma", description="ID da turma de destino para transferência")
    motivo: str | None = Field(default=None, example="Mudança de turno ou evolução pedagógica")


class TransferenciaHistoricoResponse(BaseModel):
    id: str
    turma_origem_nome: str
    turma_destino_nome: str
    transferido_em: str
    motivo: str | None = None


class AlunoResponse(BaseModel):
    id: str
    turma_atual_id: str
    turma_nome: str
    nome: str
    sobrenome: str
    matricula: str | None = None
    data_nascimento: str | None = None
    nivel_braille: str | None = None
    preferencias_acessibilidade: str | None = None
    observacoes_pedagogicas: str | None = None
    criado_em: str
    arquivado_em: str | None = None


class AlunoDetailResponse(AlunoResponse):
    historico_transferencias: list[TransferenciaHistoricoResponse] = []
