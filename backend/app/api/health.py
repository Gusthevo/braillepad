from fastapi import APIRouter
from ..core.database import get_db_connection

router = APIRouter(prefix="/api", tags=["Saúde e Conectividade"])


@router.get("/health")
def health():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return {"api": "ok", "database": "ok"}
    except Exception as e:
        return {"api": "ok", "database": "dev_mode", "detalhes": str(e)}


@router.get("/pad/health")
def pad_health():
    return {
        "integrado": False,
        "teste_disponivel": False,
        "estado": "NAO_IMPLEMENTADO",
    }
