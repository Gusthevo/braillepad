"""Armazenamento de arquivos enviados (fotos de perfil).

O resto do backend só conhece a interface `Armazenamento` (salvar, remover,
url_publica). Hoje os arquivos ficam numa pasta do servidor montada como
volume Docker (`uploads`). Para usar um object storage (S3, MinIO, Garage...)
basta escrever outra classe com os mesmos métodos e trocá-la em
`obter_armazenamento()`; as rotas e o app não mudam.
"""
from __future__ import annotations

import logging
import os
import secrets
from pathlib import Path
from typing import Protocol

from ..core.config import settings

logger = logging.getLogger(__name__)

# Prefixo das URLs servidas pelo StaticFiles montado em main.py
PREFIXO_URL = "/static/uploads"


class Armazenamento(Protocol):
    def salvar(self, pasta: str, conteudo: bytes, extensao: str) -> str:
        """Grava o arquivo e devolve a URL pública (relativa à API)."""

    def remover(self, url: str | None) -> None:
        """Apaga um arquivo salvo por este armazenamento. Ignora URLs de fora."""


class ArmazenamentoLocal:
    def __init__(self, raiz: str):
        self.raiz = Path(raiz)

    def salvar(self, pasta: str, conteudo: bytes, extensao: str) -> str:
        destino = self.raiz / pasta
        destino.mkdir(parents=True, exist_ok=True)
        # Nome aleatório de 128 bits: a URL não pode ser adivinhada nem listada.
        nome = f"{secrets.token_urlsafe(16)}.{extensao}"
        temporario = destino / f".{nome}.tmp"
        temporario.write_bytes(conteudo)
        os.replace(temporario, destino / nome)  # gravação atômica
        return f"{PREFIXO_URL}/{pasta}/{nome}"

    def remover(self, url: str | None) -> None:
        if not url or not url.startswith(PREFIXO_URL + "/"):
            return  # foto antiga por link externo: nada a apagar aqui
        relativo = url[len(PREFIXO_URL) + 1:]
        caminho = (self.raiz / relativo).resolve()
        if self.raiz.resolve() not in caminho.parents:
            logger.warning("Remoção recusada fora da pasta de uploads: %s", url)
            return
        try:
            caminho.unlink(missing_ok=True)
        except OSError:
            logger.exception("Não foi possível apagar %s", caminho)


_armazenamento: Armazenamento | None = None


def obter_armazenamento() -> Armazenamento:
    global _armazenamento
    if _armazenamento is None:
        _armazenamento = ArmazenamentoLocal(settings.UPLOAD_DIR)
    return _armazenamento
