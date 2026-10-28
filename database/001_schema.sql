-- DTAE MVP | PostgreSQL 16+ | versao inicial de modelo relacional
-- IMPORTANT: executado no primeiro boot de um volume PostgreSQL vazio.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 01. IDENTIDADE E GESTAO ESCOLAR
CREATE TABLE professor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL CHECK (btrim(nome) <> ''),
    sobrenome VARCHAR(100) NOT NULL CHECK (btrim(sobrenome) <> ''),
    email VARCHAR(255) NOT NULL CHECK (position('@' in email) > 1),
    senha_hash TEXT NOT NULL CHECK (length(senha_hash) > 20),
    foto_url TEXT,
    instituicao VARCHAR(180),
    especialidade VARCHAR(180),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_professor_email_lower ON professor (lower(email));

CREATE TABLE sessao_autenticacao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professor_id UUID NOT NULL REFERENCES professor(id) ON DELETE RESTRICT,
    refresh_token_hash TEXT NOT NULL UNIQUE,
    dispositivo VARCHAR(150),
    criada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultima_renovacao_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_em TIMESTAMPTZ NOT NULL,
    revogada_em TIMESTAMPTZ,
    CHECK (expira_em > criada_em)
);
CREATE INDEX ix_sessao_autenticacao_ativa ON sessao_autenticacao(professor_id)
    WHERE revogada_em IS NULL;

CREATE TABLE preferencia_professor (
    professor_id UUID PRIMARY KEY REFERENCES professor(id) ON DELETE RESTRICT,
    tema VARCHAR(10) NOT NULL DEFAULT 'SISTEMA' CHECK (tema IN ('CLARO','ESCURO','SISTEMA')),
    escala_fonte NUMERIC(3,2) NOT NULL DEFAULT 1.00 CHECK (escala_fonte BETWEEN 0.80 AND 2.00),
    alto_contraste BOOLEAN NOT NULL DEFAULT FALSE,
    som_ativo BOOLEAN NOT NULL DEFAULT TRUE,
    vibracao_ativa BOOLEAN NOT NULL DEFAULT TRUE,
    volume_som INTEGER NOT NULL DEFAULT 80 CHECK (volume_som BETWEEN 0 AND 100),
    modo_execucao_padrao VARCHAR(12) NOT NULL DEFAULT 'MANUAL'
        CHECK (modo_execucao_padrao IN ('MANUAL','SIMULACAO'))
);

CREATE TABLE turma (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professor_id UUID NOT NULL REFERENCES professor(id) ON DELETE RESTRICT,
    nome VARCHAR(120) NOT NULL CHECK (btrim(nome) <> ''),
    descricao TEXT NOT NULL DEFAULT '',
    ano_letivo SMALLINT CHECK (ano_letivo BETWEEN 2020 AND 2200),
    ano_escolar VARCHAR(80),
    turno VARCHAR(20) CHECK (turno IS NULL OR turno IN ('MANHA','TARDE','NOITE','INTEGRAL')),
    criada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    arquivada_em TIMESTAMPTZ
);
CREATE INDEX ix_turma_professor ON turma(professor_id) WHERE arquivada_em IS NULL;

CREATE TABLE aluno (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turma_atual_id UUID NOT NULL REFERENCES turma(id) ON DELETE RESTRICT,
    nome VARCHAR(100) NOT NULL CHECK (btrim(nome) <> ''),
    sobrenome VARCHAR(100) NOT NULL CHECK (btrim(sobrenome) <> ''),
    matricula VARCHAR(60),
    data_nascimento DATE,
    nivel_braille VARCHAR(30) CHECK (nivel_braille IS NULL OR nivel_braille IN ('INICIANTE','EM_APRENDIZAGEM','FAMILIARIZADO')),
    preferencias_acessibilidade TEXT,
    observacoes_pedagogicas TEXT,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    arquivado_em TIMESTAMPTZ
);
CREATE INDEX ix_aluno_turma ON aluno(turma_atual_id) WHERE arquivado_em IS NULL;

