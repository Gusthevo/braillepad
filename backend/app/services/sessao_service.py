import uuid
import re
import logging
import datetime
from typing import Optional
from fastapi import HTTPException, status
from ..core.database import get_db_connection
from ..schemas.sessao_schema import (
    SessaoIniciarRequest,
    LeituraFichaRequest,
    SessaoFinalizarRequest,
    SessaoResponse,
    AlertaAtividadeResponse,
)

logger = logging.getLogger(__name__)

# In-memory storage for dev mode fallback
_IN_MEMORY_SESSOES = {}

# Separadores que aparecem em rótulos de alvo (ex: "MA-LA") mas não existem
# como ficha física no PAD. Mesma regra é aplicada no app.
_SEPARADORES_ROTULO = re.compile(r"[\s\-–—_.]")


def _normalizar_rotulo(rotulo: str) -> str:
    """Rótulo como sequência de fichas: sem separadores e em maiúsculas."""
    return _SEPARADORES_ROTULO.sub("", rotulo or "").upper()


def obter_alvos_da_atividade(cur, atividade_id: str, categoria: str) -> list[str]:
    """Retorna os alvos da fase ordenada da atividade, na ordem pedagógica cadastrada.

    O app executa uma fase em ordem e depois a mesma lista embaralhada, então a
    lista vem da fase ORDEM (ou FORMACAO, no módulo de palavras), respeitando
    fase_alvo.ordem_padrao. Fases de outro tipo (ex: COMPARACAO) não são misturadas.
    """
    try:
        cur.execute(
            """
            SELECT a.rotulo
            FROM fase_alvo f_alvo
            JOIN alvo a ON f_alvo.alvo_id = a.id
            WHERE f_alvo.fase_id = (
                SELECT f.id
                FROM fase_atividade f
                WHERE f.atividade_id::text = %s
                  AND EXISTS (SELECT 1 FROM fase_alvo x WHERE x.fase_id = f.id)
                ORDER BY (f.tipo_fase IN ('ORDEM', 'FORMACAO')) DESC,
                         f.pontuavel DESC,
                         f.ordem ASC
                LIMIT 1
            )
            ORDER BY f_alvo.ordem_padrao ASC
            """,
            (atividade_id,),
        )
        rows = cur.fetchall()
        alvos = [_normalizar_rotulo(r[0]) for r in rows]
        alvos = [a for a in alvos if a]
        if alvos:
            return alvos
    except Exception:
        logger.exception("Falha ao buscar alvos da atividade %s", atividade_id)

    if categoria == 'SILABAS':
        return ['MA', 'ME', 'MI', 'MO', 'MU', 'LA', 'LE', 'LI', 'LO', 'LU']
    elif categoria == 'PALAVRAS':
        return ['MALA', 'LAMA', 'LIMA', 'MULA', 'MOLA', 'LIMAO', 'LEAO']
    else:
        return ['A', 'E', 'I', 'O', 'U']


def gerar_alertas_sessao(leituras: list[dict]) -> list[AlertaAtividadeResponse]:
    """Gera alertas pedagógicos automáticos baseados nas regras da Seção 1.1 do documento YouthTech."""
    alertas = []
    erros_por_vogal = {}
    fichas_apresentadas = {}

    for l in leituras:
        v_alvo = l.get("alvo_id", "desconhecido")
        is_correta = l.get("correta", True)
        f_codigo = l.get("ficha_codigo", "desconhecida")

        if not is_correta:
            erros_por_vogal[v_alvo] = erros_por_vogal.get(v_alvo, 0) + 1
            fichas_apresentadas[f_codigo] = fichas_apresentadas.get(f_codigo, 0) + 1

    for v, num_erros in erros_por_vogal.items():
        if num_erros >= 2:
            alertas.append(
                AlertaAtividadeResponse(
                    tipo="ERROS_RECORRENTES",
                    titulo="Erros Recorrentes na Identificação",
                    mensagem=f"Registradas {num_erros} identificações incorretas para o alvo {v}.",
                )
            )

    for f, count in fichas_apresentadas.items():
        if count >= 2:
            alertas.append(
                AlertaAtividadeResponse(
                    tipo="CONFUSAO_GRAFEMAS",
                    titulo="Confusão Recorrente entre Grafemas",
                    mensagem=f"A ficha {f} foi apresentada incorretamente {count} vezes.",
                )
            )

    return alertas


