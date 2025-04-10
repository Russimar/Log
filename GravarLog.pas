unit GravarLog;

interface

uses
  System.IniFiles;

type
  IGravarLog = Interface
    ['{4E3DB66D-16FD-45FB-9CC4-1B5A919854A4}']
    function doSaveLog(aValue: String): IGravarLog; Overload;
    function doSaveLog(aValue, AFileName: String): IGravarLog; Overload;
  End;

  TGravarLog = class(TInterfacedObject, IGravarLog)
  private
    FPath: String;
  public
    class function New: IGravarLog;
    constructor Create;
    destructor Destroy; override;
    property Path: String read FPath write FPath;
    function doSaveLog(aValue: String): IGravarLog; Overload;
    function doSaveLog(aValue, AFileName: String): IGravarLog; Overload;
  end;

implementation

uses
  System.SysUtils;

{ TGravarLog }

constructor TGravarLog.Create;
begin
  Path := ExtractFilePath(ParamStr(0));
end;

destructor TGravarLog.Destroy;
begin

  inherited;
end;

function TGravarLog.doSaveLog(aValue, AFileName: String): IGravarLog;
var
  Caminho: String;
  Log: TextFile;
begin
  Caminho := FPath + '/Log';
  if not DirectoryExists(Caminho) then
  begin
    try
      ForceDirectories(Caminho);
//      CreateDir(Caminho);
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

function TGravarLog.doSaveLog(aValue: String): IGravarLog;
var
  Caminho: String;
  Log: TextFile;
begin
  Caminho := FPath + '/Log';
  if not DirectoryExists(Caminho) then
  begin
    try
      ForceDirectories(Caminho);
//      CreateDir(Caminho);
    except
      Exit;
    end;
  end;
  Caminho := Caminho + '/' + StringReplace(ExtractFileName(ParamStr(0)),'.exe', '.txt',[rfReplaceAll]);
  Caminho := StringReplace(Caminho, '.txt', FormatDateTime('ddmmyyyy', now) + '.txt',[rfReplaceAll]);
  AssignFile(Log, Caminho);
  if not FileExists(Caminho) then
    Rewrite(Log)
  else
    Append(Log);
  Writeln(Log, 'Mensagem: ' + FormatDateTime('dd/mm/yyyy hh:nn:ss.zzz', now) + ' ' + aValue);
  CloseFile(Log);
  {$IFDEF CONSOLE}
    Writeln('Mensagem: ' + FormatDateTime('dd/mm/yyyy hh:nn', now) + ' ' + aValue);
  {$ENDIF}
end;

class function TGravarLog.New: IGravarLog;
begin
  Result := Self.Create;
end;

end.
