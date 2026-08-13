unit MCP.Tools;

{
  Catalogo de ferramentas (tools) do servidor MCP.

  Cada ferramenta possui:
    - name        : identificador chamado pela IA
    - description : texto que ajuda o modelo a decidir quando usar
    - inputSchema : JSON Schema dos argumentos

  A execucao devolve um texto (normalmente JSON) que a IA le como resultado.
}

interface

uses
  System.SysUtils,
  System.JSON,
  Clientes.Repositorio;

type
  TResultadoFerramenta = record
    Texto: string;
    Erro: Boolean;
  end;

  TMCPTools = class
  private
    FRepo: TClienteRepositorio;

    function ClienteParaJSON(const ACliente: TCliente): TJSONObject;
    function EsquemaObjeto(AProps: TJSONObject; const ARequeridos: array of string): TJSONObject;
    function PropString(const ADescricao: string): TJSONObject;

    // Implementacao das ferramentas
    function FerrPing(AArgs: TJSONObject): TResultadoFerramenta;
    function FerrListarClientes(AArgs: TJSONObject): TResultadoFerramenta;
    function FerrBuscarCliente(AArgs: TJSONObject): TResultadoFerramenta;
    function FerrCriarCliente(AArgs: TJSONObject): TResultadoFerramenta;
  public
    constructor Create;
    destructor Destroy; override;

    /// Retorna o array de definicoes para o metodo tools/list.
    function ListarDefinicoes: TJSONArray;

    /// Executa a ferramenta pelo nome (metodo tools/call).
    function Executar(const ANome: string; AArgs: TJSONObject): TResultadoFerramenta;
  end;

implementation

{ Utilitarios }

function TMCPTools.PropString(const ADescricao: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'string');
  Result.AddPair('description', ADescricao);
end;

function TMCPTools.EsquemaObjeto(AProps: TJSONObject;
  const ARequeridos: array of string): TJSONObject;
var
  Req: TJSONArray;
  Nome: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', AProps);
  if Length(ARequeridos) > 0 then
  begin
    Req := TJSONArray.Create;
    for Nome in ARequeridos do
      Req.Add(Nome);
    Result.AddPair('required', Req);
  end;
end;

function TMCPTools.ClienteParaJSON(const ACliente: TCliente): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(ACliente.Id));
  Result.AddPair('nome', ACliente.Nome);
  Result.AddPair('email', ACliente.Email);
  Result.AddPair('cidade', ACliente.Cidade);
end;

{ Ciclo de vida }

constructor TMCPTools.Create;
begin
  inherited Create;
  FRepo := TClienteRepositorio.Create;
end;

destructor TMCPTools.Destroy;
begin
  FRepo.Free;
  inherited;
end;

{ Definicoes (tools/list) }

function TMCPTools.ListarDefinicoes: TJSONArray;

  function Def(const ANome, ADescricao: string; AEsquema: TJSONObject): TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('name', ANome);
    Result.AddPair('description', ADescricao);
    Result.AddPair('inputSchema', AEsquema);
  end;

var
  PropsBuscar, PropsCriar: TJSONObject;
begin
  Result := TJSONArray.Create;

  Result.Add(Def('ping',
    'Verifica se o servidor MCP em Delphi esta ativo e retorna informacoes basicas.',
    EsquemaObjeto(TJSONObject.Create, [])));

  Result.Add(Def('listar_clientes',
    'Lista todos os clientes cadastrados no sistema.',
    EsquemaObjeto(TJSONObject.Create, [])));

  PropsBuscar := TJSONObject.Create;
  PropsBuscar.AddPair('termo', PropString('Nome, cidade ou e-mail (ou parte) do cliente procurado.'));
  Result.Add(Def('buscar_cliente',
    'Busca clientes por nome, cidade ou e-mail.',
    EsquemaObjeto(PropsBuscar, ['termo'])));

  PropsCriar := TJSONObject.Create;
  PropsCriar.AddPair('nome', PropString('Nome completo do cliente.'));
  PropsCriar.AddPair('email', PropString('E-mail do cliente.'));
  PropsCriar.AddPair('cidade', PropString('Cidade do cliente.'));
  Result.Add(Def('criar_cliente',
    'Cadastra um novo cliente no sistema.',
    EsquemaObjeto(PropsCriar, ['nome', 'email', 'cidade'])));
