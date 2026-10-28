# DTAE — Modelo relacional e regras de negocio (MVP)

**Status:** proposta implementável; validar em ambiente PostgreSQL antes de uso real.  
**Origem:** fluxograma DTAE, Atividades DTAE, Métricas do app (versão simples) e decisões do projeto.

## 1. Modelo conceitual vs. relacional

- `01_modelo_er.mmd`: entidades e cardinalidades conceituais (Mermaid ER).
- `02_modelo_relacional.mmd`: tabelas com PK/FK principais (Mermaid ER).
- `../database/001_schema.sql`: modelo físico PostgreSQL com tipos, índices, checks e triggers.
- `../database/002_seed.sql`: módulos, atividades mockadas, algumas fases demonstrativas e parâmetros.

A estrutura pedagógica precisa de **FASE_ALVO** (associativa N:M): o alvo `A` pode aparecer em várias fases ou atividades. Um alvo possui N fichas esperadas em `ALVO_FICHA` (posição 1..N). A sessão **não** aponta diretamente para a fase, pois registra cada `EXECUCAO_ALVO` associado ao `FASE_ALVO` e à ordem efetivamente usada. Para uma atividade sem conteúdo configurado, não pode ser aberta sessão.

## 2. Dicionário de tabelas

| Tabela | PK | FK e responsabilidade |
|---|---|---|
| `professor` | `id` UUID | Conta do professor, e-mail exclusivo ignorando maiúsculas; somente hash de senha |
| `sessao_autenticacao` | `id` UUID | `professor_id`; refresh-token **hasheado** e revogável, para permanecer conectado |
| `preferencia_professor` | `professor_id` UUID | Preferências de acessibilidade e modo padrão |
| `turma` | `id` UUID | `professor_id`; exatamente um professor responsável |
| `aluno` | `id` UUID | `turma_atual_id NOT NULL`; uma turma atual obrigatória |
| `transferencia_aluno` | `id` UUID | aluno, turma de origem/destino, professor que registrou; auditoria de transferência |
| `modulo` | `id` SMALLINT | 1 vogais, 2 sílabas, 3 palavras |
| `atividade` | `id` UUID | `modulo_id`; número 1..10 único dentro do módulo; `publicada` controla execução |
| `fase_atividade` | `id` UUID | `atividade_id`; exploração, ordem, embaralhada, comparação, formação |
| `alvo` | `id` UUID | Vogal, sílaba, palavra ou par de comparação |
| `ficha` | `id` UUID | Símbolo físico; código RFID ainda opcional |
| `alvo_ficha` | (`alvo_id`,`posicao`) | Sequência de fichas esperadas; ex.: MALA = M,A,L,A |
| `fase_alvo` | `id` UUID | (`fase_id`,`alvo_id`); vínculo N:M e ordem padrão |
| `sessao_atividade` | `id` UUID | professor, turma no momento, aluno, atividade, modo, status e duração |
| `execucao_alvo` | `id` UUID | sessão e fase_alvo, `ordem_real` — guarda a randomização |
| `tentativa` | `id` UUID | execucao_alvo, número, resultado e horários |
| `leitura_ficha` | `id` UUID | tentativa, ficha esperada/apresentada, posição, acerto/erro, origem e horário |
| `comentario_professor` | `id` UUID | sessão, professor e texto; consolidado via consulta por aluno/atividade |
| `regra_pontuacao` | `id` UUID | versão e categoria da regra; uma versão ativa por categoria |
| `parametro_pontuacao` | (`regra_id`,`criterio`,`chave`) | Pontos por tentativas, ajuda e compreensão |
| `avaliacao_sessao` | `sessao_id` UUID | sessao concluída, regra/versionamento, ajuda, compreensão e nota |
| `config_metricas` | `id` SMALLINT | Limiares de status, janela de notas e alertas; linha única |

As chaves estrangeiras são `ON DELETE RESTRICT`. No MVP, alunos/turmas são arquivados pelo timestamp `arquivado_em` / `arquivada_em`, não apagados, preservando histórico. A exclusão definitiva de dados pessoais será um fluxo administrativo futuro, sujeito à política de retenção e à LGPD.

## 3. Cardinalidades essenciais

