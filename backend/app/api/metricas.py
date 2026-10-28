from fastapi import APIRouter, Depends
from ..core.security import get_current_professor_id
from ..schemas.metricas_schema import MetricasAlunoResponse, MetricasTurmaResponse
from ..services import metricas_service

router = APIRouter(prefix="/api/metricas", tags=["Métricas, Relatórios e Alertas DTAE"])


@router.get("/alunos/{aluno_id}", response_model=MetricasAlunoResponse)
def obter_metricas_aluno(
    aluno_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Obter o Status Colorido (🟢 🟡 🔴 ⚪) e Alertas Pedagógicos do Aluno (RF-031, RF-032)."""
    return metricas_service.calcular_metricas_aluno(professor_id=prof_id, aluno_id=aluno_id)


@router.get("/turmas/{turma_id}", response_model=MetricasTurmaResponse)
def obter_metricas_turma(
    turma_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Obter relatório coletivo da turma e distribuição por status colorido (RF-033)."""
    return metricas_service.calcular_metricas_turma(professor_id=prof_id, turma_id=turma_id)
