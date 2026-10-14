unit Clientes.Ferramentas;

{
  Ferramentas (tools) do servidor MCP.

  Com o MCPConnect basta marcar os metodos com atributos:
    - [McpTool]  publica o metodo como ferramenta (nome + descricao)
    - [McpParam] descreve cada argumento

  A biblioteca gera sozinha o tools/list (com o JSON Schema dos argumentos),
  converte os argumentos JSON para os parametros Delphi e serializa o retorno
  (strings viram texto; records e arrays viram JSON).

  Uma instancia desta classe e criada a cada chamada, por isso os dados ficam
  no repositorio global (Clientes.Repositorio), e nao em campos da classe.
}

interface

uses
  System.SysUtils,
  MCPConnect.MCP.Attributes,
  Clientes.Repositorio;

type
  TClientesFerramentas = class
  public
    [McpTool('ping', 'Verifica se o servidor MCP em Delphi esta ativo e retorna informacoes basicas.')]
    function Ping: string;

    [McpTool('listar_clientes', 'Lista todos os clientes cadastrados no sistema.')]
    function ListarClientes: TArray<TCliente>;

    [McpTool('buscar_cliente', 'Busca clientes por nome, cidade ou e-mail.')]
    function BuscarCliente(
      [McpParam('termo', 'Nome, cidade ou e-mail (ou parte) do cliente procurado.')] const ATermo: string
    ): TArray<TCliente>;

    [McpTool('criar_cliente', 'Cadastra um novo cliente no sistema.')]
    function CriarCliente(
      [McpParam('nome', 'Nome completo do cliente.')] const ANome: string;
      [McpParam('email', 'E-mail do cliente.')] const AEmail: string;
      [McpParam('cidade', 'Cidade do cliente.')] const ACidade: string
    ): TCliente;
  end;

implementation

function TClientesFerramentas.Ping: string;
begin
  Result := Format('DelphiMCP ativo (Delphi / Object Pascal + MCPConnect). Clientes cadastrados: %d.',
    [Repositorio.Total]);
end;

function TClientesFerramentas.ListarClientes: TArray<TCliente>;
begin
  Result := Repositorio.Listar;
end;

function TClientesFerramentas.BuscarCliente(const ATermo: string): TArray<TCliente>;
begin
  Result := Repositorio.Buscar(ATermo);
end;

function TClientesFerramentas.CriarCliente(const ANome, AEmail, ACidade: string): TCliente;
begin
  // Uma excecao vira uma resposta de erro JSON-RPC para o host.
  if ANome.Trim.IsEmpty then
    raise Exception.Create('O campo "nome" e obrigatorio.');

  Result := Repositorio.Criar(ANome, AEmail, ACidade);
end;

end.