- Professor 1:N Turma; Turma 1:N Aluno (vínculo atual), mas o aluno sempre tem exatamente uma turma atual.
- Módulo 1:N Atividade; Atividade 1:N Fase; Fase N:M Alvo por `fase_alvo`; Alvo 1:N `alvo_ficha`.
- Professor / Turma / Aluno / Atividade 1:N `sessao_atividade`.
- Sessão 1:N `execucao_alvo`; Execução 1:N Tentativa; Tentativa 1:N Leitura; Sessão 1:N Comentário; Sessão 0:1 Avaliação.
- Regra 1:N Parâmetros; Regra 1:N Avaliações.

## 4. Regras que o banco já protege

1. `aluno.turma_atual_id` obrigatório; `sessao_atividade.turma_id` armazena a turma **histórica**.
2. `atividade` tem numeração 1..10 sem duplicação dentro do módulo, e `modulo` restringe categorias 1, 2 e 3.
3. `UNIQUE INDEX ... WHERE status='EM_ANDAMENTO'` impede duas sessões abertas pelo mesmo professor, inclusive em requisições concorrentes.
4. Trigger de criação de sessão confirma que o professor é da turma, o aluno está matriculado nela e a atividade está publicada e tem alvos obrigatórios.
5. Trigger de `execucao_alvo` verifica que o alvo pertence à atividade daquela sessão.
6. Trigger de finalização exige estado `CONCLUIDA` somente se **todos** os alvos obrigatórios têm execução concluída; caso contrário `PARCIAL`.
7. Uma avaliação só pode ser gravada para sessão concluída e que tenha fase pontuável, usando regra da categoria correta.
8. Cada leitura guarda ficha esperada e apresentada; `correta` deve coincidir com a igualdade das fichas.

### Regras que devem ser mantidas na camada de serviços FastAPI

- Validação de permissões em **todas** as consultas e alterações por professor, nunca confiar no `professor_id` enviado pelo celular.
- Mudança de turma/transferência precisa acontecer numa **transação**: verificar permissão, gravar `transferencia_aluno` e atualizar `aluno.turma_atual_id`.
- Não permitir arquivar a turma que ainda contém alunos ativos sem transferi-los ou arquivá-los.
- Não permitir iniciar sessão se houver outra aberta; transformar erro de índice parcial em resposta HTTP 409.
- `fase_alvo` precisa pertencer à atividade correta, e a ordem aleatória deve ser persistida em `execucao_alvo.ordem_real`.
- Para uma ficha incorreta, encerrar a tentativa com `ERRO`, registrar a leitura e permitir nova tentativa **desde a posição 1**.
- Para marcar um alvo como concluído em fase pontuável, validar sequência completa e última tentativa `ACERTO`; fases Explorar podem ser concluídas sem nota.
- Impedir inserção de tentativas/leitura em sessões encerradas e edição de conteúdo pedagógico que já tenha sessões, ou versionar conteúdo futuramente.
- Atualizar `avaliacao_sessao` somente após finalizar sessão como `CONCLUIDA`; **não** atribuir uma nota final completa a uma sessão parcial.
- Desabilitar integração PAD até que o dispositivo esteja implementado. `/api/health` mede API + banco; não mede o PAD.

## 5. Cálculo das notas (documento de métricas)

O backend identifica os alvos de fases `pontuavel = TRUE` e coleta quantas tentativas foram necessárias até o acerto final. A fase Explorar não entra na nota.

### Vogais e sílabas

| Tentativas | Pontos |
|---|---:|
| 1 | 60 |
| 2 | 40 |
| 3 | 20 |
| 4 ou mais | 0 |

| Ajuda | Pontos |
|---|---:|
| Sem ajuda | 40 |
| Dica verbal | 20 |
| Mediação intensa | 0 |

`nota = média(pontos de tentativas de todos os alvos pontuáveis) + pontos de ajuda`.

### Palavras

| Tentativas | Pontos |
|---|---:|
| 1 | 40 |
| 2 | 25 |
| 3 | 10 |
| 4 ou mais | 0 |

Ajuda: sem ajuda +30, dica verbal +15, mediação intensa +0.  
Compreensão: sim +30, em parte +15, ainda não +0.

`nota = média(pontos de tentativas de todos os alvos pontuáveis) + pontos de ajuda + pontos de compreensão`.

**Proposta explícita para atividades com várias fases:** reunir todos os alvos das fases pontuáveis da sessão e tirar uma média de seus pontos de tentativas; acrescentar ajuda/compreensão uma única vez por sessão. A professora ainda poderá validar esta agregação com base nas 30 atividades definitivas. Caso a atividade misture tipos de pontuação, será necessário definir uma regra específica antes da publicação.