def encerrar_sessao_ativa_parcial(professor_id: str) -> bool:
    """Encerra garantidamente qualquer sessão ativa do professor em andamento."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE sessao_atividade
                    SET status = 'PARCIAL', encerrada_em = now()
                    WHERE professor_id::text = %s AND status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                conn.commit()
                return True
    except Exception:
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        UPDATE sessao_atividade
                        SET status = 'CONCLUIDA', encerrada_em = now()
                        WHERE professor_id::text = %s AND status = 'EM_ANDAMENTO'
                        """,
                        (professor_id,),
                    )
                    conn.commit()
                    return True
        except Exception:
            for s_id, s in _IN_MEMORY_SESSOES.items():
                if s["professor_id"] == professor_id and s["status"] == "EM_ANDAMENTO":
                    s["status"] = "PARCIAL"
                    s["finalizada_em"] = datetime.datetime.now().isoformat()
            return True


def iniciar_sessao(professor_id: str, request: SessaoIniciarRequest) -> SessaoResponse:
    """Abre uma nova sessão pedagógica individual (RF-020). Regra RN-09: encerra anterior se solicitado."""
    if request.encerrar_anterior:
        encerrar_sessao_ativa_parcial(professor_id)

    sessao_id = str(uuid.uuid4())

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id FROM sessao_atividade
                    WHERE professor_id::text = %s AND status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                if cur.fetchone():
                    encerrar_sessao_ativa_parcial(professor_id)

                cur.execute(
                    """
                    SELECT a.nome || ' ' || a.sobrenome as aluno_nome, at.titulo as atividade_titulo, m.categoria
                    FROM aluno a
                    JOIN turma t ON a.turma_atual_id = t.id
                    JOIN atividade at ON at.id::text = %s OR at.id = %s::uuid
                    JOIN modulo m ON at.modulo_id = m.id
                    WHERE a.id::text = %s AND t.professor_id::text = %s
                    """,
                    (request.atividade_id, request.atividade_id, request.aluno_id, professor_id),
                )
                info_row = cur.fetchone()
                aluno_nome = info_row[0] if info_row else "Aluno DTAE"
                atividade_titulo = info_row[1] if info_row else "Atividade DTAE"
                categoria = info_row[2] if info_row else "VOGAIS"

                alvos = obter_alvos_da_atividade(cur, request.atividade_id, categoria)
                modo_reg = request.modo_entrada if request.modo_entrada in ['MANUAL', 'SIMULACAO', 'PAD'] else 'MANUAL'

                cur.execute(
                    """
                    INSERT INTO sessao_atividade (
                        id, professor_id, turma_id, aluno_id, atividade_id, modo_registro, status
                    )
                    VALUES (%s::uuid, %s::uuid, %s::uuid, %s::uuid, %s::uuid, %s, 'EM_ANDAMENTO')
                    RETURNING iniciada_em::text
                    """,
                    (sessao_id, professor_id, request.turma_id, request.aluno_id, request.atividade_id, modo_reg),
                )
                iniciada_em = cur.fetchone()[0]
                conn.commit()

                return SessaoResponse(
                    id=sessao_id,
                    professor_id=professor_id,
                    aluno_id=request.aluno_id,
                    aluno_nome=aluno_nome,
                    atividade_id=request.atividade_id,
                    atividade_titulo=atividade_titulo,
                    turma_historica_id=request.turma_id,
                    modo_entrada=modo_reg,
                    status="EM_ANDAMENTO",
                    iniciada_em=iniciada_em,
                    modulo_categoria=categoria,
                    alvos_esperados=alvos,
                )
    except HTTPException:
        raise
    except Exception:
        iniciada_em = datetime.datetime.now().isoformat()
        sessao_dict = {
            "id": sessao_id,
            "professor_id": professor_id,
            "aluno_id": request.aluno_id,
            "aluno_nome": "Aluno DTAE",
            "atividade_id": request.atividade_id,
            "atividade_titulo": "Atividade 01 - Vogais",
            "turma_historica_id": request.turma_id,
            "modo_entrada": request.modo_entrada,
            "status": "EM_ANDAMENTO",
            "iniciada_em": iniciada_em,
            "total_tentativas": 1,
            "comentarios": [],
            "modulo_categoria": "VOGAIS",
            "alvos_esperados": ["A", "E", "I", "O", "U"],
        }
        _IN_MEMORY_SESSOES[sessao_id] = sessao_dict
        return SessaoResponse(**sessao_dict)


