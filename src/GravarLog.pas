unit GravarLog;

// ============================================================
// CONFIGURAÇÃO DE COMPORTAMENTO
// ------------------------------------------------------------
// Descomente para DESATIVAR a gravação em arquivo local:
// {$DEFINE DESATIVAR_LOG_LOCAL}
//
// Descomente para ATIVAR o envio à API REST:
// {$DEFINE ATIVAR_LOG_NUVEM}
// ============================================================

interface

uses
  System.SysUtils
  {$IFDEF ATIVAR_LOG_NUVEM}
  , System.Classes
  , System.Net.HttpClient
  , System.Net.Mime
  , System.JSON
  , System.Threading
  , GravarLog.Auth
  {$ENDIF}
  ;

type
  TLogTipo = (
    ltTrace,
    ltDebug,
    ltInfo,
    ltWarning,
    ltError,
    ltCritical,
    ltFatal,
    ltSecurity,
    ltAudit,
    ltIntegration
  );

  TLogTipoHelper = record helper for TLogTipo
    function ToString: string;
  end;

  IGravarLog = Interface
    ['{4E3DB66D-16FD-45FB-9CC4-1B5A919854A4}']
    function doSaveLog(aValue, AFileName: String): IGravarLog; Overload;
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
    ): IGravarLog; Overload;
  End;

  TGravarLog = class(TInterfacedObject, IGravarLog)
  private
    FPath      : String;
    FServerURL : String;
    {$IFDEF ATIVAR_LOG_NUVEM}
    FBearerToken: string;
    function MontarJson(
      const ATipo, AMensagem, AOrigem, ASistema,
            AModulo, AUsuario, ADetalhes, AVersao,
            ATags, ADadosAdicionais: string
    ): string;
    procedure EnviarParaAPI(const AJson: string);
    {$ENDIF}
  public
    class function New(const AServerURL: string = 'http://localhost:8080'): IGravarLog;
    constructor Create(const AServerURL: string = 'http://localhost:8080');
    destructor Destroy; override;
    property Path: String read FPath write FPath;
    function doSaveLog(aValue, AFileName: String): IGravarLog; Overload;
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
    ): IGravarLog; Overload;
  end;

implementation

uses
  System.Net.URLClient;	

{ TLogTipoHelper }

function TLogTipoHelper.ToString: string;
const
  MAP: array[TLogTipo] of string = (
    'trace', 'debug', 'info', 'warning', 'error',
    'critical', 'fatal', 'security', 'audit', 'integration'
  );
begin
  Result := MAP[Self];
end;

{ TGravarLog }

constructor TGravarLog.Create(const AServerURL: string = 'http://localhost:8080');
begin
  Path       := ExtractFilePath(ParamStr(0));
  FServerURL := AServerURL.TrimRight(['/']);
  {$IFDEF ATIVAR_LOG_NUVEM}
  FBearerToken := TGravarLogAuth.GerarBearer;
  {$ENDIF}
end;

destructor TGravarLog.Destroy;
begin
  inherited;
end;

class function TGravarLog.New(const AServerURL: string = 'http://localhost:8080'): IGravarLog;
begin
  Result := Self.Create(AServerURL);
end;

function TGravarLog.doSaveLog(aValue, AFileName: String): IGravarLog;
var
  Caminho: String;
  Log: TextFile;
begin
  Result := Self;
  Caminho := FPath + '/Log';
  if not DirectoryExists(Caminho) then
  begin
    try
      ForceDirectories(Caminho);
    except
      Exit;
    end;
  end;
  Caminho := Caminho + '/' + AFileName;
  AssignFile(Log, Caminho);
  if not FileExists(Caminho) then
    Rewrite(Log)
  else
    Append(Log);
  Writeln(Log, 'Mensagem: ' + FormatDateTime('dd/mm/yyyy hh:nn', now) + ' ' + aValue);
  CloseFile(Log);
  {$IFDEF CONSOLE}
    Writeln('Mensagem: ' + FormatDateTime('dd/mm/yyyy hh:nn', now) + ' ' + aValue);
  {$ENDIF}
