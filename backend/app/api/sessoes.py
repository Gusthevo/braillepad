from typing import Optional
from fastapi import APIRouter, Depends, status
from ..core.security import get_current_professor_id
from ..schemas.sessao_schema import (
    SessaoIniciarRequest,
    LeituraFichaRequest,
    SessaoFinalizarRequest,
    SessaoResponse,
)
from ..services import sessao_service

router = APIRouter(prefix="/api/sessoes", tags=["Gestão de Sessões Pedagógicas DTAE"])


@router.post("", response_model=SessaoResponse, status_code=status.HTTP_201_CREATED)
def iniciar_sessao(
    request: SessaoIniciarRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Abre uma nova sessão de atendimento pedagógico individual (RF-020). Regra RN-09: encerra anterior como PARCIAL se solicitado."""
    return sessao_service.iniciar_sessao(professor_id=prof_id, request=request)


@router.get("/ativa", response_model=Optional[SessaoResponse])
def obter_sessao_ativa(
    prof_id: str = Depends(get_current_professor_id),
):
    """Retorna a sessão atualmente em andamento do professor logado (se houver)."""
    return sessao_service.obter_sessao_ativa(professor_id=prof_id)


@router.post("/encerrar-ativa-parcial")
def encerrar_sessao_ativa_parcial(
    prof_id: str = Depends(get_current_professor_id),
):
    """Encerra a sessão atualmente em andamento do professor como PARCIAL (RF-024)."""
    sessao_service.encerrar_sessao_ativa_parcial(professor_id=prof_id)
    return {"status": "sucesso", "mensagem": "Sessão anterior encerrada como PARCIAL."}


@router.post("/{sessao_id}/leituras")
def registrar_leitura_ficha(
    sessao_id: str,
    request: LeituraFichaRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Registra uma leitura de ficha/toque em Braille aplicando a regra de erro RN-12."""
    return sessao_service.registrar_leitura_ficha(
        professor_id=prof_id, sessao_id=sessao_id, request=request
    )


@router.post("/{sessao_id}/finalizar", response_model=SessaoResponse)
def finalizar_sessao(
    sessao_id: str,
    request: SessaoFinalizarRequest,
    prof_id: str = Depends(get_current_professor_id),
):
    """Encerramento manual da sessão pelo professor com cálculo da nota DTAE e registro de comentários (RF-024)."""
    return sessao_service.finalizar_sessao(
        professor_id=prof_id, sessao_id=sessao_id, request=request
    )
