unit GravarLog.Manager;

interface

uses
  GravarLog,
  GravarLog.Queue,
  GravarLog.Utils;

type
  TGravarLogManager = class
  private
    FNivelMinimo        : TNivelLog;
    FLog                : IGravarLog;
    FQueue              : TGravarLogQueue;
    constructor Create;
    class var FInstance : TGravarLogManager;
  public
    class function GetInstance: TGravarLogManager;
    destructor Destroy; override;
    function ConfigurarNivel(ANivel: TNivelLog): TGravarLogManager;
    function ConfigurarServidor(const AURL: string): TGravarLogManager;
    function doSaveLog(
      const ANivel           : TNivelLog;
      const AMensagem        : string;
      const ATipo            : TLogTipo = ltError;
      const AOrigem          : string = '';
      const ASistema         : string = '';
      const AModulo          : string = '';
      const AUsuario         : string = '';
      const ADetalhes        : string = '';
      const AVersao          : string = '';
      const ATags            : string = '';
      const ADadosAdicionais : string = ''
    ): TGravarLogManager;
  published
    property NivelMinimo: TNivelLog read FNivelMinimo;
  end;

implementation

uses
  System.SyncObjs;

var
  GLock : TCriticalSection;

{ TGravarLogManager }

constructor TGravarLogManager.Create;
begin
  FNivelMinimo := nlNormal;
  FLog         := TGravarLog.New;
  FQueue       := TGravarLogQueue.Create(FLog);
end;

destructor TGravarLogManager.Destroy;
begin
  FQueue.Free;
  inherited;
end;

class function TGravarLogManager.GetInstance: TGravarLogManager;
begin
  // Double-checked locking: o teste externo evita o custo do lock no caminho
  // comum (instancia ja criada); o teste interno garante criacao unica quando
  // duas ou mais threads chegam juntas na primeira chamada.
  if not Assigned(FInstance) then
  begin
    GLock.Enter;
    try
      if not Assigned(FInstance) then
        FInstance := TGravarLogManager.Create;
    finally
      GLock.Leave;
    end;
  end;
  Result := FInstance;
end;

function TGravarLogManager.ConfigurarNivel(ANivel: TNivelLog): TGravarLogManager;
begin
  Result := Self;
  GLock.Enter;
  try
    FNivelMinimo := ANivel;
  finally
    GLock.Leave;
  end;
end;

function TGravarLogManager.ConfigurarServidor(const AURL: string): TGravarLogManager;
begin
  Result := Self;
  // FLog e uma interface lida por doSaveLog a partir de outras threads; a
  // troca precisa ser atomica em relacao a esses leitores.
  GLock.Enter;
  try
    FLog := TGravarLog.New(AURL);
    FQueue.ReplaceLog(FLog);
  finally
    GLock.Leave;
  end;
end;

function TGravarLogManager.doSaveLog(
  const ANivel           : TNivelLog;
  const AMensagem        : string;
  const ATipo            : TLogTipo = ltError;
  const AOrigem          : string = '';
  const ASistema         : string = '';
  const AModulo          : string = '';
  const AUsuario         : string = '';
  const ADetalhes        : string = '';
  const AVersao          : string = '';
  const ATags            : string = '';
  const ADadosAdicionais : string = ''
): TGravarLogManager;
var
  LNivelMinimo : TNivelLog;
begin
  Result := Self;
  GLock.Enter;
  try
    LNivelMinimo := FNivelMinimo;
  finally
    GLock.Leave;
  end;
  if Ord(ANivel) > Ord(LNivelMinimo) then
    Exit;
  FQueue.Enqueue(
    TLogItem.Create(
      AMensagem, ATipo, AOrigem, ASistema,
      AModulo, AUsuario, ADetalhes, AVersao,
      ATags, ADadosAdicionais
    )
  );
end;

initialization
  GLock := TCriticalSection.Create;
  TGravarLogManager.FInstance := nil;

finalization
  TGravarLogManager.FInstance.Free;
  TGravarLogManager.FInstance := nil;
  GLock.Free;

end.
