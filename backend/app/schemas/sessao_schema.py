from pydantic import BaseModel, Field

class SessaoIniciarRequest(BaseModel):
    aluno_id: str = Field(..., example="uuid-do-aluno")
    atividade_id: str = Field(..., example="uuid-da-atividade")
    turma_id: str = Field(..., example="uuid-da-turma")
    modo_entrada: str = Field(default="MANUAL", example="MANUAL", description="MANUAL ou SIMULACAO")
    encerrar_anterior: bool = Field(default=False, description="Encerrar sessão anterior em andamento como PARCIAL")


class LeituraFichaRequest(BaseModel):
    alvo_id: str = Field(..., example="uuid-do-alvo")
    posicao: int = Field(default=1, ge=1, example=1, description="Posição (1-based) da ficha dentro do alvo")
    ficha_codigo: str = Field(..., example="VOGAL_A")
    correta: bool = Field(default=True, example=True)
    tipo_fase: str | None = Field(
        default=None, example="ORDEM",
        description="Fase em que a leitura ocorreu: EXPLORAR, ORDEM, EMBARALHADA, COMPARACAO ou FORMACAO",
    )


class SessaoFinalizarRequest(BaseModel):
    duracao_segundos: int | None = Field(default=0, example=135, description="Duração total da sessão em segundos")
    total_acertos: int | None = Field(default=0, example=5, description="Total de acertos na sessão")
    total_tentativas: int | None = Field(default=0, example=10, description="Total de tentativas na sessão")
    nivel_auxilio_fase1: str | None = Field(default="INDEPENDENTE", example="INDEPENDENTE")
    nivel_auxilio_fase2: str | None = Field(default="INDEPENDENTE", example="INDEPENDENTE")
    compreensao_instrucoes: str | None = Field(default="TOTAL", example="TOTAL")
    autonomia_exploracao: str | None = Field(default="SIM", example="SIM")
    comentario: str | None = Field(default=None, example="Criança demonstrou excelente percepção das vogais.")
    avaliacao_estrelas: int | None = Field(default=5, ge=1, le=5, example=5)


class AlertaAtividadeResponse(BaseModel):
    tipo: str
    titulo: str
    mensagem: str


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
    duracao_segundos: int | None = 0
    nota: float | None = None
    percentual_acertos: float | None = 100.0
    avaliacao_estrelas: int | None = 5
    nivel_auxilio_fase1: str | None = None
    nivel_auxilio_fase2: str | None = None
    compreensao_instrucoes: str | None = None
    autonomia_exploracao: str | None = None
    comentarios: list[str] = []
    alertas_gerados: list[AlertaAtividadeResponse] = []
    modulo_categoria: str = Field(default="VOGAIS", example="VOGAIS", description="VOGAIS, SILABAS, PALAVRAS")
    alvos_esperados: list[str] = Field(default_factory=list, example=["A", "E", "I", "O", "U"])