CREATE TABLE transferencia_aluno (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aluno_id UUID NOT NULL REFERENCES aluno(id) ON DELETE RESTRICT,
    turma_origem_id UUID NOT NULL REFERENCES turma(id) ON DELETE RESTRICT,
    turma_destino_id UUID NOT NULL REFERENCES turma(id) ON DELETE RESTRICT,
    registrada_por UUID NOT NULL REFERENCES professor(id) ON DELETE RESTRICT,
    transferido_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    motivo TEXT,
    CHECK (turma_origem_id <> turma_destino_id)
);
CREATE INDEX ix_transferencia_aluno_em ON transferencia_aluno(aluno_id, transferido_em DESC);

-- 02. CONTEUDO PEDAGOGICO
CREATE TABLE modulo (
    id SMALLINT PRIMARY KEY CHECK (id IN (1,2,3)),
    numero SMALLINT NOT NULL UNIQUE CHECK (numero IN (1,2,3)),
    categoria VARCHAR(12) NOT NULL UNIQUE CHECK (categoria IN ('VOGAIS','SILABAS','PALAVRAS')),
    nome VARCHAR(120) NOT NULL,
    descricao TEXT NOT NULL DEFAULT '',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (id = numero)
);

CREATE TABLE atividade (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    modulo_id SMALLINT NOT NULL REFERENCES modulo(id) ON DELETE RESTRICT,
    numero SMALLINT NOT NULL CHECK (numero BETWEEN 1 AND 10),
    titulo VARCHAR(180) NOT NULL,
    descricao TEXT NOT NULL DEFAULT '',
    objetivo TEXT,
    instrucao_audio_url TEXT,
    obrigatoria BOOLEAN NOT NULL DEFAULT TRUE,
    publicada BOOLEAN NOT NULL DEFAULT FALSE,
    ativa BOOLEAN NOT NULL DEFAULT TRUE,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(modulo_id, numero)
);

CREATE TABLE fase_atividade (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    atividade_id UUID NOT NULL REFERENCES atividade(id) ON DELETE RESTRICT,
    ordem INTEGER NOT NULL CHECK (ordem >= 1),
    titulo VARCHAR(160) NOT NULL,
    tipo_fase VARCHAR(16) NOT NULL CHECK (tipo_fase IN ('EXPLORAR','ORDEM','EMBARALHADA','COMPARACAO','FORMACAO')),
    pontuavel BOOLEAN NOT NULL DEFAULT TRUE,
    sequenciamento VARCHAR(12) NOT NULL DEFAULT 'FIXO' CHECK (sequenciamento IN ('FIXO','ALEATORIO')),
    UNIQUE(atividade_id, ordem),
    CHECK (tipo_fase <> 'EXPLORAR' OR pontuavel = FALSE)
);

CREATE TABLE ficha (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    simbolo VARCHAR(30) NOT NULL UNIQUE,
    tipo VARCHAR(12) NOT NULL CHECK (tipo IN ('VOGAL','CONSOANTE','OUTRA')),
    codigo_rfid VARCHAR(120) UNIQUE,
    ativa BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE alvo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo VARCHAR(14) NOT NULL CHECK (tipo IN ('VOGAL','SILABA','PALAVRA','COMPARACAO')),
    rotulo VARCHAR(120) NOT NULL,
    descricao TEXT,
    UNIQUE(tipo,rotulo)
);

CREATE TABLE alvo_ficha (
    alvo_id UUID NOT NULL REFERENCES alvo(id) ON DELETE RESTRICT,
    posicao SMALLINT NOT NULL CHECK (posicao >= 1),
    ficha_id UUID NOT NULL REFERENCES ficha(id) ON DELETE RESTRICT,
    PRIMARY KEY (alvo_id,posicao)
);

-- Tabela associativa: um mesmo alvo pode estar em varias fases/atividades.
CREATE TABLE fase_alvo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fase_id UUID NOT NULL REFERENCES fase_atividade(id) ON DELETE RESTRICT,
    alvo_id UUID NOT NULL REFERENCES alvo(id) ON DELETE RESTRICT,
    ordem_padrao INTEGER NOT NULL CHECK (ordem_padrao >= 1),
    obrigatorio BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(fase_id, alvo_id),
    UNIQUE(fase_id, ordem_padrao)
);

