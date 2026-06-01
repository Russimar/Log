unit GravarLog.Queue;

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  GravarLog,
  GravarLog.Utils;

type
  TLogItem = record
    Mensagem       : string;
    Tipo           : TLogTipo;
    Origem         : string;
    Sistema        : string;
    Modulo         : string;
    Usuario        : string;
    Detalhes       : string;
    Versao         : string;
    Tags           : string;
    DadosAdicionais: string;
    class function Create(
      const AMensagem        : string;
      const ATipo            : TLogTipo;
      const AOrigem          : string;
      const ASistema         : string;
      const AModulo          : string;
      const AUsuario         : string;
      const ADetalhes        : string;
      const AVersao          : string;
      const ATags            : string;
      const ADadosAdicionais : string
    ): TLogItem; static;
  end;

  TGravarLogQueue = class;

  TGravarLogWorker = class(TThread)
  strict private
    FQueue: TGravarLogQueue;
    procedure ProcessarSnapshot(ALog: IGravarLog; const ASnapshot: TArray<TLogItem>);
  protected
    procedure Execute; override;
  public
    constructor Create(AQueue: TGravarLogQueue);
  end;

  TGravarLogQueue = class
  strict private
    FQueue : TQueue<TLogItem>;
    FCS    : TCriticalSection;
    FEvent : TEvent;
    FWorker: TGravarLogWorker;
    FLog   : IGravarLog;
  public
    constructor Create(ALog: IGravarLog);
    destructor Destroy; override;
    procedure Enqueue(const AItem: TLogItem);
    function DequeueAllLocked: TArray<TLogItem>;
    procedure ReplaceLog(ANovoLog: IGravarLog);
    property CS   : TCriticalSection read FCS;
    property Event: TEvent           read FEvent;
    property Log  : IGravarLog       read FLog;
  end;

implementation

uses
  System.SysUtils;

{ TLogItem }

class function TLogItem.Create(
  const AMensagem        : string;
  const ATipo            : TLogTipo;
  const AOrigem          : string;
  const ASistema         : string;
  const AModulo          : string;
  const AUsuario         : string;
  const ADetalhes        : string;
  const AVersao          : string;
  const ATags            : string;
  const ADadosAdicionais : string
): TLogItem;
begin
  Result.Mensagem        := AMensagem;
  Result.Tipo            := ATipo;
  Result.Origem          := AOrigem;
  Result.Sistema         := ASistema;
  Result.Modulo          := AModulo;
  Result.Usuario         := AUsuario;
  Result.Detalhes        := ADetalhes;
  Result.Versao          := AVersao;
  Result.Tags            := ATags;
  Result.DadosAdicionais := ADadosAdicionais;
end;

{ TGravarLogWorker }

constructor TGravarLogWorker.Create(AQueue: TGravarLogQueue);
begin
  inherited Create(True);
  FQueue           := AQueue;
  FreeOnTerminate  := False;
end;

procedure TGravarLogWorker.Execute;
const
  C_WORKER_TIMEOUT_MS = 500;
var
  LLog     : IGravarLog;
  LSnapshot: TArray<TLogItem>;
begin
  while not Terminated do
  begin
    FQueue.Event.WaitFor(C_WORKER_TIMEOUT_MS);

    FQueue.CS.Enter;
    try
      LLog      := FQueue.Log;
      LSnapshot := FQueue.DequeueAllLocked;
    finally
      FQueue.CS.Leave;
    end;

    if Assigned(LLog) then
      ProcessarSnapshot(LLog, LSnapshot);
  end;

  // Drenagem final após Terminated = True
  FQueue.CS.Enter;
  try
    LLog      := FQueue.Log;
    LSnapshot := FQueue.DequeueAllLocked;
  finally
    FQueue.CS.Leave;
  end;

  if Assigned(LLog) then
    ProcessarSnapshot(LLog, LSnapshot);
end;

procedure TGravarLogWorker.ProcessarSnapshot(ALog: IGravarLog; const ASnapshot: TArray<TLogItem>);
var
  LItem: TLogItem;
begin
  for LItem in ASnapshot do
  begin
    try
      ALog.doSaveLog(
        LItem.Mensagem, LItem.Tipo,    LItem.Origem,  LItem.Sistema,
        LItem.Modulo,   LItem.Usuario, LItem.Detalhes, LItem.Versao,
        LItem.Tags,     LItem.DadosAdicionais
      );
    except
      // log não pode propagar exceção — worker nunca deve morrer por falha de I/O
    end;
  end;
end;

{ TGravarLogQueue }

constructor TGravarLogQueue.Create(ALog: IGravarLog);
begin
  inherited Create;
  FLog    := ALog;
  FCS     := TCriticalSection.Create;
  FEvent  := TEvent.Create(nil, False, False, '');
  FQueue  := TQueue<TLogItem>.Create;
  FWorker := TGravarLogWorker.Create(Self);
  FWorker.Start;
end;

destructor TGravarLogQueue.Destroy;
begin
  FWorker.Terminate;
  FEvent.SetEvent;
  FWorker.WaitFor;
  FWorker.Free;
  FQueue.Free;
  FCS.Free;
  FEvent.Free;
  inherited;
end;

procedure TGravarLogQueue.Enqueue(const AItem: TLogItem);
begin
  FCS.Enter;
  try
    FQueue.Enqueue(AItem);
  finally
    FCS.Leave;
  end;
  FEvent.SetEvent;
end;

function TGravarLogQueue.DequeueAllLocked: TArray<TLogItem>;
var
  LCount: Integer;
begin
  LCount := 0;
  SetLength(Result, FQueue.Count);
  while FQueue.Count > 0 do
  begin
    Result[LCount] := FQueue.Dequeue;
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

procedure TGravarLogQueue.ReplaceLog(ANovoLog: IGravarLog);
begin
  FCS.Enter;
  try
    FLog := ANovoLog;
  finally
    FCS.Leave;
  end;
end;

end.
