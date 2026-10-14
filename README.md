# DelphiMCP — Servidor MCP em Delphi

Um servidor **MCP (Model Context Protocol)** escrito em **Delphi / Object Pascal**,
que expõe funções de um sistema de negócio (um mini-CRM) como **ferramentas**
que uma IA — como o Claude — pode chamar diretamente.

Projeto criado como complemento ao vídeo **"MCP com Delphi"**.

---

## O que é MCP?

O **Model Context Protocol** é um padrão aberto (criado pela Anthropic) que
define **como um modelo de IA conversa com sistemas externos** — bancos de dados,
APIs, arquivos, sua própria aplicação. Em vez de cada integração ser "na marra",
o MCP padroniza a conversa usando **JSON-RPC 2.0**.

Pense no MCP como o **"USB-C das integrações de IA"**: um único conector padrão
para plugar qualquer ferramenta no modelo.

### Os três papéis

| Papel        | Quem é                         | Função                                            |
|--------------|--------------------------------|---------------------------------------------------|
| **Host**     | Claude Desktop, IDE, seu app   | Onde a IA "mora" e conversa com o usuário          |
| **Client**   | Dentro do host                 | Mantém 1 conexão com cada servidor                 |
| **Server**   | **Este projeto (Delphi)**      | Expõe ferramentas/dados para a IA usar             |

```mermaid
flowchart LR
    U[Usuario] --> H[Host + Modelo de IA<br/>]
    H <-->|JSON-RPC 2.0<br/>via stdio| S[Servidor MCP<br/>DelphiMCP.exe]
    S --> R[(Sistema de negocio<br/>CRM / Banco / API)]
```

O modelo **não executa código sozinho**: ele pede ao servidor "execute a ferramenta
`buscar_cliente` com o termo `Curitiba`", e o **seu código Delphi** decide o que fazer.

---

## Como funciona (o protocolo em 3 passos)

A comunicação é feita por mensagens **JSON-RPC 2.0**, uma por linha, trafegando
pela entrada/saída padrão (**stdio**):

1. **`initialize`** — aperto de mão. O host pergunta a versão do protocolo e as
   capacidades; o servidor se apresenta.
2. **`tools/list`** — o host pergunta "quais ferramentas você tem?". O servidor
   devolve nome, descrição e o *JSON Schema* dos argumentos de cada uma.
3. **`tools/call`** — o modelo decide usar uma ferramenta; o host envia os
   argumentos, o servidor executa e devolve o resultado em texto.

Exemplo real de uma chamada e sua resposta:

```jsonc
// Host -> Servidor
{"jsonrpc":"2.0","id":6,"method":"tools/call",
 "params":{"name":"buscar_cliente","arguments":{"termo":"Curitiba"}}}

// Servidor -> Host
{"jsonrpc":"2.0","id":6,"result":{"content":[{"type":"text",
 "text":"[{\"id\":3,\"nome\":\"Ana Costa\",\"cidade\":\"Curitiba\"}]"}]}}
```

