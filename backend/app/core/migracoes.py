"""Migrações idempotentes aplicadas na inicialização da API.

Os scripts em `database/` só rodam quando o volume do PostgreSQL é criado pela
primeira vez. Para bancos que já existem, as alterações de esquema posteriores
são aplicadas aqui; cada comando pode rodar várias vezes sem efeito colateral.
"""
import logging

from .database import get_db_connection

logger = logging.getLogger(__name__)

_MIGRACOES = [
    # Preferências de voz (TTS) do professor
    """
    ALTER TABLE preferencia_professor
        ADD COLUMN IF NOT EXISTS volume_voz INTEGER NOT NULL DEFAULT 100
            CHECK (volume_voz BETWEEN 0 AND 100)
    """,
    """
    ALTER TABLE preferencia_professor
        ADD COLUMN IF NOT EXISTS velocidade_fala NUMERIC(3,2) NOT NULL DEFAULT 0.50
            CHECK (velocidade_fala BETWEEN 0.20 AND 1.00)
    """,
    # Modo de execução: 'SIMULACAO' virou 'PAD' (somente fichas lidas pelo PAD)
    """
    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'preferencia_professor_modo_execucao_padrao_check'
              AND pg_get_constraintdef(oid) LIKE '%PAD%'
        ) THEN
            ALTER TABLE preferencia_professor
                DROP CONSTRAINT IF EXISTS preferencia_professor_modo_execucao_padrao_check;
            UPDATE preferencia_professor SET modo_execucao_padrao = 'PAD'
                WHERE modo_execucao_padrao = 'SIMULACAO';
            ALTER TABLE preferencia_professor
                ADD CONSTRAINT preferencia_professor_modo_execucao_padrao_check
                CHECK (modo_execucao_padrao IN ('MANUAL','PAD'));
        END IF;
    END $$
    """,
]


def aplicar_migracoes() -> None:
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                for sql in _MIGRACOES:
                    cur.execute(sql)
            conn.commit()
        logger.info("Migrações de esquema aplicadas.")
    except Exception:
        # A API sobe mesmo assim; as rotas que dependem do banco responderão 503.
        logger.exception("Falha ao aplicar migrações de esquema")
