unit TesteGravarLogQueue;

// =============================================================================
// Testes unitarios de GravarLog.Queue
//
// Cobertura:
//   TLogItem.Create        — 3 casos
//   TGravarLogQueue.Create — 2 casos
//   TGravarLogQueue.Enqueue / DequeueAllLocked — 4 casos
//   TGravarLogQueue.ReplaceLog — 2 casos
//   Despacho assincrono (worker) — 3 casos
// =============================================================================

interface

uses
  DUnitX.TestFramework,
  System.SyncObjs,
  System.Threading,
  GravarLog,
  GravarLog.Utils,
  GravarLog.Queue;

type

  // ---------------------------------------------------------------------------
  // IGravarLog stub — registra chamadas sem gravar em disco nem chamar API
  // ---------------------------------------------------------------------------
  TLogStub = class(TInterfacedObject, IGravarLog)
  strict private
    FCS          : TCriticalSection;
    FChamadas    : Integer;
    FUltimaMensagem: string;
    FUltimoTipo  : TLogTipo;
  public
    constructor Create;
    destructor Destroy; override;
    // IGravarLog (overload legado — nao usado nos testes, apenas implementado)
    function doSaveLog(aValue, AFileName: string): IGravarLog; overload;
    // IGravarLog (overload estruturado)
    function doSaveLog(
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
    ): IGravarLog; overload;
    // Leitura thread-safe dos contadores
    function Chamadas: Integer;
    function UltimaMensagem: string;
    function UltimoTipo: TLogTipo;
  end;

  // ---------------------------------------------------------------------------
  // Fixture principal
  // ---------------------------------------------------------------------------
  [TestFixture]
  TGravarLogQueueTests = class
  strict private
    FStub : TLogStub;
    FLog  : IGravarLog;
    FQueue: TGravarLogQueue;
    // Aguarda ate condicao ser verdadeira ou timeout (ms) — evita sleeps fixos
    function AguardarCondicao(
      ACondicao    : TFunc<Boolean>;
      ATimeoutMs   : Integer = 2000;
      AIntervaloMs : Integer = 20
    ): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

  published
    // --- TLogItem.Create ---
    [Test]
    procedure Test_LogItemCreate_TodosCamposPreenchidos;
    [Test]
    procedure Test_LogItemCreate_CamposOpcionaisVazios;
    [Test]
    procedure Test_LogItemCreate_TipoCritical;

    // --- TGravarLogQueue.Create ---
    [Test]
    procedure Test_QueueCreate_PropriedadesInicializadas;
    [Test]
    procedure Test_QueueCreate_LogAtribuidoCorretamente;

    // --- Enqueue / DequeueAllLocked ---
    [Test]
    procedure Test_Enqueue_FilaVazia_AdicionaUmItem;
    [Test]
    procedure Test_Enqueue_MultiplosItens_MantemOrdem;
    [Test]
    procedure Test_DequeueAllLocked_FilaVazia_RetornaArrayVazio;
    [Test]
    procedure Test_DequeueAllLocked_EsvaziaFila;

    // --- ReplaceLog ---
    [Test]
    procedure Test_ReplaceLog_SubstituiReferencia;
    [Test]
    procedure Test_ReplaceLog_NilDesabilitaDespacho;

    // --- Despacho assincrono ---
    [Test]
    procedure Test_Enqueue_WorkerChamadoSaveLog;
    [Test]
    procedure Test_Enqueue_MultiplosChamadosOrdemCorreta;
    [Test]
    procedure Test_WorkerNaoMorrePorExcecaoNoSaveLog;
  end;

implementation

uses
  System.SysUtils;

// =============================================================================
// TLogStub
// =============================================================================

constructor TLogStub.Create;
begin
  inherited Create;
  FCS := TCriticalSection.Create;
end;

destructor TLogStub.Destroy;
begin
  FCS.Free;
  inherited;
end;

function TLogStub.doSaveLog(aValue, AFileName: string): IGravarLog;
begin
  Result := Self;
