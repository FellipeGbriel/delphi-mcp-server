unit Clientes.Repositorio;

{
  Repositorio de clientes em memoria.

  Representa o "sistema de negocio" ja existente em Delphi. Num caso real,
  aqui estariam consultas FireDAC a um banco, regras de negocio, servicos
  REST internos, etc. O servidor MCP apenas expoe essas operacoes como
  ferramentas para a IA.
}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TCliente = record
    Id: Integer;
    Nome: string;
    Email: string;
    Cidade: string;
  end;

  TClienteRepositorio = class
  private
    FClientes: TList<TCliente>;
    FProximoId: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function Listar: TArray<TCliente>;
    function Buscar(const ATermo: string): TArray<TCliente>;
    function Criar(const ANome, AEmail, ACidade: string): TCliente;
    function Total: Integer;
  end;

implementation

uses
  System.Character;

constructor TClienteRepositorio.Create;
begin
  inherited Create;
  FClientes := TList<TCliente>.Create;
  FProximoId := 1;

  // Dados de exemplo (seed).
  Criar('Maria Oliveira', 'maria.oliveira@exemplo.com.br', 'Sao Paulo');
  Criar('Joao Santos', 'joao.santos@exemplo.com.br', 'Belo Horizonte');
  Criar('Ana Costa', 'ana.costa@exemplo.com.br', 'Curitiba');
  Criar('Carlos Pereira', 'carlos.pereira@exemplo.com.br', 'Porto Alegre');
end;

destructor TClienteRepositorio.Destroy;
begin
  FClientes.Free;
  inherited;
end;

function TClienteRepositorio.Listar: TArray<TCliente>;
begin
  Result := FClientes.ToArray;
end;

function TClienteRepositorio.Buscar(const ATermo: string): TArray<TCliente>;
var
  Termo: string;
  Cliente: TCliente;
  Encontrados: TList<TCliente>;
begin
  Termo := ATermo.Trim.ToLower;
  Encontrados := TList<TCliente>.Create;
  try
    for Cliente in FClientes do
      if (Termo = '') or Cliente.Nome.ToLower.Contains(Termo)
        or Cliente.Cidade.ToLower.Contains(Termo)
        or Cliente.Email.ToLower.Contains(Termo) then
        Encontrados.Add(Cliente);
    Result := Encontrados.ToArray;
  finally
    Encontrados.Free;
  end;
end;

function TClienteRepositorio.Criar(const ANome, AEmail, ACidade: string): TCliente;
var
  Cliente: TCliente;
begin
  Cliente.Id := FProximoId;
  Cliente.Nome := ANome;
  Cliente.Email := AEmail;
  Cliente.Cidade := ACidade;
  Inc(FProximoId);
  FClientes.Add(Cliente);
  Result := Cliente;
end;

function TClienteRepositorio.Total: Integer;
begin
  Result := FClientes.Count;
end;

end.
