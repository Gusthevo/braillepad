"""Validação e normalização de fotos de perfil.

Toda foto é decodificada e regravada pelo Pillow: isso garante que o arquivo
é mesmo uma imagem (não basta a extensão), remove metadados EXIF (inclusive a
localização GPS que fotos de celular carregam) e padroniza o tamanho.
"""
from io import BytesIO

from fastapi import HTTPException, status
from PIL import Image, ImageOps, UnidentifiedImageError

TAMANHO_MAXIMO_BYTES = 8 * 1024 * 1024  # 8 MB de entrada (o app já envia bem menos)
LADO_FINAL = 512
QUALIDADE_JPEG = 85
# Protege contra "bombas de descompressão" (arquivo pequeno com resolução gigante).
Image.MAX_IMAGE_PIXELS = 40_000_000

_FORMATOS_ACEITOS = {"JPEG", "PNG", "WEBP", "MPO"}  # MPO: JPEG de algumas câmeras


def _erro(msg: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=msg)


def normalizar_foto_perfil(conteudo: bytes) -> bytes:
    """Devolve um JPEG quadrado de 512×512, sem metadados."""
    if not conteudo:
        raise _erro("Arquivo vazio.")
    if len(conteudo) > TAMANHO_MAXIMO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="A foto deve ter no máximo 8 MB.",
        )
    try:
        with Image.open(BytesIO(conteudo)) as img:
            if img.format not in _FORMATOS_ACEITOS:
                raise _erro("Formato não suportado. Envie uma foto JPG, PNG ou WEBP.")
            img.load()
            img = ImageOps.exif_transpose(img)  # respeita a rotação do celular
            if img.mode in ("RGBA", "LA", "P"):
                fundo = Image.new("RGB", img.size, (255, 255, 255))
                fundo.paste(img.convert("RGBA"), mask=img.convert("RGBA").split()[-1])
                img = fundo
            else:
                img = img.convert("RGB")
            # Recorte central quadrado (o app já recorta; isto garante o formato).
            img = ImageOps.fit(img, (LADO_FINAL, LADO_FINAL), Image.Resampling.LANCZOS)
            saida = BytesIO()
            img.save(saida, "JPEG", quality=QUALIDADE_JPEG, optimize=True, progressive=True)
            return saida.getvalue()
    except HTTPException:
        raise
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError, ValueError):
        raise _erro("O arquivo enviado não é uma imagem válida.")
