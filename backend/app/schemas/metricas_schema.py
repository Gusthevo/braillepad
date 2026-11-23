from pydantic import BaseModel, Field

class AlertaPedagógicoResponse(BaseModel):
    tipo: str = Field(..., example="QUEDA_RECENTE", description="QUEDA_RECENTE, EVOLUCAO, FICHA_DIFICIL")
    titulo: str
    mensagem: str


class SessaoHistoricoResponse(BaseModel):
    sessao_id: str
    atividade_titulo: str
    modulo_nome: str
    data: str = Field(..., description="Data de encerramento da sessão (ISO 8601)")
    nota: float
    percentual_acertos: float | None = None


class MetricasAlunoResponse(BaseModel):
    aluno_id: str
    aluno_nome: str
    turma_nome: str
    status_colorido: str = Field(..., example="VERDE", description="VERDE, AMARELO, VERMELHO, CINZA")
    descricao_status: str
    media_notas: float | None = None
    total_sessoes_concluidas: int = 0
    # Notas da janela usada no status (mais recente primeiro)
    ultimas_notas: list[float] = []
    # Histórico recente com atividade e data (mais recente primeiro)
    historico: list[SessaoHistoricoResponse] = []
    notas_janela: int = 3
    minimo_notas: int = 2
    alertas: list[AlertaPedagógicoResponse] = []


class MetricasTurmaResponse(BaseModel):
    turma_id: str
    turma_nome: str
    total_alunos: int = 0
    media_turma: float | None = None
    alunos_verde: int = 0
    alunos_amarelo: int = 0
    alunos_vermelho: int = 0
    alunos_cinza: int = 0
    alunos_metricas: list[MetricasAlunoResponse] = []
