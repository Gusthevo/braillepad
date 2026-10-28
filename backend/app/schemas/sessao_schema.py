from pydantic import BaseModel, Field

class SessaoIniciarRequest(BaseModel):
    aluno_id: str = Field(..., example="uuid-do-aluno")
    atividade_id: str = Field(..., example="uuid-da-atividade")
    turma_id: str = Field(..., example="uuid-da-turma")
    modo_entrada: str = Field(default="MANUAL", example="MANUAL", description="MANUAL ou SIMULACAO")
    encerrar_anterior: bool = Field(default=False, description="Encerrar sessão anterior em andamento como PARCIAL")


class LeituraFichaRequest(BaseModel):
    alvo_id: str = Field(..., example="uuid-do-alvo")
    posicao: int = Field(default=1, ge=1, example=1)
    ficha_codigo: str = Field(..., example="VOGAL_A")
    correta: bool = Field(default=True, example=True)


class SessaoFinalizarRequest(BaseModel):
    nivel_ajuda: str = Field(default="NENHUMA", example="NENHUMA", description="NENHUMA, VERBAL, FISICA")
    compreensao: str | None = Field(default="TOTAL", example="TOTAL", description="TOTAL, PARCIAL, NENHUMA")
    comentario: str | None = Field(default=None, example="O aluno respondeu com autonomia.")


class LeituraResponse(BaseModel):
    id: str
    posicao: int
    ficha_codigo: str
    correta: bool
    registrada_em: str


class SessaoResponse(BaseModel):
    id: str
    professor_id: str
    aluno_id: str
    aluno_nome: str
    atividade_id: str
    atividade_titulo: str
    turma_historica_id: str
    modo_entrada: str
    status: str  # EM_ANDAMENTO, CONCLUIDA, PARCIAL
    iniciada_em: str
    finalizada_em: str | None = None
    nota: float | None = None
    total_tentativas: int = 0
    nivel_ajuda: str | None = None
    compreensao: str | None = None
    comentarios: list[str] = []
