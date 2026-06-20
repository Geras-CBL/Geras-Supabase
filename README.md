# Geras - Backend (Supabase)

Este repositório contém toda a infraestrutura backend da aplicação Geras, utilizando o [Supabase](https://supabase.com/). Inclui as migrações da base de dados PostgreSQL, políticas de RLS (Row Level Security), triggers, e Edge Functions (Deno).

---

## Como Correr o Projeto Localmente

Para desenvolver, testar ou correr a base de dados localmente no seu computador sem afetar o ambiente de produção, siga as instruções abaixo.

### Pré-requisitos

1. **Docker**: O Supabase local utiliza o Docker para correr os serviços (PostgreSQL, GoTrue, Realtime, etc.). Certifique-se de que tem o [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e a correr.
2. **Supabase CLI**: Instale a interface de linha de comandos do Supabase.
   - **Windows** (via Scoop): `scoop install supabase`
   - **macOS** (via Homebrew): `brew install supabase/tap/supabase`
   - **Linux** (via Homebrew): `brew install supabase/tap/supabase`

### Instalação e Execução

1. Clone o repositório para a sua máquina local:
   ```bash
   git clone <url-do-repositorio>
   ```

2. Navegue para a raiz do repositório:
   ```bash
   cd Geras-Supabase
   ```

3. Instale/inicie o ambiente Supabase local:
   ```bash
   supabase start
   ```
   *Nota: O primeiro arranque pode demorar alguns minutos pois o Docker terá de descarregar as imagens necessárias. Após arrancar, as suas migrações locais (`supabase/migrations`) serão aplicadas automaticamente a esta base de dados vazia.*

4. No final do arranque, o terminal irá imprimir as credenciais locais:
   - **API URL**: O URL do seu Supabase local (ex: `http://127.0.0.1:54321`)
   - **anon key**: A chave pública para a API
   - **service_role key**: A chave de administração (não expor)
   - **Studio URL**: O painel de gestão web local (ex: `http://127.0.0.1:54323`) onde pode ver as tabelas e dados.

5. **Ligar o Frontend ao Backend Local**:
   Copie a **API URL** e a **anon key** fornecidas no passo anterior e cole-as no ficheiro `.env` da pasta do frontend (`geras`):
   ```env
   EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
   EXPO_PUBLIC_SUPABASE_ANON_KEY=sua_anon_key_local
   ```

### Edge Functions

Se quiser testar chamadas a Edge Functions localmente (como o apagar conta ou notificações), inicie o servidor de funções:
```bash
supabase functions serve
```
*(Nota: Opcionalmente, pode ser necessário configurar um ficheiro `.env` em `supabase/functions/.env` caso a função requeira variáveis externas não suportadas nativamente).*

### Parar o Ambiente Local

Para desligar os serviços locais sem apagar a sua base de dados local:
```bash
supabase stop
```

Se pretender desligar e apagar a base de dados (recomeçar do zero no próximo `start`):
```bash
supabase stop --no-backup
```