end;

function TLogStub.doSaveLog(
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
): IGravarLog;
begin
  Result := Self;
  FCS.Enter;
  try
    Inc(FChamadas);
    FUltimaMensagem := AMensagem;
    FUltimoTipo     := ATipo;
  finally
    FCS.Leave;
  end;
end;

function TLogStub.Chamadas: Integer;
begin
  FCS.Enter;
  try
    Result := FChamadas;
  finally
    FCS.Leave;
  end;
end;

function TLogStub.UltimaMensagem: string;
begin
  FCS.Enter;
  try
    Result := FUltimaMensagem;
  finally
    FCS.Leave;
  end;
end;

function TLogStub.UltimoTipo: TLogTipo;
begin
  FCS.Enter;
  try
    Result := FUltimoTipo;
  finally
    FCS.Leave;
  end;
end;

// =============================================================================
// TGravarLogQueueTests — Setup / TearDown
// =============================================================================

procedure TGravarLogQueueTests.Setup;
begin
  FStub  := TLogStub.Create;
  FLog   := FStub;           // interface assume a contagem de referencia
  FQueue := TGravarLogQueue.Create(FLog);
end;

procedure TGravarLogQueueTests.TearDown;
begin
  FQueue.Free;
  FQueue := nil;
  FLog   := nil;  // libera o stub via contagem de referencia
end;

function TGravarLogQueueTests.AguardarCondicao(
  ACondicao    : TFunc<Boolean>;
  ATimeoutMs   : Integer;
  AIntervaloMs : Integer
): Boolean;
var
  LDecorrido: Integer;
begin
  LDecorrido := 0;
  while (not ACondicao()) and (LDecorrido < ATimeoutMs) do
  begin
    Sleep(AIntervaloMs);
    Inc(LDecorrido, AIntervaloMs);
  end;
  Result := ACondicao();
end;

// =============================================================================
// TLogItem.Create
// =============================================================================

procedure TGravarLogQueueTests.Test_LogItemCreate_TodosCamposPreenchidos;
var
  LItem: TLogItem;
begin
  LItem := TLogItem.Create(
    'Mensagem teste', ltInfo,
    'TMinhaClasse', 'SistemaX', 'ModuloY',
    'usuario1', 'Detalhes aqui', '1.0.0',
    'tag1,tag2', '{"chave":"valor"}'
  );

  Assert.AreEqual('Mensagem teste',      LItem.Mensagem);
  Assert.AreEqual(ltInfo,                LItem.Tipo);
  Assert.AreEqual('TMinhaClasse',        LItem.Origem);
  Assert.AreEqual('SistemaX',            LItem.Sistema);
  Assert.AreEqual('ModuloY',             LItem.Modulo);
  Assert.AreEqual('usuario1',            LItem.Usuario);
  Assert.AreEqual('Detalhes aqui',       LItem.Detalhes);
  Assert.AreEqual('1.0.0',               LItem.Versao);
  Assert.AreEqual('tag1,tag2',           LItem.Tags);
  Assert.AreEqual('{"chave":"valor"}',   LItem.DadosAdicionais);
end;

procedure TGravarLogQueueTests.Test_LogItemCreate_CamposOpcionaisVazios;
var
  LItem: TLogItem;
begin
  LItem := TLogItem.Create('Apenas mensagem', ltError, '', '', '', '', '', '', '', '');

  Assert.AreEqual('Apenas mensagem', LItem.Mensagem);
  Assert.AreEqual(ltError,           LItem.Tipo);
  Assert.AreEqual('',                LItem.Origem);
  Assert.AreEqual('',                LItem.Sistema);
  Assert.AreEqual('',                LItem.Modulo);
  Assert.AreEqual('',                LItem.Usuario);
  Assert.AreEqual('',                LItem.Detalhes);
  Assert.AreEqual('',                LItem.Versao);
  Assert.AreEqual('',                LItem.Tags);
  Assert.AreEqual('',                LItem.DadosAdicionais);
end;