A função de exemplo está em `backend/app/scoring.py`, **sem pesos hardcoded**. A aplicação deve carregar `parametro_pontuacao` da regra ativa e persistir `regra_id` com a nota.

## 6. Indicadores e progresso (consultas derivadas)

- `vw_progresso_modulo`: proporção de atividades `obrigatoria = TRUE` com ao menos uma sessão concluída por aluno. Repetições não contam duas vezes. As 10 atividades de cada módulo são obrigatórias por padrão.
- `vw_status_aprendizagem`: média das últimas 3 notas de sessões concluídas, ignorando parciais. **Cinza com menos de 2 notas**; Verde ≥75; Amarelo 50 a 74,99; Vermelho <50.
- `vw_comentarios_por_atividade`: comentários por aluno e atividade, mantendo referência à sessão original.
- Alertas: queda da nota mais recente de ≥20 pontos, 3 notas consecutivas crescentes, e erro na mesma posição de ficha em ≥3 atividades. Consultar histórico em vez de armazenar sinais redundantes.
- Tempo registrado para relatórios; **nunca** subtrai pontos.

## 7. Exemplo de operação transacional

**Iniciar sessão:** (1) validar token do professor; (2) checar turma + matrícula; (3) criar `sessao_atividade` (modo MANUAL/SIMULACAO); (4) para cada fase_alvo criar `execucao_alvo` na ordem escolhida (embaralhar onde aplicável); (5) commit.

**Responder:** (1) criar ou continuar `tentativa`; (2) gravar `leitura_ficha` com posição, gabarito, símbolo apresentado, origem, timestamp; (3) se erro, finalizar tentativa ERRO e reiniciar; (4) se última posição correta, finalizar tentativa ACERTO e alvo CONCLUIDO.

**Finalizar manualmente:** (1) professor clica Finalizar; (2) consulta alvos obrigatórios pendentes; (3) encerra sessão como PARCIAL/CONCLUIDA; (4) se CONCLUIDA e com fases pontuáveis, ler ajuda e compreensão e calcular nota usando regra ativa; (5) apresentar resumo; (6) repetir = nova sessão.

## 8. Endpoint planning (não implementados no starter)

| Recurso | Operações FastAPI esperadas |
|---|---|
| Autenticação | `POST /api/auth/login`, `/register`, `/refresh`, `/logout` |
| Professor | `GET/PATCH /api/me`, `PATCH /api/me/password`, `GET/PATCH /api/me/preferences` |
| Turmas | `GET/POST /api/turmas`, `GET/PATCH /api/turmas/{id}`, `POST /api/turmas/{id}/arquivar` |
| Alunos | `GET/POST /api/alunos`, `GET/PATCH /api/alunos/{id}`, `POST /api/alunos/{id}/transferir`, `POST /api/alunos/{id}/arquivar` |
| Módulos | `GET /api/modulos`, `GET /api/modulos/{id}/atividades` |
| Atividades | `GET /api/atividades/{id}`, `GET /api/atividades/{id}/historico?turma_id=...` |
| Sessões | `POST /api/sessoes`, `POST /api/sessoes/{id}/alvos/{execucao_id}/tentativas`, `POST /api/sessoes/{id}/finalizar` |
| Feedback | `GET/POST /api/sessoes/{id}/comentarios` |
| Relatórios | `GET /api/alunos/{id}/progresso`, `GET /api/turmas/{id}/metricas` |
| Saúde | `GET /api/health`, `GET /api/pad/health` (indisponível) |

Para uso real com dados de crianças, a API não deve expor CRUD sem autenticação/autorização, e o Android deve usar armazenamento seguro de credenciais. O starter atual entrega **somente os endpoints de saúde**, não os CRUD.

## 9. Decisões para o futuro

- Comprovação de requisitos pedagógicos, modelagem de áudio e fases de comparação complexas, quando chegarem os materiais definitivos.
- Histórico de versão de conteúdo das atividades quando a criação/edição for habilitada fora do MVP.
- Revisar exigências da LGPD, período de retenção, criptografia e políticas de backup/restauração antes de operar com dados reais de menores.
- Integrar hardware PAD separadamente, sem simular resultado de conectividade real.
