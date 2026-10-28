from fastapi import APIRouter, Depends, Query, status
from ..core.security import get_current_professor_id
from ..schemas.turma_schema import (
    TurmaCreateRequest,
    TurmaUpdateRequest,
    TurmaResponse,
    TurmaDetailResponse,
)
from ..services import turma_service

router = APIRouter(prefix="/api/turmas", tags=["Gestão de Turmas"])


@router.get("", response_model=list[TurmaResponse])
def listar_turmas(
    incluir_arquivadas: bool = Query(default=False, description="Incluir turmas arquivadas na listagem"),
    prof_id: str = Depends(get_current_professor_id),
):
    """Listar turmas do professor autenticado."""
    return turma_service.listar_turmas(professor_id=prof_id, incluir_arquivadas=incluir_arquivadas)


@router.post("", response_model=TurmaResponse, status_code=status.HTTP_201_CREATED)
def criar_turma(
    request: TurmaCreateRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Criar uma nova turma para o professor autenticado."""
    return turma_service.criar_turma(professor_id=prof_id, request=request)


@router.get("/{turma_id}", response_model=TurmaDetailResponse)
def obter_detalhes_turma(
    turma_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Obter detalhes de uma turma e seus alunos vinculados."""
    return turma_service.obter_turma_detalhada(professor_id=prof_id, turma_id=turma_id)


@router.patch("/{turma_id}", response_model=TurmaResponse)
def atualizar_turma(
    turma_id: str,
    request: TurmaUpdateRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Atualizar informações de uma turma."""
    return turma_service.atualizar_turma(professor_id=prof_id, turma_id=turma_id, request=request)


@router.post("/{turma_id}/arquivar")
def arquivar_turma(
    turma_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Arquivar uma turma sem remover o histórico."""
    turma_service.arquivar_turma(professor_id=prof_id, turma_id=turma_id)
    return {"status": "sucesso", "mensagem": "Turma arquivada com sucesso."}


@router.post("/{turma_id}/desarquivar")
def desarquivar_turma(
    turma_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Desarquivar uma turma."""
    turma_service.desarquivar_turma(professor_id=prof_id, turma_id=turma_id)
    return {"status": "sucesso", "mensagem": "Turma desarquivada com sucesso."}
