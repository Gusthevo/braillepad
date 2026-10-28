# DTAE — Modelagem E-R, PostgreSQL e ambiente local (MVP)

Pacote de partida para a plataforma Android Flutter + FastAPI (Python) + PostgreSQL, hospedados em servidor local na mesma rede Wi-Fi do dispositivo.

## Conteúdo

```text
dtae_modelagem/
├── docs/
│   ├── 01_modelo_er.mmd          # Modelo conceitual Mermaid
│   ├── 02_modelo_relacional.mmd   # Tabelas + PK/FK em Mermaid
│   └── 03_modelo_relacional.md    # Dicionario, regras, calculos e endpoints
├── database/
│   ├── 001_schema.sql            # Tabelas, indices, triggers e views
│   └── 002_seed.sql              # Modulos, 30 atividades e parametros
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── main.py                # /api/health e /api/pad/health apenas
│       └── scoring.py             # Logica de pontuacao configuravel
├── docker-compose.yml
├── .env.example
└── .gitignore
```

## Iniciar no computador-servidor

1. Instale Docker Engine + plugin Docker Compose (ou Docker Desktop).
2. Copie `.env.example` para `.env` e defina uma senha forte, sem espaços não escapados em valores de configuração.
3. No diretório deste README, rode:

```bash
docker compose up --build -d
docker compose ps
curl http://localhost:8000/api/health
curl http://localhost:8000/api/pad/health
```

No celular Android conectado **à mesma rede local**, a base da API será `http://IP_DO_SERVIDOR:8000/api`. O IP do exemplo é ilustrativo; descubra o IP real da LAN, prefira reserva DHCP ou IP fixo e confira regras de firewall e isolamento entre clientes do roteador.

**Para produção com dados reais de crianças:** use HTTPS/TLS mesmo na LAN (proxy reverso ou outra solução de rede segura), login/autorização em todos os endpoints, backups testados e políticas de privacidade. HTTP simples aqui é apenas para desenvolvimento no laboratório. Android pode bloquear HTTP em versões atuais se não for habilitado apenas no build de desenvolvimento.

## Dados iniciais

- 3 módulos, cada qual com 10 atividades fixas (`01..10`): 30 cadastros.
- A atividade 01 de cada módulo é **demonstração técnica** com fases/alvos derivados dos exemplos pedagógicos dos documentos; não é o conteúdo final da professora.
- As outras 27 atividades ficam `publicada = FALSE` até que o conteúdo pedagógico esteja definido, pois uma sessão não pode iniciar sem alvos.
- Fichas iniciais A,E,I,O,U,M,L, alvos exemplificativos de vogais, sílabas e palavras.
- Regras de pontuação v1 e limites de status são semeados nas tabelas.

## Persistência do PostgreSQL

O volume Docker `postgres_data` mantém o banco após `docker compose down` e reinícios. **Nunca use `docker compose down -v` em ambiente com dados importantes**, pois isso remove o volume de dados.

Arquivos `database/001_schema.sql` e `002_seed.sql` rodarão **apenas na primeira inicialização quando o volume estiver vazio**. Alterações posteriores devem ser feitas por migrações versionadas (recomendação: Alembic), não pela edição dos scripts de inicialização. Referência: https://docs.docker.com/guides/postgresql/.

## Backups simples (exemplo de laboratório)

```bash
# Cria dump consistente em formato customizado (arquivo fora do container):
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > dtae_backup.dump
```

Garanta que backups também fiquem em armazenamento seguro separado do servidor. Teste restauração em ambiente isolado; este pacote não automatiza isso.

## Limites do starter

- Docker Compose e SQL foram preparados e validados estaticamente, **mas não executados contra Docker/PostgreSQL reais neste ambiente**; teste a inicialização no servidor local antes de usar.
- O FastAPI contém apenas `/api/health` e `/api/pad/health`; NÃO há CRUD, login nem fluxo completo de sessão implementados.
- O aplicativo Flutter ainda será desenvolvido; ele não é executado no Docker.
- O teste PAD está indisponível e não devolve verde/vermelho sem dispositivo conectado.

Para implementar o backend, siga a ordem: autenticação → turmas/alunos → catálogo → sessão + tentativas → pontuação → relatórios → integração PAD.