-- 03. SESSOES, RESPOSTAS E FEEDBACK
CREATE TABLE sessao_atividade (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professor_id UUID NOT NULL REFERENCES professor(id) ON DELETE RESTRICT,
    turma_id UUID NOT NULL REFERENCES turma(id) ON DELETE RESTRICT,
    aluno_id UUID NOT NULL REFERENCES aluno(id) ON DELETE RESTRICT,
    atividade_id UUID NOT NULL REFERENCES atividade(id) ON DELETE RESTRICT,
    modo_registro VARCHAR(12) NOT NULL CHECK (modo_registro IN ('MANUAL','SIMULACAO','PAD')),
    status VARCHAR(13) NOT NULL DEFAULT 'EM_ANDAMENTO'
        CHECK (status IN ('EM_ANDAMENTO','PARCIAL','CONCLUIDA')),
    iniciada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    encerrada_em TIMESTAMPTZ,
    duracao_segundos INTEGER CHECK (duracao_segundos IS NULL OR duracao_segundos >= 0),
    CHECK ((status = 'EM_ANDAMENTO' AND encerrada_em IS NULL) OR
           (status IN ('PARCIAL','CONCLUIDA') AND encerrada_em IS NOT NULL))
);
CREATE UNIQUE INDEX uq_uma_sessao_ativa_por_professor
    ON sessao_atividade(professor_id) WHERE status = 'EM_ANDAMENTO';
CREATE INDEX ix_sessao_aluno_data ON sessao_atividade(aluno_id,iniciada_em DESC);
CREATE INDEX ix_sessao_turma_data ON sessao_atividade(turma_id,iniciada_em DESC);
CREATE INDEX ix_sessao_atividade_aluno ON sessao_atividade(atividade_id,aluno_id);

CREATE TABLE execucao_alvo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sessao_id UUID NOT NULL REFERENCES sessao_atividade(id) ON DELETE RESTRICT,
    fase_alvo_id UUID NOT NULL REFERENCES fase_alvo(id) ON DELETE RESTRICT,
    ordem_real INTEGER NOT NULL CHECK (ordem_real >= 1),
    status VARCHAR(14) NOT NULL DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','EM_ANDAMENTO','CONCLUIDO')),
    iniciada_em TIMESTAMPTZ,
    concluida_em TIMESTAMPTZ,
    UNIQUE(sessao_id,fase_alvo_id),
    UNIQUE(sessao_id,ordem_real),
    CHECK ((status = 'CONCLUIDO' AND concluida_em IS NOT NULL) OR
           (status <> 'CONCLUIDO' AND concluida_em IS NULL))
);

-- Uma tentativa pode conter varias leituras. Um erro interrompe a tentativa
-- e a proxima tentativa recomeça a sequencia desde a primeira ficha.
CREATE TABLE tentativa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    execucao_alvo_id UUID NOT NULL REFERENCES execucao_alvo(id) ON DELETE RESTRICT,
    numero INTEGER NOT NULL CHECK (numero >= 1),
    resultado VARCHAR(13) NOT NULL DEFAULT 'EM_ANDAMENTO'
        CHECK (resultado IN ('EM_ANDAMENTO','ACERTO','ERRO')),
    iniciada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    encerrada_em TIMESTAMPTZ,
    UNIQUE(execucao_alvo_id,numero),
    CHECK ((resultado = 'EM_ANDAMENTO' AND encerrada_em IS NULL) OR
           (resultado IN ('ACERTO','ERRO') AND encerrada_em IS NOT NULL))
);

CREATE TABLE leitura_ficha (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tentativa_id UUID NOT NULL REFERENCES tentativa(id) ON DELETE RESTRICT,
    posicao SMALLINT NOT NULL CHECK (posicao >= 1),
    ficha_esperada_id UUID NOT NULL REFERENCES ficha(id) ON DELETE RESTRICT,
    ficha_apresentada_id UUID NOT NULL REFERENCES ficha(id) ON DELETE RESTRICT,
    correta BOOLEAN NOT NULL,
    origem_registro VARCHAR(12) NOT NULL CHECK (origem_registro IN ('MANUAL','SIMULACAO','PAD')),
    registrada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tentativa_id,posicao),
    CHECK (correta = (ficha_esperada_id = ficha_apresentada_id))
);
CREATE INDEX ix_leitura_tentativa ON leitura_ficha(tentativa_id);
CREATE INDEX ix_leitura_erros ON leitura_ficha(registrada_em DESC) WHERE correta = FALSE;

