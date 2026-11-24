from typing import Literal, Optional
from pydantic import BaseModel, Field

Tema = Literal["CLARO", "ESCURO", "SISTEMA"]
# MANUAL: botões de toque na tela (o PAD também é aceito). PAD: somente fichas lidas pelo PAD.
ModoExecucao = Literal["MANUAL", "PAD"]


class PreferenciaResponse(BaseModel):
    professor_id: str
    tema: Tema = "SISTEMA"
    escala_fonte: float = Field(default=1.00, ge=0.80, le=2.00, example=1.00)
    alto_contraste: bool = False
    som_ativo: bool = True
    vibracao_ativa: bool = True
    volume_som: int = Field(default=80, ge=0, le=100)
    modo_execucao_padrao: ModoExecucao = "MANUAL"
    volume_voz: int = Field(default=100, ge=0, le=100)
    velocidade_fala: float = Field(default=0.50, ge=0.20, le=1.00)


class PreferenciaUpdateRequest(BaseModel):
    tema: Optional[Tema] = None
    escala_fonte: Optional[float] = Field(default=None, ge=0.80, le=2.00)
    alto_contraste: Optional[bool] = None
    som_ativo: Optional[bool] = None
    vibracao_ativa: Optional[bool] = None
    volume_som: Optional[int] = Field(default=None, ge=0, le=100)
    modo_execucao_padrao: Optional[ModoExecucao] = None
    volume_voz: Optional[int] = Field(default=None, ge=0, le=100)
    velocidade_fala: Optional[float] = Field(default=None, ge=0.20, le=1.00)