def obter_sessao_ativa(professor_id: str) -> Optional[SessaoResponse]:
    """Retorna a sessão atualmente EM_ANDAMENTO do professor logado (se houver)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT 
                        s.id, s.professor_id, s.aluno_id, a.nome || ' ' || a.sobrenome,
                        s.atividade_id, at.titulo, s.turma_id, s.modo_registro,
                        s.status, s.iniciada_em::text, m.categoria
                    FROM sessao_atividade s
                    JOIN aluno a ON s.aluno_id = a.id
                    JOIN atividade at ON s.atividade_id = at.id
                    JOIN modulo m ON at.modulo_id = m.id
                    WHERE s.professor_id::text = %s AND s.status = 'EM_ANDAMENTO'
                    """,
                    (professor_id,),
                )
                r = cur.fetchone()
                if r:
                    atv_id = str(r[4])
                    cat = r[10]
                    alvos = obter_alvos_da_atividade(cur, atv_id, cat)

                    return SessaoResponse(
                        id=str(r[0]),
                        professor_id=str(r[1]),
                        aluno_id=str(r[2]),
                        aluno_nome=r[3],
                        atividade_id=atv_id,
                        atividade_titulo=r[5],
                        turma_historica_id=str(r[6]),
                        modo_entrada=r[7],
                        status=r[8],
                        iniciada_em=r[9],
                        modulo_categoria=cat,
                        alvos_esperados=alvos,
                    )
                return None
    except Exception:
        for s_id, s in _IN_MEMORY_SESSOES.items():
            if s["professor_id"] == professor_id and s["status"] == "EM_ANDAMENTO":
                return SessaoResponse(**s)
        return None


def _resolver_fase_alvo(cur, sessao_id: str, alvo_ref: str, tipo_fase: Optional[str]):
    """Encontra o fase_alvo da sessão correspondente ao alvo informado pelo app.

    O app envia o alvo como UUID ou como "alvo_<rotulo>". Quando o mesmo alvo
    existe em várias fases (ex: vogais em ORDEM e EMBARALHADA), usa a fase
    informada em tipo_fase. Leituras do tutorial (EXPLORAR) só são gravadas se
    a atividade tiver fase EXPLORAR, para não contaminar fases pontuáveis.
    Retorna (fase_alvo_id, alvo_id) ou None.
    """
    ref = (alvo_ref or "").strip()
    rotulo = _normalizar_rotulo(ref[5:] if ref.lower().startswith("alvo_") else ref)
    tipo = (tipo_fase or "").strip().upper()

    cur.execute(
        """
        SELECT fa.id::text, a.id::text, f.tipo_fase
        FROM sessao_atividade s
        JOIN fase_atividade f ON f.atividade_id = s.atividade_id
        JOIN fase_alvo fa ON fa.fase_id = f.id
        JOIN alvo a ON a.id = fa.alvo_id
        WHERE s.id::text = %s
          AND (a.id::text = %s
               OR upper(regexp_replace(a.rotulo, '[[:space:]_.–—-]', '', 'g')) = %s)
        ORDER BY (f.tipo_fase = %s) DESC,
                 (f.tipo_fase IN ('ORDEM', 'FORMACAO')) DESC,
                 f.ordem ASC
        """,
        (sessao_id, ref, rotulo, tipo),
    )
    rows = cur.fetchall()
    if not rows:
        return None

    if tipo == "EXPLORAR":
        row = next((r for r in rows if r[2] == "EXPLORAR"), None)
    else:
        row = next((r for r in rows if r[2] != "EXPLORAR"), None)
    return (row[0], row[1]) if row else None