CREATE TABLE comentario_professor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sessao_id UUID NOT NULL REFERENCES sessao_atividade(id) ON DELETE RESTRICT,
    professor_id UUID NOT NULL REFERENCES professor(id) ON DELETE RESTRICT,
    texto TEXT NOT NULL CHECK (btrim(texto) <> ''),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_comentario_sessao ON comentario_professor(sessao_id,criado_em);

-- 04. PONTUACAO VERSIONADA E STATUS
CREATE TABLE regra_pontuacao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria VARCHAR(12) NOT NULL CHECK (categoria IN ('VOGAIS','SILABAS','PALAVRAS')),
    versao INTEGER NOT NULL CHECK (versao >= 1),
    ativa BOOLEAN NOT NULL DEFAULT FALSE,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    observacoes TEXT,
    UNIQUE(categoria,versao)
);
CREATE UNIQUE INDEX uq_regra_ativa_categoria
    ON regra_pontuacao(categoria) WHERE ativa = TRUE;

CREATE TABLE parametro_pontuacao (
    regra_id UUID NOT NULL REFERENCES regra_pontuacao(id) ON DELETE RESTRICT,
    criterio VARCHAR(15) NOT NULL CHECK (criterio IN ('TENTATIVAS','AJUDA','COMPREENSAO')),
    chave VARCHAR(25) NOT NULL,
    pontos NUMERIC(5,2) NOT NULL CHECK (pontos BETWEEN 0 AND 100),
    PRIMARY KEY(regra_id,criterio,chave)
);

CREATE TABLE config_metricas (
    id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    notas_janela SMALLINT NOT NULL DEFAULT 3 CHECK (notas_janela >= 1),
    minimo_notas SMALLINT NOT NULL DEFAULT 2 CHECK (minimo_notas >= 1),
    limiar_amarelo NUMERIC(5,2) NOT NULL DEFAULT 50 CHECK (limiar_amarelo BETWEEN 0 AND 100),
    limiar_verde NUMERIC(5,2) NOT NULL DEFAULT 75 CHECK (limiar_verde BETWEEN 0 AND 100),
    alerta_queda NUMERIC(5,2) NOT NULL DEFAULT 20 CHECK (alerta_queda BETWEEN 0 AND 100),
    alerta_mesma_posicao SMALLINT NOT NULL DEFAULT 3 CHECK (alerta_mesma_posicao >= 2),
    CHECK (limiar_verde > limiar_amarelo),
    CHECK (minimo_notas <= notas_janela)
);

