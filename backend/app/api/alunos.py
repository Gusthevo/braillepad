from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from ..core.security import get_current_professor_id
from ..schemas.aluno_schema import (
    AlunoCreateRequest,
    AlunoUpdateRequest,
    AlunoTransferirRequest,
    AlunoResponse,
    AlunoDetailResponse,
)
from ..services import aluno_service

router = APIRouter(prefix="/api/alunos", tags=["Gestão de Alunos"])


@router.get("", response_model=list[AlunoResponse])
def listar_alunos(
    turma_id: Optional[str] = Query(default=None, description="Filtrar alunos por ID da turma"),
    incluir_arquivados: bool = Query(default=False, description="Incluir alunos arquivados"),
    prof_id: str = Depends(get_current_professor_id),
):
    """Listar alunos vinculados às turmas do professor autenticado (RF-009)."""
    return aluno_service.listar_alunos(
        professor_id=prof_id, turma_id=turma_id, incluir_arquivados=incluir_arquivados
    )


@router.post("", response_model=AlunoResponse, status_code=status.HTTP_201_CREATED)
def criar_aluno(
    request: AlunoCreateRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Cadastrar novo aluno vinculado obrigatoriamente a uma turma (RF-009)."""
    return aluno_service.criar_aluno(professor_id=prof_id, request=request)


@router.get("/{aluno_id}", response_model=AlunoDetailResponse)
def obter_detalhes_aluno(
    aluno_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Obter modal/detalhes e histórico do aluno (RF-010)."""
    return aluno_service.obter_aluno_detalhado(professor_id=prof_id, aluno_id=aluno_id)


@router.post("/{aluno_id}/transferir", response_model=AlunoDetailResponse)
def transferir_aluno(
    aluno_id: str,
    request: AlunoTransferirRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Transferir aluno para outra turma gravando histórico de transação (RF-011)."""
    return aluno_service.transferir_aluno(professor_id=prof_id, aluno_id=aluno_id, request=request)


@router.post("/{aluno_id}/arquivar")
def arquivar_aluno(
    aluno_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Arquivar aluno preservando histórico de sessões (RF-011)."""
    aluno_service.arquivar_aluno(professor_id=prof_id, aluno_id=aluno_id)
    return {"status": "sucesso", "mensagem": "Aluno arquivado com sucesso."}