Você **não precisa escrever nada disso à mão**: a biblioteca
[MCPConnect](https://github.com/delphi-blocks/MCPConnect) cuida de todo o
protocolo. Veja a seguir.

---

## Como fica o código com o MCPConnect

Uma ferramenta é só um método Delphi comum, marcado com atributos
(`Clientes.Ferramentas.pas`):

```pascal
type
  TClientesFerramentas = class
  public
    [McpTool('buscar_cliente', 'Busca clientes por nome, cidade ou e-mail.')]
    function BuscarCliente(
      [McpParam('termo', 'Nome, cidade ou e-mail (ou parte) do cliente procurado.')] const ATermo: string
    ): TArray<TCliente>;
  end;

function TClientesFerramentas.BuscarCliente(const ATermo: string): TArray<TCliente>;
begin
  Result := Repositorio.Buscar(ATermo);
end;
```

A partir dos atributos e do RTTI, o MCPConnect:

- gera a resposta do `tools/list`, incluindo o *JSON Schema* dos argumentos;
- converte os argumentos JSON recebidos no `tools/call` para os parâmetros Delphi;
- serializa o retorno (string vira texto; records e arrays viram JSON);
- transforma exceções em respostas de erro JSON-RPC.

E o programa principal (`DelphiMCP.dpr`) só registra a classe e sobe o servidor stdio:

```pascal
var Servidor := TJRPCStdioServer.Create(nil);
try
  Servidor.JRPCServer
    .Plugin.Configure<IMCPConfig>
      .Server
        .SetName('delphi-crm')
        .SetVersion('1.0.0')
      .BackToMCP
      .Tools
        .RegisterClass(TClientesFerramentas)
      .BackToMCP
    .ApplyConfig;

  Servidor.StartServerAndWait;
finally
  Servidor.Free;
end;
```

Para criar uma nova ferramenta, basta adicionar outro método com `[McpTool]`.

---

## Ferramentas expostas por este servidor

| Ferramenta         | Descrição                                        | Argumentos                 |
|--------------------|--------------------------------------------------|----------------------------|
| `ping`             | Verifica se o servidor está ativo                 | —                          |
| `listar_clientes`  | Lista todos os clientes                           | —                          |
| `buscar_cliente`   | Busca por nome, cidade ou e-mail                  | `termo`                    |
| `criar_cliente`    | Cadastra um novo cliente                          | `nome`, `email`, `cidade`  |

Os dados ficam em memória (`Clientes.Repositorio.pas`). Num caso real, aqui você
plugaria **FireDAC**, um serviço REST, ou qualquer regra de negócio já existente.

---

## Requisitos

- **RAD Studio / Delphi** (testado com a versão **37.0 / RAD Studio 13**; o
  MCPConnect suporta Delphi 11 ou superior).
- Windows.
- **git** no PATH (o `build.bat` usa para baixar as dependências).
- Bibliotecas (baixadas automaticamente para `lib\` na primeira compilação):
  - [MCPConnect](https://github.com/delphi-blocks/MCPConnect) — o servidor MCP
  - [Neon](https://github.com/paolo-rossi/delphi-neon) — serialização JSON (usada pelo MCPConnect)
  - [Logify](https://github.com/delphi-blocks/Logify) — logging (usada pelo MCPConnect)

---

## Como compilar

### Opção 1 — Linha de comando (mais rápido)

```bash
build.bat
```

Na primeira execução o script clona as dependências em `lib\`; depois chama o
`rsvars.bat` do RAD Studio e gera `bin\DelphiMCP.exe`.
Se a sua versão do Studio for diferente de `37.0`, edite a variável
`STUDIO_VER` no topo do `build.bat`.

### Opção 2 — Pela IDE

Rode o `build.bat` uma vez (para baixar as dependências em `lib\`), abra
`src\DelphiMCP.dproj` no RAD Studio e pressione **Shift+F9** (Build). O projeto
já aponta o *search path* para `lib\MCPConnect\Source`, `lib\Neon\Source` e
`lib\Logify\Source`.

---

## Como testar sem a IA

O servidor fala JSON-RPC pela stdin/stdout, então dá para testar com um arquivo
de mensagens:

```powershell
Get-Content testes\requisicoes.jsonl | .\bin\DelphiMCP.exe
```

Cada linha de saída é uma resposta JSON-RPC. Os logs de diagnóstico saem pelo
**stderr** (não poluem o canal do protocolo).

---

## Exemplo de como conectar ao Claude Desktop

1. Compile o projeto (`build.bat`).
2. Abra o arquivo de configuração do Claude Desktop:
   `%APPDATA%\Claude\claude_desktop_config.json`
3. Adicione o servidor (veja `config\claude_desktop_config.example.json`):

   ```json
   {
     "mcpServers": {
       "delphi-crm": {
         "command": "C:\\Users\\fsilva\\Documents\\GitHub\\MCP\\bin\\DelphiMCP.exe",
         "args": []
       }
     }
   }
   ```

4. Reinicie o Claude Desktop. As ferramentas aparecerão no ícone de conectores.
5. Peça algo como: *"Liste meus clientes de Curitiba"* ou *"Cadastre o cliente
   Pedro Lima, de Recife"*.

---

## Estrutura do projeto

```
MCP/
├── build.bat                     # Baixa as dependências e compila
├── README.md
├── lib/                          # MCPConnect, Neon e Logify (baixados, fora do git)
├── src/
│   ├── DelphiMCP.dpr             # Programa principal: configura e sobe o servidor
│   ├── DelphiMCP.dproj           # Projeto do RAD Studio
│   ├── Clientes.Ferramentas.pas  # Ferramentas MCP ([McpTool] / [McpParam])
│   └── Clientes.Repositorio.pas  # "Sistema de negócio" (CRM em memória)
└── testes/
    └── requisicoes.jsonl         # Mensagens de exemplo para teste manual
```

### Fluxo interno

```mermaid
sequenceDiagram
    participant H as Host (Claude)
    participant M as MCPConnect
    participant F as TClientesFerramentas
    participant R as Repositorio

    H->>M: linha JSON-RPC (stdin)
    M->>M: parse + localiza a ferramenta "buscar_cliente"
    M->>F: BuscarCliente('Curitiba')
    F->>R: Buscar('Curitiba')
    R-->>F: TArray<TCliente>
    F-->>M: TArray<TCliente>
    M->>M: serializa o resultado em JSON
    M-->>H: linha JSON-RPC (stdout)
```

---

## Licença

MIT. Use, modifique e adapte à vontade.
