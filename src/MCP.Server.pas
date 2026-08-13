unit MCP.Server;

{
  Nucleo do servidor MCP.

  Le mensagens JSON-RPC 2.0 do transporte, interpreta o metodo e responde.
  Metodos suportados:
    - initialize                 (handshake inicial)
    - notifications/initialized  (notificacao, sem resposta)
    - ping                       (keep-alive)
    - tools/list                 (lista as ferramentas disponiveis)
    - tools/call                 (executa uma ferramenta)
}

interface

uses
  System.SysUtils,
  System.JSON,
  MCP.Transport,
  MCP.Tools;

const
  PROTOCOLO_MCP = '2024-11-05';
  NOME_SERVIDOR = 'delphi-mcp-server';
  VERSAO_SERVIDOR = '1.0.0';

  // Codigos de erro JSON-RPC
  ERRO_PARSE = -32700;
  ERRO_REQUISICAO_INVALIDA = -32600;
  ERRO_METODO_NAO_ENCONTRADO = -32601;
  ERRO_PARAMS_INVALIDOS = -32602;
  ERRO_INTERNO = -32603;

type
  TMCPServer = class
  private
    FTransporte: TMCPTransport;
    FTools: TMCPTools;

    function ClonarId(AId: TJSONValue): TJSONValue;
    procedure Responder(AId: TJSONValue; AResultado: TJSONValue);
    procedure ResponderErro(AId: TJSONValue; ACodigo: Integer; const AMensagem: string);
    procedure Processar(ARequisicao: TJSONObject);

    function TratarInitialize(AParams: TJSONObject): TJSONObject;
    function TratarToolsList: TJSONObject;
    function TratarToolsCall(AParams: TJSONObject): TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Executar;
  end;

implementation

constructor TMCPServer.Create;
begin
  inherited Create;
  FTransporte := TMCPTransport.Create;
  FTools := TMCPTools.Create;
end;

destructor TMCPServer.Destroy;
begin
  FTools.Free;
  FTransporte.Free;
  inherited;
end;

procedure TMCPServer.Executar;
var
  Linha: string;
  Valor: TJSONValue;
begin
  FTransporte.Log('Servidor iniciado. Aguardando mensagens JSON-RPC...');
  while FTransporte.LerMensagem(Linha) do
  begin
    if Linha.Trim.IsEmpty then
      Continue;

    Valor := TJSONObject.ParseJSONValue(Linha);
    if not (Valor is TJSONObject) then
    begin
      Valor.Free;
      ResponderErro(nil, ERRO_PARSE, 'JSON invalido.');
      Continue;
    end;

    try
      Processar(TJSONObject(Valor));
    finally
      Valor.Free;
    end;
  end;
  FTransporte.Log('Fluxo encerrado. Finalizando.');
end;

function TMCPServer.ClonarId(AId: TJSONValue): TJSONValue;
begin
  // Reconstroi o id preservando o tipo (numero, string ou null),
  // evitando problemas de propriedade do JSON original.
  if AId = nil then
    Result := TJSONNull.Create
  else if AId is TJSONNumber then
    Result := TJSONNumber.Create(TJSONNumber(AId).AsInt64)
  else if AId is TJSONString then
    Result := TJSONString.Create(TJSONString(AId).Value)
  else
    Result := TJSONNull.Create;
end;

procedure TMCPServer.Responder(AId: TJSONValue; AResultado: TJSONValue);
var
  Resposta: TJSONObject;
begin
  Resposta := TJSONObject.Create;
  try
    Resposta.AddPair('jsonrpc', '2.0');
    Resposta.AddPair('id', ClonarId(AId));
    Resposta.AddPair('result', AResultado);
    FTransporte.EnviarMensagem(Resposta.ToJSON);
  finally
    Resposta.Free; // libera tambem AResultado e o id
  end;
end;

procedure TMCPServer.ResponderErro(AId: TJSONValue; ACodigo: Integer;
  const AMensagem: string);
var
  Resposta, Erro: TJSONObject;
begin
  Resposta := TJSONObject.Create;
  try
    Resposta.AddPair('jsonrpc', '2.0');
    Resposta.AddPair('id', ClonarId(AId));
    Erro := TJSONObject.Create;
    Erro.AddPair('code', TJSONNumber.Create(ACodigo));
    Erro.AddPair('message', AMensagem);
    Resposta.AddPair('error', Erro);
    FTransporte.EnviarMensagem(Resposta.ToJSON);
  finally
    Resposta.Free;
  end;
end;

procedure TMCPServer.Processar(ARequisicao: TJSONObject);
var
  Metodo: string;
  Id: TJSONValue;
  Params: TJSONObject;
  TemId: Boolean;
begin
  Metodo := '';
  if ARequisicao.GetValue('method') <> nil then
    Metodo := ARequisicao.GetValue<string>('method');

  Id := ARequisicao.GetValue('id'); // nil quando e uma notificacao
  TemId := Id <> nil;

  Params := nil;
  if ARequisicao.GetValue('params') is TJSONObject then
    Params := TJSONObject(ARequisicao.GetValue('params'));

  FTransporte.Log('Metodo recebido: ' + Metodo);

  // Notificacoes (sem id) nao geram resposta.
  if Metodo.StartsWith('notifications/') then
    Exit;

  if Metodo = 'initialize' then
    Responder(Id, TratarInitialize(Params))
  else if Metodo = 'ping' then
    Responder(Id, TJSONObject.Create)
  else if Metodo = 'tools/list' then
    Responder(Id, TratarToolsList)
  else if Metodo = 'tools/call' then
    Responder(Id, TratarToolsCall(Params))
  else if TemId then
    ResponderErro(Id, ERRO_METODO_NAO_ENCONTRADO,
      Format('Metodo nao suportado: "%s".', [Metodo]));
end;

function TMCPServer.TratarInitialize(AParams: TJSONObject): TJSONObject;
var
  Capacidades, Ferramentas, Info: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('protocolVersion', PROTOCOLO_MCP);

  Capacidades := TJSONObject.Create;
  Ferramentas := TJSONObject.Create; // {} = suporta ferramentas
  Capacidades.AddPair('tools', Ferramentas);
  Result.AddPair('capabilities', Capacidades);

  Info := TJSONObject.Create;
  Info.AddPair('name', NOME_SERVIDOR);
  Info.AddPair('version', VERSAO_SERVIDOR);
  Result.AddPair('serverInfo', Info);
end;

function TMCPServer.TratarToolsList: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('tools', FTools.ListarDefinicoes);
end;

function TMCPServer.TratarToolsCall(AParams: TJSONObject): TJSONObject;
var
  Nome: string;
  Args: TJSONObject;
  Res: TResultadoFerramenta;
  Conteudo: TJSONArray;
  Item: TJSONObject;
begin
  Nome := '';
  Args := nil;

  if AParams <> nil then
  begin
    if AParams.GetValue('name') <> nil then
      Nome := AParams.GetValue<string>('name');
    if AParams.GetValue('arguments') is TJSONObject then
      Args := TJSONObject(AParams.GetValue('arguments'));
  end;

  Res := FTools.Executar(Nome, Args);

  // Formato de resposta do tools/call: array "content" de blocos.
  Item := TJSONObject.Create;
  Item.AddPair('type', 'text');
  Item.AddPair('text', Res.Texto);

  Conteudo := TJSONArray.Create;
  Conteudo.Add(Item);

  Result := TJSONObject.Create;
  Result.AddPair('content', Conteudo);
  Result.AddPair('isError', TJSONBool.Create(Res.Erro));
end;

end.