def _obter_ou_criar_ficha(cur, simbolo: str) -> Optional[str]:
    """Busca a ficha pelo símbolo. Fichas físicas ainda não catalogadas (ex: números
    enviados pelo PAD) são cadastradas como OUTRA para o erro não se perder."""
    if not simbolo:
        return None
    cur.execute("SELECT id::text FROM ficha WHERE upper(simbolo) = %s LIMIT 1", (simbolo,))
    row = cur.fetchone()
    if row:
        return row[0]
    if not re.fullmatch(r"[0-9A-Z]{1,2}", simbolo):
        return None
    cur.execute(
        """
        INSERT INTO ficha (simbolo, tipo) VALUES (%s, 'OUTRA')
        ON CONFLICT (simbolo) DO UPDATE SET simbolo = EXCLUDED.simbolo
        RETURNING id::text
        """,
        (simbolo,),
    )
    return cur.fetchone()[0]


def registrar_leitura_ficha(
    professor_id: str, sessao_id: str, request: LeituraFichaRequest
) -> dict:
    """Registra uma leitura de ficha (RF-023) preservando o histórico de tentativas.

    Modelo gravado:
      execucao_alvo (1 por alvo da fase na sessão)
        └─ tentativa (numerada; fica EM_ANDAMENTO até errar ou completar o alvo)
             └─ leitura_ficha (posição da ficha dentro do alvo, esperada x apresentada)
    Um erro encerra a tentativa como ERRO; a próxima leitura abre uma nova tentativa.
    Completar a última posição encerra a tentativa como ACERTO e conclui o alvo.
    """
    leitura_id = str(uuid.uuid4())
    simbolo = request.ficha_codigo.replace("FICHA_", "").replace("VOGAL_", "").strip().upper()
    base_resposta = {
        "leitura_id": leitura_id,
        "sessao_id": sessao_id,
        "alvo_id": request.alvo_id,
        "posicao": request.posicao,
        "ficha_codigo": request.ficha_codigo,
    }

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT modo_registro FROM sessao_atividade
                    WHERE id::text = %s AND professor_id::text = %s AND status = 'EM_ANDAMENTO'
                    """,
                    (sessao_id, professor_id),
                )
                sessao_row = cur.fetchone()
                if not sessao_row:
                    raise HTTPException(
                        status_code=404, detail="Sessão ativa em andamento não encontrada."
                    )
                origem = sessao_row[0] if sessao_row[0] in ("MANUAL", "SIMULACAO", "PAD") else "MANUAL"

                resolvido = _resolver_fase_alvo(cur, sessao_id, request.alvo_id, request.tipo_fase)
                if not resolvido:
                    logger.warning(
                        "Leitura não gravada: alvo %s (fase %s) não pertence à sessão %s",
                        request.alvo_id, request.tipo_fase, sessao_id,
                    )
                    return {**base_resposta, "correta": request.correta, "registrada": False,
                            "mensagem": "Alvo não pertence a esta atividade; leitura não gravada."}
                fase_alvo_id, alvo_id = resolvido

                cur.execute(
                    """
                    SELECT af.ficha_id::text,
                           (SELECT count(*) FROM alvo_ficha WHERE alvo_id = %s::uuid)
                    FROM alvo_ficha af
                    WHERE af.alvo_id = %s::uuid AND af.posicao = %s
                    """,
                    (alvo_id, alvo_id, request.posicao),
                )
                esperada_row = cur.fetchone()
                ficha_apresentada_id = _obter_ou_criar_ficha(cur, simbolo)
                if not esperada_row or not ficha_apresentada_id:
                    logger.warning(
                        "Leitura não gravada: posição %s / ficha %s inválidas para o alvo %s",
                        request.posicao, simbolo, request.alvo_id,
                    )
                    conn.rollback()
                    return {**base_resposta, "correta": request.correta, "registrada": False,
                            "mensagem": "Posição ou ficha inválida para o alvo; leitura não gravada."}
                ficha_esperada_id, total_posicoes = esperada_row[0], int(esperada_row[1])

                # A correção é decidida pelo gabarito do banco (exigido pelo CHECK da tabela).
                correta = ficha_esperada_id == ficha_apresentada_id
                if correta != request.correta:
                    logger.warning(
                        "Divergência app x gabarito na sessão %s: alvo %s pos %s ficha %s (app=%s, banco=%s)",
                        sessao_id, request.alvo_id, request.posicao, simbolo, request.correta, correta,
                    )

                # 1. Execução do alvo (ordem_real é sequencial dentro da sessão)
                cur.execute(
                    """
                    SELECT id::text FROM execucao_alvo
                    WHERE sessao_id::text = %s AND fase_alvo_id = %s::uuid
                    """,
                    (sessao_id, fase_alvo_id),
                )
                ea_row = cur.fetchone()
                if ea_row:
                    execucao_id = ea_row[0]
                else:
                    cur.execute(
                        """
                        INSERT INTO execucao_alvo (sessao_id, fase_alvo_id, ordem_real, status, iniciada_em)
                        SELECT %s::uuid, %s::uuid, COALESCE(MAX(ordem_real), 0) + 1, 'EM_ANDAMENTO', now()
                        FROM execucao_alvo WHERE sessao_id = %s::uuid
                        RETURNING id::text
                        """,
                        (sessao_id, fase_alvo_id, sessao_id),
                    )
                    execucao_id = cur.fetchone()[0]

                # 2. Tentativa aberta (ou uma nova, se a anterior terminou)
                cur.execute(
                    """
                    SELECT id::text FROM tentativa
                    WHERE execucao_alvo_id = %s::uuid AND resultado = 'EM_ANDAMENTO'
                    ORDER BY numero DESC LIMIT 1
                    """,
                    (execucao_id,),
                )
                tent_row = cur.fetchone()
                if tent_row:
                    tentativa_id = tent_row[0]
                else:
                    cur.execute(
                        """
                        INSERT INTO tentativa (execucao_alvo_id, numero, resultado, iniciada_em)
                        SELECT %s::uuid, COALESCE(MAX(numero), 0) + 1, 'EM_ANDAMENTO', now()
                        FROM tentativa WHERE execucao_alvo_id = %s::uuid
                        RETURNING id::text
                        """,
                        (execucao_id, execucao_id),
                    )
                    tentativa_id = cur.fetchone()[0]

                # 3. Leitura na posição da ficha dentro do alvo (reenvio duplicado é ignorado)
                cur.execute(
                    """
                    INSERT INTO leitura_ficha (id, tentativa_id, posicao, ficha_esperada_id,
                                               ficha_apresentada_id, correta, origem_registro)
                    VALUES (%s::uuid, %s::uuid, %s, %s::uuid, %s::uuid, %s, %s)
                    ON CONFLICT (tentativa_id, posicao) DO NOTHING
                    """,
                    (leitura_id, tentativa_id, request.posicao, ficha_esperada_id,
                     ficha_apresentada_id, correta, origem),
                )

                # 4. Fecha a tentativa / conclui o alvo
                if not correta:
                    cur.execute(
                        "UPDATE tentativa SET resultado = 'ERRO', encerrada_em = now() WHERE id = %s::uuid",
                        (tentativa_id,),
                    )
                elif request.posicao >= total_posicoes:
                    cur.execute(
                        "UPDATE tentativa SET resultado = 'ACERTO', encerrada_em = now() WHERE id = %s::uuid",
                        (tentativa_id,),
                    )
                    cur.execute(
                        """
                        UPDATE execucao_alvo
                        SET status = 'CONCLUIDO', concluida_em = COALESCE(concluida_em, now())
                        WHERE id = %s::uuid
                        """,
                        (execucao_id,),
                    )

                conn.commit()
                return {
                    **base_resposta,
                    "correta": correta,
                    "registrada": True,
                    "mensagem": "Leitura gravada" if correta else "Erro registrado.",
                }
    except HTTPException:
        raise
    except Exception:
        logger.exception("Falha ao gravar leitura no banco; usando armazenamento em memória")
        if sessao_id in _IN_MEMORY_SESSOES:
            s = _IN_MEMORY_SESSOES[sessao_id]
            if "leituras" not in s:
                s["leituras"] = []
            s["leituras"].append({"correta": request.correta, "ficha_codigo": request.ficha_codigo})
            s["total_tentativas"] = len(s["leituras"])
        return {
            **base_resposta,
            "correta": request.correta,
            "registrada": False,
            "mensagem": "Leitura registrada apenas em memória.",
        }


def finalizar_sessao(
    professor_id: str, sessao_id: str, request: SessaoFinalizarRequest
) -> SessaoResponse:
    """
    Finaliza a sessão (RF-024) de forma simples e direta, alterando o status para 'CONCLUIDA'
    e registrando a nota na tabela 'avaliacao_sessao' no PostgreSQL sem bloqueios.
    """
    finalizada_em = datetime.datetime.now().isoformat()
    duracao_sec = request.duracao_segundos or 0
    estrelas = request.avaliacao_estrelas or 5

    req_tentativas = request.total_tentativas or 0
    req_acertos = request.total_acertos or 0
    if req_tentativas > 0:
        percentual_acertos = round(float((req_acertos / req_tentativas) * 100.0), 1)
    else:
        percentual_acertos = float(estrelas * 20.0)

    # Nota final calculada (50% desempenho + 50% avaliação de estrelas)
    nota_calculada = round(float((estrelas * 10.0) + (percentual_acertos * 0.5)), 1)

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.id, s.aluno_id, a.nome || ' ' || a.sobrenome, s.atividade_id, at.titulo, s.turma_id, s.modo_registro, s.iniciada_em::text, s.status, m.categoria
                    FROM sessao_atividade s
                    JOIN aluno a ON s.aluno_id = a.id
                    JOIN atividade at ON s.atividade_id = at.id
                    JOIN modulo m ON at.modulo_id = m.id
                    WHERE s.id::text = %s
                    """,
                    (sessao_id,),
                )
                r = cur.fetchone()
                if not r:
                    raise HTTPException(status_code=404, detail="Sessão não encontrada.")

                aluno_id = str(r[1])
                aluno_nome = r[2]
                atividade_id = str(r[3])
                atividade_titulo = r[4]
                turma_id = str(r[5])
                modo_registro = r[6]
                iniciada_em = r[7]
                status_atual = r[8]
                categoria = r[9]
                alvos = obter_alvos_da_atividade(cur, atividade_id, categoria)

                # 1. Se a sessão ainda estiver EM_ANDAMENTO, conclui os alvos e altera o status para CONCLUIDA
                if status_atual == 'EM_ANDAMENTO':
                    cur.execute(
                        """
                        SELECT fa.id
                        FROM fase_atividade f
                        JOIN fase_alvo fa ON fa.fase_id = f.id
                        WHERE f.atividade_id::text = %s AND fa.obrigatorio
                        ORDER BY fa.ordem_padrao ASC
                        """,
                        (atividade_id,),
                    )
                    fa_rows = cur.fetchall()
                    for fa_r in fa_rows:
                        fa_id = str(fa_r[0])
                        # ordem_real é única por sessão: alvos já executados mantêm a
                        # ordem em que aconteceram e os restantes entram ao final.
                        cur.execute(
                            """
                            INSERT INTO execucao_alvo (sessao_id, fase_alvo_id, ordem_real, status, iniciada_em, concluida_em)
                            SELECT %s::uuid, %s::uuid, COALESCE(MAX(ordem_real), 0) + 1, 'CONCLUIDO', now(), now()
                            FROM execucao_alvo WHERE sessao_id = %s::uuid
                            ON CONFLICT (sessao_id, fase_alvo_id) DO UPDATE SET
                                status = 'CONCLUIDO',
                                iniciada_em = COALESCE(execucao_alvo.iniciada_em, now()),
                                concluida_em = COALESCE(execucao_alvo.concluida_em, now())
                            """,
                            (sessao_id, fa_id, sessao_id),
                        )

                    # 2. Atualizar a sessao para status 'CONCLUIDA'
                    cur.execute(
                        """
                        UPDATE sessao_atividade
                        SET status = 'CONCLUIDA', encerrada_em = now(), duracao_segundos = %s
                        WHERE id::text = %s
                        """,
                        (duracao_sec, sessao_id),
                    )
                else:
                    # Se já estava concluída, apenas busca fa_rows para contagem
                    cur.execute(
                        """
                        SELECT fa.id
                        FROM fase_atividade f
                        JOIN fase_alvo fa ON fa.fase_id = f.id
                        WHERE f.atividade_id::text = %s AND fa.obrigatorio
                        """,
                        (atividade_id,),
                    )
                    fa_rows = cur.fetchall()
                    cur.execute(
                        "UPDATE sessao_atividade SET duracao_segundos = GREATEST(duracao_segundos, %s) WHERE id::text = %s",
                        (duracao_sec, sessao_id),
                    )

                # 3. Inserir ou atualizar avaliacao_sessao com mapeamento estrito para satisfazer as triggers do banco
                cur.execute("SELECT id FROM regra_pontuacao WHERE categoria = %s AND ativa = TRUE LIMIT 1", (categoria,))
                regra_row = cur.fetchone()
                if not regra_row:
                    cur.execute("SELECT id FROM regra_pontuacao WHERE categoria = %s LIMIT 1", (categoria,))
                    regra_row = cur.fetchone()

                if regra_row:
                    regra_id = str(regra_row[0])

                    # Mapeamento do nível de ajuda (CHECK constraint: SEM_AJUDA, DICA_VERBAL, MEDIACAO_INTENSA)
                    n_aux = (request.nivel_auxilio_fase1 or 'INDEPENDENTE').upper()
                    if n_aux in ['INDEPENDENTE', 'SEM_AJUDA']:
                        nivel_ajuda_db = 'SEM_AJUDA'
                    elif n_aux in ['VERBAL', 'REPETICAO', 'DICA_VERBAL']:
                        nivel_ajuda_db = 'DICA_VERBAL'
                    else:
                        nivel_ajuda_db = 'MEDIACAO_INTENSA'

                    # Mapeamento de compreensão (Trigger constraint: APENAS PALAVRAS aceita compreensao NOT NULL)
                    if categoria == 'PALAVRAS':
                        c_inst = (request.compreensao_instrucoes or 'SIM').upper()
                        if c_inst in ['TOTAL', 'SIM']:
                            compreensao_db = 'SIM'
                        elif c_inst in ['PARCIAL', 'REPETIDAS', 'EM_PARTE']:
                            compreensao_db = 'EM_PARTE'
                        else:
                            compreensao_db = 'AINDA_NAO'
                    else:
                        compreensao_db = None

                    cur.execute(
                        """
                        INSERT INTO avaliacao_sessao (sessao_id, regra_id, nivel_ajuda, compreensao, nota, alvos_pontuados)
                        VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s)
                        ON CONFLICT (sessao_id) DO UPDATE
                        SET nivel_ajuda = EXCLUDED.nivel_ajuda,
                            compreensao = EXCLUDED.compreensao,
                            nota = EXCLUDED.nota,
                            avaliada_em = now()
                        """,
                        (sessao_id, regra_id, nivel_ajuda_db, compreensao_db, nota_calculada, max(len(fa_rows), 1)),
                    )

                # 4. Gravar comentário do professor se houver
                if request.comentario and request.comentario.strip():
                    cur.execute(
                        """
                        INSERT INTO comentario_professor (sessao_id, professor_id, texto)
                        VALUES (%s::uuid, %s::uuid, %s)
                        """,
                        (sessao_id, professor_id, request.comentario.strip()),
                    )

                conn.commit()

                cur.execute(
                    "SELECT texto FROM comentario_professor WHERE sessao_id::text = %s ORDER BY criado_em ASC",
                    (sessao_id,),
                )
                comentarios_list = [c[0] for c in cur.fetchall()]

                alertas_gerados = [
                    AlertaAtividadeResponse(
                        tipo="EVOLUCAO",
                        titulo="Atividade Concluída",
                        mensagem=f"Nota registrada: {nota_calculada:.1f} pts.",
                    )
                ]

                return SessaoResponse(
                    id=sessao_id,
                    professor_id=professor_id,
                    aluno_id=aluno_id,
                    aluno_nome=aluno_nome,
                    atividade_id=atividade_id,
                    atividade_titulo=atividade_titulo,
                    turma_historica_id=turma_id,
                    modo_entrada=modo_registro,
                    status="CONCLUIDA",
                    iniciada_em=iniciada_em,
                    finalizada_em=finalizada_em,
                    duracao_segundos=duracao_sec,
                    nota=nota_calculada,
                    percentual_acertos=percentual_acertos,
                    avaliacao_estrelas=estrelas,
                    nivel_auxilio_fase1=request.nivel_auxilio_fase1,
                    nivel_auxilio_fase2=request.nivel_auxilio_fase2,
                    compreensao_instrucoes=request.compreensao_instrucoes,
                    autonomia_exploracao=request.autonomia_exploracao,
                    comentarios=comentarios_list,
                    alertas_gerados=alertas_gerados,
                    modulo_categoria=categoria,
                    alvos_esperados=alvos,
                )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao finalizar sessão no banco: {e}")
