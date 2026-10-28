from fastapi import APIRouter, Depends
from ..core.security import get_current_professor_id
from ..schemas.atividade_schema import (
    ModuloResponse,
    AtividadeResponse,
    AtividadeDetailResponse,
)
from ..services import atividade_service

router = APIRouter(prefix="/api", tags=["Catálogo de Módulos e Atividades"])


@router.get("/modulos", response_model=list[ModuloResponse])
def listar_modulos(
    prof_id: str = Depends(get_current_professor_id),
):
    """Listar os 3 Módulos fixos do catálogo DTAE (RF-012)."""
    return atividade_service.listar_modulos()


@router.get("/modulos/{modulo_id}/atividades", response_model=list[AtividadeResponse])
def listar_atividades_por_modulo(
    modulo_id: int,
    prof_id: str = Depends(get_current_professor_id),
):
    """Listar as 10 Atividades do módulo informado (RF-013)."""
    return atividade_service.listar_atividades_por_modulo(modulo_id=modulo_id)


@router.get("/atividades/{atividade_id}", response_model=AtividadeDetailResponse)
def obter_detalhes_atividade(
    atividade_id: str,
    prof_id: str = Depends(get_current_professor_id),
):
    """Obter detalhes de uma atividade, suas fases e alvos esperados (RF-014)."""
    return atividade_service.obter_atividade_detalhada(atividade_id=atividade_id)
