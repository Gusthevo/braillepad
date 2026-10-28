"""Motor de nota DTAE: cálculo de pontuação baseado nas regras pedagógicas.
"""
from decimal import Decimal, ROUND_HALF_UP

DEFAULT_PARAMETROS: dict[tuple[str, str], Decimal] = {
    ("TENTATIVAS", "1"): Decimal("60"),
    ("TENTATIVAS", "2"): Decimal("40"),
    ("TENTATIVAS", "3"): Decimal("20"),
    ("TENTATIVAS", "4_PLUS"): Decimal("0"),
    ("AJUDA", "NENHUMA"): Decimal("40"),
    ("AJUDA", "VERBAL"): Decimal("20"),
    ("AJUDA", "FISICA"): Decimal("0"),
    ("COMPREENSAO", "TOTAL"): Decimal("0"),
    ("COMPREENSAO", "PARCIAL"): Decimal("-10"),
    ("COMPREENSAO", "NENHUMA"): Decimal("-20"),
}


def calcular_nota(
    tentativas_por_alvo: list[int],
    nivel_ajuda: str,
    compreensao: str | None,
    parametros: dict[tuple[str, str], Decimal] = DEFAULT_PARAMETROS,
) -> Decimal:
    if not tentativas_por_alvo or min(tentativas_por_alvo) < 1:
        raise ValueError("Informe as tentativas de todos os alvos pontuáveis")

    pontos = []
    for n in tentativas_por_alvo:
        chave = str(n) if n <= 3 else "4_PLUS"
        pontos.append(parametros[("TENTATIVAS", chave)])

    media_tentativas = sum(pontos) / Decimal(len(pontos))
    nota = media_tentativas + parametros[("AJUDA", nivel_ajuda)]

    if compreensao is not None:
        nota += parametros[("COMPREENSAO", compreensao)]

    return min(Decimal("100"), max(Decimal("0"), nota)).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )


def avaliar_sessao_dtae(
    tentativas_por_alvo: list[int],
    nivel_ajuda: str = "NENHUMA",
    compreensao: str | None = "TOTAL",
) -> float:
    """Calcula a nota DTAE final do aluno e retorna como float."""
    nota_decimal = calcular_nota(
        tentativas_por_alvo=tentativas_por_alvo,
        nivel_ajuda=nivel_ajuda,
        compreensao=compreensao,
        parametros=DEFAULT_PARAMETROS,
    )
    return float(nota_decimal)
