unit GravarLog.Manager;

interface

uses
  GravarLog,
  GravarLog.Utils;

type
  TGravarLogManager = class
  private
    FNivelMinimo        : TNivelLog;
    FLog                : IGravarLog;
    constructor Create;
    class var FInstance : TGravarLogManager;
  public
    class function GetInstance: TGravarLogManager;
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

{ TGravarLogManager }

constructor TGravarLogManager.Create;
begin
  FNivelMinimo := nlNormal;
  FLog         := TGravarLog.New;
end;

class function TGravarLogManager.GetInstance: TGravarLogManager;
begin
  if not Assigned(FInstance) then
    FInstance := TGravarLogManager.Create;
  Result := FInstance;
end;

function TGravarLogManager.ConfigurarNivel(ANivel: TNivelLog): TGravarLogManager;
begin
  FNivelMinimo := ANivel;
  Result       := Self;
end;

function TGravarLogManager.ConfigurarServidor(const AURL: string): TGravarLogManager;
begin
  FLog   := TGravarLog.New(AURL);
  Result := Self;
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
begin
  Result := Self;
  if Ord(ANivel) > Ord(FNivelMinimo) then
    Exit;
  FLog.doSaveLog(
    AMensagem, ATipo, AOrigem, ASistema,
    AModulo, AUsuario, ADetalhes, AVersao,
    ATags, ADadosAdicionais
  );
end;

initialization
  TGravarLogManager.FInstance := nil;

finalization
  TGravarLogManager.FInstance.Free;
  TGravarLogManager.FInstance := nil;

end.