end;

{ Execucao (tools/call) }

function TMCPTools.Executar(const ANome: string;
  AArgs: TJSONObject): TResultadoFerramenta;
begin
  if SameText(ANome, 'ping') then
    Result := FerrPing(AArgs)
  else if SameText(ANome, 'listar_clientes') then
    Result := FerrListarClientes(AArgs)
  else if SameText(ANome, 'buscar_cliente') then
    Result := FerrBuscarCliente(AArgs)
  else if SameText(ANome, 'criar_cliente') then
    Result := FerrCriarCliente(AArgs)
  else
  begin
    Result.Erro := True;
    Result.Texto := Format('Ferramenta desconhecida: "%s".', [ANome]);
  end;
end;

function TMCPTools.FerrPing(AArgs: TJSONObject): TResultadoFerramenta;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('status', 'ok');
    Obj.AddPair('servidor', 'DelphiMCP');
    Obj.AddPair('linguagem', 'Delphi / Object Pascal');
    Obj.AddPair('total_clientes', TJSONNumber.Create(FRepo.Total));
    Result.Texto := Obj.ToJSON;
    Result.Erro := False;
  finally
    Obj.Free;
  end;
end;

function TMCPTools.FerrListarClientes(AArgs: TJSONObject): TResultadoFerramenta;
var
  Lista: TJSONArray;
  Cliente: TCliente;
begin
  Lista := TJSONArray.Create;
  try
    for Cliente in FRepo.Listar do
      Lista.Add(ClienteParaJSON(Cliente));
    Result.Texto := Lista.ToJSON;
    Result.Erro := False;
  finally
    Lista.Free;
  end;
end;

function TMCPTools.FerrBuscarCliente(AArgs: TJSONObject): TResultadoFerramenta;
var
  Termo: string;
  Lista: TJSONArray;
  Cliente: TCliente;
  Encontrados: TArray<TCliente>;
begin
  Termo := '';
  if (AArgs <> nil) and (AArgs.GetValue('termo') <> nil) then
    Termo := AArgs.GetValue<string>('termo');

  Encontrados := FRepo.Buscar(Termo);
  Lista := TJSONArray.Create;
  try
    for Cliente in Encontrados do
      Lista.Add(ClienteParaJSON(Cliente));

    if Length(Encontrados) = 0 then
      Result.Texto := Format('Nenhum cliente encontrado para "%s".', [Termo])
    else
      Result.Texto := Lista.ToJSON;
    Result.Erro := False;
  finally
    Lista.Free;
  end;
end;

function TMCPTools.FerrCriarCliente(AArgs: TJSONObject): TResultadoFerramenta;
var
  Nome, Email, Cidade: string;
  Novo: TCliente;
  Obj: TJSONObject;
begin
  if AArgs = nil then
  begin
    Result.Erro := True;
    Result.Texto := 'Argumentos ausentes: informe nome, email e cidade.';
    Exit;
  end;

  Nome := '';
  Email := '';
  Cidade := '';
  if AArgs.GetValue('nome') <> nil then
    Nome := AArgs.GetValue<string>('nome');
  if AArgs.GetValue('email') <> nil then
    Email := AArgs.GetValue<string>('email');
  if AArgs.GetValue('cidade') <> nil then
    Cidade := AArgs.GetValue<string>('cidade');

  if Nome.Trim.IsEmpty then
  begin
    Result.Erro := True;
    Result.Texto := 'O campo "nome" e obrigatorio.';
    Exit;
  end;

  Novo := FRepo.Criar(Nome, Email, Cidade);
  Obj := ClienteParaJSON(Novo);
  try
    Obj.AddPair('mensagem', 'Cliente criado com sucesso.');
    Result.Texto := Obj.ToJSON;
    Result.Erro := False;
  finally
    Obj.Free;
  end;
end;

end.