end;

function TGravarLog.doSaveLog(
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
): IGravarLog;
{$IFDEF ATIVAR_LOG_NUVEM}
var
  LJson: string;
{$ENDIF}
begin
  Result := Self;

  {$IFNDEF DESATIVAR_LOG_LOCAL}
  var Caminho: String;
  var Log: TextFile;
  Caminho := FPath + '/Log';
  if not DirectoryExists(Caminho) then
  begin
    try
      ForceDirectories(Caminho);
    except
      // falha silenciosa: se não puder criar pasta, pula o log local
    end;
  end;
  Caminho := Caminho + '/' + StringReplace(ExtractFileName(ParamStr(0)), '.exe', '.txt', [rfReplaceAll]);
  Caminho := StringReplace(Caminho, '.txt', FormatDateTime('ddmmyyyy', now) + '.txt', [rfReplaceAll]);
  AssignFile(Log, Caminho);
  if not FileExists(Caminho) then
    Rewrite(Log)
  else
    Append(Log);
  Writeln(Log, 'Mensagem: ' + FormatDateTime('dd/mm/yyyy hh:nn:ss.zzz', now) + ' [' + ATipo.ToString + '] ' + AMensagem);
  CloseFile(Log);
  {$IFDEF CONSOLE}
    Writeln('Mensagem: ' + FormatDateTime('dd/mm/yyyy hh:nn:ss.zzz', now) + ' [' + ATipo.ToString + '] ' + AMensagem);
  {$ENDIF}
  {$ENDIF}

  {$IFDEF ATIVAR_LOG_NUVEM}
  if not FServerURL.IsEmpty then
  begin
    LJson := MontarJson(
      ATipo.ToString, AMensagem, AOrigem, ASistema,
      AModulo, AUsuario, ADetalhes, AVersao,
      ATags, ADadosAdicionais
    );
    TTask.Run(
      procedure
      begin
        try
          EnviarParaAPI(LJson);
        except
          // fire-and-forget: falhas de rede nunca propagam
        end;
      end
    );
  end;
  {$ENDIF}
end;

{$IFDEF ATIVAR_LOG_NUVEM}

function TGravarLog.MontarJson(
  const ATipo, AMensagem, AOrigem, ASistema,
        AModulo, AUsuario, ADetalhes, AVersao,
        ATags, ADadosAdicionais: string
): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('tipo', ATipo);
    LObj.AddPair('mensagem', AMensagem);
    if not AOrigem.IsEmpty        then LObj.AddPair('origem',          AOrigem);
    if not ASistema.IsEmpty       then LObj.AddPair('sistema',         ASistema);
    if not AModulo.IsEmpty        then LObj.AddPair('modulo',          AModulo);
    if not AUsuario.IsEmpty       then LObj.AddPair('usuario',         AUsuario);
    if not ADetalhes.IsEmpty      then LObj.AddPair('detalhes',        ADetalhes);
    if not AVersao.IsEmpty        then LObj.AddPair('versao',          AVersao);
    if not ATags.IsEmpty          then LObj.AddPair('tags',            ATags);
    if not ADadosAdicionais.IsEmpty then LObj.AddPair('dadosAdicionais', ADadosAdicionais);
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

procedure TGravarLog.EnviarParaAPI(const AJson: string);
const
  TIMEOUT_MS = 5000;
var
  LClient  : THTTPClient;
  LContent : TStringStream;
  LHeaders : TNetHeaders;
begin
  LClient  := THTTPClient.Create;
  LContent := TStringStream.Create(AJson, TEncoding.UTF8);
  try
    LClient.ConnectionTimeout := TIMEOUT_MS;
    LClient.ResponseTimeout   := TIMEOUT_MS;
    LHeaders := [TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8')];
    if not FBearerToken.IsEmpty then
      LHeaders := LHeaders + [TNameValuePair.Create('Authorization', 'Bearer ' + FBearerToken)];
    LClient.Post(FServerURL + '/log', LContent, nil, LHeaders);
  finally
    LContent.Free;
    LClient.Free;
  end;
end;

{$ENDIF}

end.
