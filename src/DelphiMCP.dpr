program DelphiMCP;

{
  DelphiMCP - Servidor MCP (Model Context Protocol) escrito em Delphi.

  Usa a biblioteca MCPConnect (https://github.com/delphi-blocks/MCPConnect),
  que cuida de todo o protocolo: JSON-RPC 2.0, initialize, tools/list,
  tools/call e o transporte stdio. Aqui so registramos a classe de
  ferramentas (Clientes.Ferramentas) e iniciamos o servidor.

  Regra importante do transporte stdio: stdout carrega SOMENTE mensagens
  do protocolo. Logs e diagnosticos vao para stderr.
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MCPConnect.Transport.Stdio,
  MCPConnect.Configuration.MCP,
  // Registra os metodos MCP padrao (initialize, tools/*, ...) na inicializacao.
  MCPConnect.MCP.Server.Api,
  Clientes.Repositorio in 'Clientes.Repositorio.pas',
  Clientes.Ferramentas in 'Clientes.Ferramentas.pas';

begin
  try
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

      // Le stdin e responde em stdout ate o host fechar a conexao.
      Servidor.StartServerAndWait;
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