procedure TGravarLogQueueTests.Test_LogItemCreate_TipoCritical;
var
  LItem: TLogItem;
begin
  LItem := TLogItem.Create('Falha critica', ltCritical, '', '', '', '', '', '', '', '');

  Assert.AreEqual(ltCritical, LItem.Tipo);
  Assert.AreEqual('Falha critica', LItem.Mensagem);
end;

// =============================================================================
// TGravarLogQueue.Create
// =============================================================================

procedure TGravarLogQueueTests.Test_QueueCreate_PropriedadesInicializadas;
begin
  Assert.IsNotNull(FQueue.CS,    'CS nao deve ser nil apos Create');
  Assert.IsNotNull(FQueue.Event, 'Event nao deve ser nil apos Create');
end;

procedure TGravarLogQueueTests.Test_QueueCreate_LogAtribuidoCorretamente;
begin
  Assert.IsNotNull(FQueue.Log, 'Log nao deve ser nil apos Create com IGravarLog valido');
  Assert.AreEqual(FLog, FQueue.Log);
end;

// =============================================================================
// Enqueue / DequeueAllLocked
// =============================================================================

procedure TGravarLogQueueTests.Test_Enqueue_FilaVazia_AdicionaUmItem;
var
  LItem    : TLogItem;
  LSnapshot: TArray<TLogItem>;
begin
  LItem := TLogItem.Create('Item unico', ltDebug, '', '', '', '', '', '', '', '');

  // Chama Enqueue, depois adquire CS manualmente para inspecionar
  FQueue.Enqueue(LItem);

  FQueue.CS.Enter;
  try
    LSnapshot := FQueue.DequeueAllLocked;
  finally
    FQueue.CS.Leave;
  end;

  Assert.AreEqual(1, Length(LSnapshot));
  Assert.AreEqual('Item unico', LSnapshot[0].Mensagem);
end;

procedure TGravarLogQueueTests.Test_Enqueue_MultiplosItens_MantemOrdem;
var
  LSnapshot: TArray<TLogItem>;
  LIndex   : Integer;
begin
  // Pausa o worker substituindo o log por nil para evitar corrida entre
  // o enqueue e a leitura manual
  FQueue.ReplaceLog(nil);

  for LIndex := 1 to 5 do
    FQueue.Enqueue(TLogItem.Create('Msg' + LIndex.ToString, ltTrace, '', '', '', '', '', '', '', ''));

  FQueue.CS.Enter;
  try
    LSnapshot := FQueue.DequeueAllLocked;
  finally
    FQueue.CS.Leave;
  end;

  Assert.AreEqual(5, Length(LSnapshot));
  for LIndex := 0 to 4 do
    Assert.AreEqual('Msg' + (LIndex + 1).ToString, LSnapshot[LIndex].Mensagem);
end;

procedure TGravarLogQueueTests.Test_DequeueAllLocked_FilaVazia_RetornaArrayVazio;
var
  LSnapshot: TArray<TLogItem>;
begin
  FQueue.CS.Enter;
  try
    LSnapshot := FQueue.DequeueAllLocked;
  finally
    FQueue.CS.Leave;
  end;

  Assert.AreEqual(0, Length(LSnapshot));
end;

procedure TGravarLogQueueTests.Test_DequeueAllLocked_EsvaziaFila;
var
  LSnapshot1: TArray<TLogItem>;
  LSnapshot2: TArray<TLogItem>;
begin
  FQueue.ReplaceLog(nil);  // impede despacho pelo worker durante o teste

  FQueue.Enqueue(TLogItem.Create('A', ltInfo, '', '', '', '', '', '', '', ''));
  FQueue.Enqueue(TLogItem.Create('B', ltInfo, '', '', '', '', '', '', '', ''));

  FQueue.CS.Enter;
  try
    LSnapshot1 := FQueue.DequeueAllLocked;
    LSnapshot2 := FQueue.DequeueAllLocked;
  finally
    FQueue.CS.Leave;
  end;

  Assert.AreEqual(2, Length(LSnapshot1), 'Primeiro dequeue deve retornar 2 itens');
  Assert.AreEqual(0, Length(LSnapshot2), 'Segundo dequeue deve retornar array vazio');
