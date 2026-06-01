unit GravarLog.Utils;

interface

type
  TNivelLog = (nlNormal, nlAlto, nlExtremo);

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

  TNivelLogHelper = record helper for TNivelLog
    function ToInt: Integer;
    class function FromInt(AValue: Integer): TNivelLog; static;
    function ToLabel: string;
  end;

var
  NivelLog: TNivelLog;

implementation

{ TNivelLogHelper }

function TNivelLogHelper.ToInt: Integer;
begin
  Result := Ord(Self);
end;

class function TNivelLogHelper.FromInt(AValue: Integer): TNivelLog;
begin
  if AValue in [Ord(nlNormal)..Ord(nlExtremo)] then
    Result := TNivelLog(AValue)
  else
    Result := nlNormal;
end;

function TNivelLogHelper.ToLabel: string;
const
  LABELS: array [TNivelLog] of string = ('Normal', 'Alto', 'Extremo');
begin
  Result := LABELS[Self];
end;

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

initialization
  NivelLog := nlNormal;

end.