CREATE TABLE avaliacao_sessao (
    sessao_id UUID PRIMARY KEY REFERENCES sessao_atividade(id) ON DELETE RESTRICT,
    regra_id UUID NOT NULL REFERENCES regra_pontuacao(id) ON DELETE RESTRICT,
    nivel_ajuda VARCHAR(20) NOT NULL CHECK (nivel_ajuda IN ('SEM_AJUDA','DICA_VERBAL','MEDIACAO_INTENSA')),
    compreensao VARCHAR(12) CHECK (compreensao IS NULL OR compreensao IN ('SIM','EM_PARTE','AINDA_NAO')),
    nota NUMERIC(5,2) NOT NULL CHECK (nota BETWEEN 0 AND 100),
    alvos_pontuados INTEGER NOT NULL CHECK (alvos_pontuados >= 1),
    avaliada_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 05. REGRAS CRITICAS NO BANCO: TURMA HISTORICA E STATUS DE SESSAO
-- Valida o contexto na abertura da sessao: um professor responsavel,
-- aluno da turma atual e atividade publicada.
CREATE OR REPLACE FUNCTION dtae_validar_abertura_sessao() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_professor UUID; v_turma UUID; v_aluno_arquivado TIMESTAMPTZ;
        v_turma_arquivada TIMESTAMPTZ; v_publicada BOOLEAN; v_ativa BOOLEAN;
BEGIN
    IF NEW.status <> 'EM_ANDAMENTO' THEN
        RAISE EXCEPTION 'Nova sessao deve iniciar EM_ANDAMENTO';
    END IF;
    SELECT t.professor_id,t.arquivada_em INTO v_professor,v_turma_arquivada
      FROM turma t WHERE t.id = NEW.turma_id;
    SELECT a.turma_atual_id,a.arquivado_em INTO v_turma,v_aluno_arquivado
      FROM aluno a WHERE a.id = NEW.aluno_id;
    SELECT at.publicada,at.ativa INTO v_publicada,v_ativa
      FROM atividade at WHERE at.id = NEW.atividade_id;
    IF v_professor IS DISTINCT FROM NEW.professor_id OR
       v_turma IS DISTINCT FROM NEW.turma_id OR
       v_turma_arquivada IS NOT NULL OR v_aluno_arquivado IS NOT NULL OR
       v_publicada IS DISTINCT FROM TRUE OR v_ativa IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'Contexto invalido: professor/turma/aluno/atividade';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM fase_atividade f JOIN fase_alvo fa ON fa.fase_id = f.id
        WHERE f.atividade_id = NEW.atividade_id AND fa.obrigatorio
    ) THEN
        RAISE EXCEPTION 'Atividade sem alvos obrigatorios';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_validar_abertura_sessao BEFORE INSERT ON sessao_atividade
FOR EACH ROW EXECUTE FUNCTION dtae_validar_abertura_sessao();

-- Impede associar alvo de outra atividade a uma sessao.
CREATE OR REPLACE FUNCTION dtae_validar_execucao_alvo() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sessao_atividade s
        JOIN fase_alvo fa ON fa.id = NEW.fase_alvo_id
        JOIN fase_atividade f ON f.id = fa.fase_id
        WHERE s.id = NEW.sessao_id AND f.atividade_id = s.atividade_id
              AND s.status = 'EM_ANDAMENTO'
    ) THEN
        RAISE EXCEPTION 'Alvo nao pertence a atividade ou sessao encerrada';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_validar_execucao_alvo BEFORE INSERT ON execucao_alvo
FOR EACH ROW EXECUTE FUNCTION dtae_validar_execucao_alvo();

-- Ao finalizar, a sessao sera CONCLUIDA somente se TODOS os alvos
-- obrigatorios foram concluidos; em qualquer outro caso, PARCIAL.
CREATE OR REPLACE FUNCTION dtae_validar_fechamento_sessao() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_total INTEGER; v_concluidos INTEGER; v_esperado VARCHAR(13);
BEGIN
    IF OLD.status <> 'EM_ANDAMENTO' AND NEW.status <> OLD.status THEN
        RAISE EXCEPTION 'Sessao encerrada nao pode mudar de estado';
    END IF;
    IF OLD.status = 'EM_ANDAMENTO' AND NEW.status IN ('PARCIAL','CONCLUIDA') THEN
        SELECT count(*) INTO v_total
          FROM fase_atividade f JOIN fase_alvo fa ON fa.fase_id = f.id
         WHERE f.atividade_id = NEW.atividade_id AND fa.obrigatorio;
        SELECT count(*) INTO v_concluidos
          FROM execucao_alvo ea JOIN fase_alvo fa ON fa.id = ea.fase_alvo_id
         WHERE ea.sessao_id = NEW.id AND fa.obrigatorio AND ea.status = 'CONCLUIDO';
        v_esperado := CASE WHEN v_total > 0 AND v_concluidos = v_total
                          THEN 'CONCLUIDA' ELSE 'PARCIAL' END;
        IF NEW.status <> v_esperado THEN
            RAISE EXCEPTION 'Estado correto para esta sessao: %', v_esperado;
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_validar_fechamento_sessao BEFORE UPDATE OF status ON sessao_atividade
FOR EACH ROW EXECUTE FUNCTION dtae_validar_fechamento_sessao();

