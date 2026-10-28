import psycopg
from .config import settings

def get_db_connection():
    """Retorna conexão ativa com o banco de dados PostgreSQL."""
    return psycopg.connect(
        host=settings.PGHOST,
        port=settings.PGPORT,
        dbname=settings.PGDATABASE,
        user=settings.PGUSER,
        password=settings.PGPASSWORD,
        connect_timeout=3,
    )
