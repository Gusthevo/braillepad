-- DTAE | Dados iniciais do MVP.
-- 30 atividades fixas (10 por modulo); somente as 3 demonstracoes sao publicadas.
-- Os demais conteudos aguardam a professora e nao devem ser iniciados ate configuracao.
INSERT INTO modulo(id,numero,categoria,nome,descricao) VALUES
(1,1,'VOGAIS','Modulo 1 — Vogais','Identificacao e exploracao tatil de vogais'),
(2,2,'SILABAS','Modulo 2 — Silabas','Combinacoes com M e L e vogais'),
(3,3,'PALAVRAS','Modulo 3 — Palavras','Formacao de palavras por fichas sequenciais');

INSERT INTO atividade(modulo_id,numero,titulo,descricao,objetivo,obrigatoria,publicada)
SELECT m.id,n.n,
       CASE WHEN n.n=1 THEN '[DEMONSTRACAO] Atividade 01'
            ELSE 'Atividade ' || lpad(n.n::text,2,'0') || ' — a definir' END,
       CASE WHEN n.n=1 THEN 'Exemplo tecnico baseado no documento pedagógico; conteudo substituivel'
            ELSE 'Conteudo ainda nao entregue pela professora responsavel' END,
       CASE WHEN n.n=1 THEN 'Validar fluxo de sessao, fases, alvos e registro de fichas' END,
       TRUE,(n.n=1)
FROM modulo m CROSS JOIN generate_series(1,10) AS n(n);

INSERT INTO ficha(simbolo,tipo) VALUES
('A','VOGAL'),('E','VOGAL'),('I','VOGAL'),('O','VOGAL'),('U','VOGAL'),
('M','CONSOANTE'),('L','CONSOANTE');

INSERT INTO alvo(tipo,rotulo,descricao)
SELECT 'VOGAL',x,'Identificar vogal' FROM unnest(ARRAY['A','E','I','O','U']) AS x
UNION ALL
SELECT 'SILABA', consonante || vogal,'Formar silaba'
FROM unnest(ARRAY['M','L']) AS consonante CROSS JOIN unnest(ARRAY['A','E','I','O','U']) AS vogal
UNION ALL
SELECT 'PALAVRA',x,'Formar palavra'
FROM unnest(ARRAY['LUA','MALA','MOLA','MULA','MEIA','MEIO','LIMA']) AS x
UNION ALL
SELECT 'COMPARACAO',x,'Comparar silabas seguidas'
FROM unnest(ARRAY['MA-LA','MA-MI']) AS x;

-- A letra de cada posicao e o gabarito tatil esperado.
INSERT INTO alvo_ficha(alvo_id,posicao,ficha_id)
SELECT a.id,l.ord::smallint,f.id
FROM alvo a
CROSS JOIN LATERAL unnest(string_to_array(replace(a.rotulo,'-',''),NULL))
     WITH ORDINALITY AS l(simbolo,ord)
JOIN ficha f ON f.simbolo = l.simbolo;

INSERT INTO fase_atividade(atividade_id,ordem,titulo,tipo_fase,pontuavel,sequenciamento)
SELECT at.id, fase.ordem,fase.titulo,fase.tipo,fase.pontuavel,fase.seq
FROM atividade at JOIN modulo m ON m.id=at.modulo_id
CROSS JOIN LATERAL (
   SELECT * FROM (VALUES
       ('VOGAIS',1,'Explorar vogais','EXPLORAR',FALSE,'FIXO'),
       ('VOGAIS',2,'Vogais em ordem','ORDEM',TRUE,'FIXO'),
       ('VOGAIS',3,'Vogais embaralhadas','EMBARALHADA',TRUE,'ALEATORIO'),
       ('SILABAS',1,'Explorar silabas','EXPLORAR',FALSE,'FIXO'),
       ('SILABAS',2,'Silabas em ordem','ORDEM',TRUE,'FIXO'),
       ('SILABAS',3,'Silabas embaralhadas','EMBARALHADA',TRUE,'ALEATORIO'),
       ('SILABAS',4,'Compare e descubra','COMPARACAO',TRUE,'FIXO'),
       ('PALAVRAS',1,'Formacao de palavras','FORMACAO',TRUE,'FIXO')
   ) AS f(categoria,ordem,titulo,tipo,pontuavel,seq)
   WHERE f.categoria=m.categoria
) fase
WHERE at.numero=1;

INSERT INTO fase_alvo(fase_id,alvo_id,ordem_padrao,obrigatorio)
SELECT f.id,a.id,
  row_number() OVER (PARTITION BY f.id ORDER BY a.rotulo)::integer,TRUE
FROM fase_atividade f JOIN atividade at ON at.id=f.atividade_id
JOIN modulo m ON m.id=at.modulo_id
JOIN alvo a ON
     (m.categoria='VOGAIS' AND a.tipo='VOGAL') OR
     (m.categoria='SILABAS' AND f.tipo_fase <> 'COMPARACAO' AND a.tipo='SILABA') OR
     (m.categoria='SILABAS' AND f.tipo_fase = 'COMPARACAO' AND a.tipo='COMPARACAO') OR
     (m.categoria='PALAVRAS' AND a.tipo='PALAVRA');

INSERT INTO regra_pontuacao(categoria,versao,ativa,observacoes) VALUES
('VOGAIS',1,TRUE,'Regra do documento: media tentativas + ajuda'),
('SILABAS',1,TRUE,'Regra do documento: media tentativas + ajuda'),
('PALAVRAS',1,TRUE,'Regra do documento: media tentativas + ajuda + compreensao');

INSERT INTO parametro_pontuacao(regra_id,criterio,chave,pontos)
SELECT r.id,p.criterio,p.chave,p.pontos
FROM regra_pontuacao r
JOIN (VALUES
    ('VOGAIS','TENTATIVAS','1',60),('VOGAIS','TENTATIVAS','2',40),('VOGAIS','TENTATIVAS','3',20),('VOGAIS','TENTATIVAS','4_PLUS',0),
    ('VOGAIS','AJUDA','SEM_AJUDA',40),('VOGAIS','AJUDA','DICA_VERBAL',20),('VOGAIS','AJUDA','MEDIACAO_INTENSA',0),
    ('SILABAS','TENTATIVAS','1',60),('SILABAS','TENTATIVAS','2',40),('SILABAS','TENTATIVAS','3',20),('SILABAS','TENTATIVAS','4_PLUS',0),
    ('SILABAS','AJUDA','SEM_AJUDA',40),('SILABAS','AJUDA','DICA_VERBAL',20),('SILABAS','AJUDA','MEDIACAO_INTENSA',0),
    ('PALAVRAS','TENTATIVAS','1',40),('PALAVRAS','TENTATIVAS','2',25),('PALAVRAS','TENTATIVAS','3',10),('PALAVRAS','TENTATIVAS','4_PLUS',0),
    ('PALAVRAS','AJUDA','SEM_AJUDA',30),('PALAVRAS','AJUDA','DICA_VERBAL',15),('PALAVRAS','AJUDA','MEDIACAO_INTENSA',0),
    ('PALAVRAS','COMPREENSAO','SIM',30),('PALAVRAS','COMPREENSAO','EM_PARTE',15),('PALAVRAS','COMPREENSAO','AINDA_NAO',0)
) AS p(categoria,criterio,chave,pontos) ON p.categoria=r.categoria;

INSERT INTO config_metricas DEFAULT VALUES;