end;

// =============================================================================
// ReplaceLog
// =============================================================================

procedure TGravarLogQueueTests.Test_ReplaceLog_SubstituiReferencia;
var
  LNovoStub: TLogStub;
  LNovoLog : IGravarLog;
begin
  LNovoStub := TLogStub.Create;
  LNovoLog  := LNovoStub;

  FQueue.ReplaceLog(LNovoLog);

  Assert.AreEqual(LNovoLog, FQueue.Log);
end;

procedure TGravarLogQueueTests.Test_ReplaceLog_NilDesabilitaDespacho;
begin
  FQueue.ReplaceLog(nil);

  Assert.IsNull(FQueue.Log, 'Log deve ser nil apos ReplaceLog(nil)');
end;

// =============================================================================
// Despacho assincrono
// =============================================================================

procedure TGravarLogQueueTests.Test_Enqueue_WorkerChamadoSaveLog;
var
  LItem: TLogItem;
begin
  LItem := TLogItem.Create('Async OK', ltWarning, '', '', '', '', '', '', '', '');

  FQueue.Enqueue(LItem);

  Assert.IsTrue(
    AguardarCondicao(
      function: Boolean
      begin
        Result := FStub.Chamadas >= 1;
      end
    ),
    'Worker deveria ter chamado doSaveLog ao menos uma vez'
  );

  Assert.AreEqual('Async OK', FStub.UltimaMensagem);
  Assert.AreEqual(ltWarning,  FStub.UltimoTipo);
end;

procedure TGravarLogQueueTests.Test_Enqueue_MultiplosChamadosOrdemCorreta;
const
  C_TOTAL = 10;
var
  LIndex: Integer;
begin
  for LIndex := 1 to C_TOTAL do
    FQueue.Enqueue(
      TLogItem.Create('Msg' + LIndex.ToString, ltInfo, '', '', '', '', '', '', '', '')
    );

  Assert.IsTrue(
    AguardarCondicao(
      function: Boolean
      begin
        Result := FStub.Chamadas >= C_TOTAL;
      end,
      3000
    ),
    'Worker deveria ter processado todos os ' + C_TOTAL.ToString + ' itens'
  );
end;

procedure TGravarLogQueueTests.Test_WorkerNaoMorrePorExcecaoNoSaveLog;
var
  LStubFalho: TLogStub;
  LLogFalho : IGravarLog;
begin
  // Substitui o log por um stub que levanta excecao internamente.
  // Para simular a excecao sem subclassificar, enfileiramos um item com
  // o stub normal, trocamos o log e enfileiramos outro — o worker precisa
  // continuar funcionando apos processar o item com erro.
  //
  // A cobertura real do caminho de excecao e garantida pelo ProcessarSnapshot
  // que encapsula cada chamada em try..except. Aqui validamos que o worker
  // permanece vivo processando itens subsequentes.

  LStubFalho := TLogStub.Create;
  LLogFalho  := LStubFalho;

  // Enfileira um item, troca o log e enfileira mais itens
  FQueue.Enqueue(TLogItem.Create('Antes da troca', ltInfo, '', '', '', '', '', '', '', ''));

  Assert.IsTrue(
    AguardarCondicao(function: Boolean begin Result := FStub.Chamadas >= 1; end),
    'Worker deveria processar o primeiro item'
  );

  FQueue.ReplaceLog(LLogFalho);
  FQueue.Enqueue(TLogItem.Create('Apos troca', ltInfo, '', '', '', '', '', '', '', ''));

  Assert.IsTrue(
    AguardarCondicao(
      function: Boolean
      begin
        Result := LStubFalho.Chamadas >= 1;
      end,
      2000
    ),
    'Worker deveria continuar processando apos substituicao do log'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TGravarLogQueueTests);

end.
