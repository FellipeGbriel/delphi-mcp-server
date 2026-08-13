program DelphiMCP;

{
  DelphiMCP - Servidor MCP (Model Context Protocol) escrito em Delphi.

  Este e um servidor MCP que se comunica via JSON-RPC 2.0 sobre stdio
  (entrada e saida padrao), o transporte mais usado por hosts como o
  Claude Desktop. Ele expoe "ferramentas" (tools) que um modelo de IA
  pode chamar - neste exemplo, um pequeno CRM em memoria.

  Regras importantes do transporte stdio:
    - Cada mensagem JSON-RPC ocupa exatamente UMA linha (terminada por \n).
    - stdout carrega SOMENTE mensagens do protocolo (JSON puro).
    - Logs e diagnosticos vao para stderr, para nao poluir o canal.
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MCP.Transport in 'MCP.Transport.pas',
  MCP.Tools in 'MCP.Tools.pas',
  MCP.Server in 'MCP.Server.pas',
  Clientes.Repositorio in 'Clientes.Repositorio.pas';

begin
  try
    var Servidor := TMCPServer.Create;
    try
      Servidor.Executar;
    finally
      Servidor.Free;
    end;
  except
    on E: Exception do
    begin
      // Erros fatais vao para stderr (o canal stdout e reservado ao JSON-RPC).
      Writeln(ErrOutput, Format('[DelphiMCP] Erro fatal: %s: %s',
        [E.ClassName, E.Message]));
      ExitCode := 1;
    end;
  end;
end.
