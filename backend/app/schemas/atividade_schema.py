from pydantic import BaseModel, Field

class ModuloResponse(BaseModel):
    id: int
    numero: int
    categoria: str
    nome: str
    descricao: str
    total_atividades: int = 10


class AtividadeResponse(BaseModel):
    id: str
    modulo_id: int
    numero: int
    titulo: str
    descricao: str
    objetivo: str | None = None
    obrigatoria: bool = True
    publicada: bool = True


class FichaResponse(BaseModel):
    id: str
    codigo: str
    tipo: str
    representacao: str
    descricao: str | None = None


class AlvoResponse(BaseModel):
    id: str
    tipo_alvo: str
    valor_esperado: str
    ordem: int
    fichas_esperadas: list[FichaResponse] = []


class FaseResponse(BaseModel):
    id: str
    ordem: int
    titulo: str
    tipo_fase: str
    pontuavel: bool = True
    sequenciamento: str = "FIXO"
    alvos: list[AlvoResponse] = []


class AtividadeDetailResponse(AtividadeResponse):
    fases: list[FaseResponse] = []
