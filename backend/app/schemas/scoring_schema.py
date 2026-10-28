from pydantic import BaseModel, Field

class ScoringRequest(BaseModel):
    tentativas_por_alvo: list[int] = Field(
        ..., example=[1, 2, 1], description="Lista de tentativas por alvo"
    )
    nivel_ajuda: str = Field(
        default="NENHUMA", example="NENHUMA", description="NENHUMA, VERBAL, FISICA"
    )
    compreensao: str | None = Field(
        default=None, example="TOTAL", description="TOTAL, PARCIAL, NENHUMA ou None"
    )