-- Apenas sessoes concluidas, com fases pontuaveis, podem ter nota.
CREATE OR REPLACE FUNCTION dtae_validar_avaliacao() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_categoria VARCHAR(12); v_status VARCHAR(13);
BEGIN
    SELECT m.categoria,s.status INTO v_categoria,v_status
      FROM sessao_atividade s JOIN atividade a ON a.id = s.atividade_id
      JOIN modulo m ON m.id = a.modulo_id WHERE s.id = NEW.sessao_id;
    IF v_status <> 'CONCLUIDA' OR NOT EXISTS (
       SELECT 1 FROM sessao_atividade s
       JOIN fase_atividade f ON f.atividade_id = s.atividade_id
       WHERE s.id = NEW.sessao_id AND f.pontuavel
    ) THEN RAISE EXCEPTION 'Avaliacao exige sessao concluida e fase pontuavel'; END IF;
    IF NOT EXISTS (SELECT 1 FROM regra_pontuacao r
       WHERE r.id = NEW.regra_id AND r.categoria = v_categoria) THEN
       RAISE EXCEPTION 'Regra de pontuacao de categoria incorreta'; END IF;
    IF (v_categoria = 'PALAVRAS' AND NEW.compreensao IS NULL) OR
       (v_categoria <> 'PALAVRAS' AND NEW.compreensao IS NOT NULL) THEN
       RAISE EXCEPTION 'Compreensao so se aplica a palavras'; END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_validar_avaliacao BEFORE INSERT OR UPDATE ON avaliacao_sessao
FOR EACH ROW EXECUTE FUNCTION dtae_validar_avaliacao();

-- 06. CONSULTAS DE APOIO (dados derivados, sem duplicar historico)
CREATE VIEW vw_progresso_modulo AS
SELECT a.id AS aluno_id, m.id AS modulo_id,
       count(at.id) FILTER (WHERE at.obrigatoria) AS atividades_obrigatorias,
       count(at.id) FILTER (WHERE at.obrigatoria AND EXISTS (
           SELECT 1 FROM sessao_atividade s
           WHERE s.aluno_id = a.id AND s.atividade_id = at.id AND s.status = 'CONCLUIDA'
       )) AS atividades_concluidas,
       CASE WHEN count(at.id) FILTER (WHERE at.obrigatoria) = 0 THEN 0::numeric
            ELSE round(100.0 * count(at.id) FILTER (WHERE at.obrigatoria AND EXISTS (
                  SELECT 1 FROM sessao_atividade s
                  WHERE s.aluno_id = a.id AND s.atividade_id = at.id AND s.status = 'CONCLUIDA'
            )) / count(at.id) FILTER (WHERE at.obrigatoria), 2) END AS percentual
FROM aluno a CROSS JOIN modulo m
LEFT JOIN atividade at ON at.modulo_id = m.id
GROUP BY a.id,m.id;

CREATE VIEW vw_status_aprendizagem AS
WITH ranqueadas AS (
    SELECT s.aluno_id, av.nota, av.avaliada_em,
           row_number() OVER (PARTITION BY s.aluno_id ORDER BY av.avaliada_em DESC,s.id DESC) AS ordem
    FROM avaliacao_sessao av JOIN sessao_atividade s ON s.id = av.sessao_id
), agregado AS (
    SELECT r.aluno_id, count(*) AS quantidade, round(avg(r.nota),2) AS media_recente
    FROM ranqueadas r CROSS JOIN config_metricas c WHERE r.ordem <= c.notas_janela
    GROUP BY r.aluno_id
)
SELECT a.id AS aluno_id, coalesce(g.quantidade,0) AS notas_consideradas,
       g.media_recente,
       CASE WHEN coalesce(g.quantidade,0) < c.minimo_notas THEN 'CINZA'
            WHEN g.media_recente >= c.limiar_verde THEN 'VERDE'
            WHEN g.media_recente >= c.limiar_amarelo THEN 'AMARELO'
            ELSE 'VERMELHO' END AS status
FROM aluno a CROSS JOIN config_metricas c
LEFT JOIN agregado g ON g.aluno_id = a.id;

CREATE VIEW vw_comentarios_por_atividade AS
SELECT s.aluno_id,s.atividade_id,s.id AS sessao_id,
       c.professor_id,c.texto,c.criado_em
FROM comentario_professor c JOIN sessao_atividade s ON s.id = c.sessao_id;
