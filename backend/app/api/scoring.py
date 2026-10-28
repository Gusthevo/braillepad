from fastapi import APIRouter, HTTPException
from ..schemas.scoring_schema import ScoringRequest
from ..services.scoring_service import avaliar_sessao_dtae

router = APIRouter(prefix="/api/scoring", tags=["Pontuação DTAE"])


@router.post("")
def calcular_nota_endpoint(request: ScoringRequest):
    try:
        nota = avaliar_sessao_dtae(
            tentativas_por_alvo=request.tentativas_por_alvo,
            nivel_ajuda=request.nivel_ajuda,
            compreensao=request.compreensao,
        )
        return {
            "status": "sucesso",
            "nota": nota,
            "nivel_ajuda": request.nivel_ajuda,
            "compreensao": request.compreensao,
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no cálculo: {str(e)}")
