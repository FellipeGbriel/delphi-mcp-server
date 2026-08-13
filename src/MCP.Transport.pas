unit MCP.Transport;

{
  Transporte stdio do MCP.

  Le e escreve mensagens JSON-RPC delimitadas por quebra de linha (\n)
  diretamente nos handles padrao do Windows, garantindo UTF-8 sem BOM
  e sem traducao CRLF (que corromperia o protocolo).
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math;

type
  TMCPTransport = class
  private
    FEntrada: THandleStream;
    FSaida: THandleStream;
  public
    constructor Create;
    destructor Destroy; override;

    /// Le uma linha (mensagem) da entrada padrao.
    /// Retorna False quando o fluxo termina (EOF) - hora de encerrar.
    function LerMensagem(out ALinha: string): Boolean;

    /// Escreve uma mensagem no stdout, adicionando o \n final.
    procedure EnviarMensagem(const ALinha: string);

    /// Escreve diagnostico no stderr (nunca no stdout).
    procedure Log(const AMensagem: string);
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

constructor TMCPTransport.Create;
begin
  inherited Create;
{$IFDEF MSWINDOWS}
  FEntrada := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE));
  FSaida := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
{$ELSE}
  FEntrada := THandleStream.Create(0); // stdin
  FSaida := THandleStream.Create(1);   // stdout
{$ENDIF}
end;

destructor TMCPTransport.Destroy;
begin
  FEntrada.Free;
  FSaida.Free;
  inherited;
end;

function TMCPTransport.LerMensagem(out ALinha: string): Boolean;
var
  Buffer: TBytes;
  B: Byte;
  Tamanho: Integer;
begin
  SetLength(Buffer, 0);
  Tamanho := 0;
  while True do
  begin
    if FEntrada.Read(B, 1) = 0 then
    begin
      // EOF: se algo ja foi lido, entrega a ultima linha; senao, encerra.
      if Tamanho > 0 then
      begin
        SetLength(Buffer, Tamanho);
        ALinha := TEncoding.UTF8.GetString(Buffer);
        Exit(True);
      end;
      ALinha := '';
      Exit(False);
    end;

    if B = 10 then // \n  -> fim da mensagem
      Break;
    if B = 13 then // \r  -> ignorado
      Continue;

    if Tamanho >= Length(Buffer) then
      SetLength(Buffer, IfThen(Length(Buffer) = 0, 256, Length(Buffer) * 2));
    Buffer[Tamanho] := B;
    Inc(Tamanho);
  end;

  SetLength(Buffer, Tamanho);
  ALinha := TEncoding.UTF8.GetString(Buffer);
  Result := True;
end;

procedure TMCPTransport.EnviarMensagem(const ALinha: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(ALinha + #10);
  if Length(Bytes) > 0 then
    FSaida.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure TMCPTransport.Log(const AMensagem: string);
begin
  Writeln(ErrOutput, '[DelphiMCP] ' + AMensagem);
  Flush(ErrOutput);
end;

end.
