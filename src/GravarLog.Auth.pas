unit GravarLog.Auth;

interface

type
  TGravarLogAuth = class
  private
    class function LerCampoVersionInfo(const ACampo: string): string;
    class function LerMetaData(const ACampo: string): string;
    class function ObterAppName: string;
    class function ObterAppKey: string;
  public
    class function GerarBearer: string;
  end;

implementation

uses
  System.Hash
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  {$IFDEF ANDROID}
  , Androidapi.JNI.App
  , Androidapi.Helpers
  , Androidapi.JNI.JavaTypes
  {$ENDIF}
  ;

{ TGravarLogAuth }

class function TGravarLogAuth.LerCampoVersionInfo(const ACampo: string): string;
{$IFDEF MSWINDOWS}
var
  LSize     : DWORD;
  LDummy    : DWORD;
  LBuffer   : Pointer;
  LTrans    : PWord;
  LTransSize: UINT;
  LValue    : PChar;
  LValueSize: UINT;
  LLangCode : string;
begin
  Result := '';
  LSize := GetFileVersionInfoSize(PChar(ParamStr(0)), LDummy);
  if LSize = 0 then Exit;
  GetMem(LBuffer, LSize);
  try
    if not GetFileVersionInfo(PChar(ParamStr(0)), 0, LSize, LBuffer) then Exit;
    if VerQueryValue(LBuffer, '\VarFileInfo\Translation', Pointer(LTrans), LTransSize)
       and (LTransSize >= 4) then
      LLangCode := Format('%.4x%.4x', [LTrans^, PWord(NativeUInt(LTrans) + 2)^])
    else
      LLangCode := '040904B0';
    if VerQueryValue(LBuffer,
         PChar('\StringFileInfo\' + LLangCode + '\' + ACampo),
         Pointer(LValue), LValueSize) then
      Result := LValue;
  finally
    FreeMem(LBuffer, LSize);
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

class function TGravarLogAuth.LerMetaData(const ACampo: string): string;
{$IFDEF ANDROID}
var
  LAppInfo: JApplicationInfo;
begin
  Result := '';
  try
    LAppInfo := TAndroidHelper.Context.getPackageManager.getApplicationInfo(
      TAndroidHelper.Context.getPackageName,
      JPackageManager.JavaClass.GET_META_DATA);
    if LAppInfo.metaData <> nil then
      Result := JStringToString(LAppInfo.metaData.getString(StringToJString(ACampo)));
  except
    Result := '';
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

class function TGravarLogAuth.ObterAppName: string;
begin
{$IFDEF MSWINDOWS}
  Result := LerCampoVersionInfo('AppName');
{$ELSE}{$IFDEF ANDROID}
  Result := LerMetaData('AppName');
{$ELSE}
  Result := '';
{$ENDIF}{$ENDIF}
end;

class function TGravarLogAuth.ObterAppKey: string;
begin
{$IFDEF MSWINDOWS}
  Result := LerCampoVersionInfo('AppKey');
{$ELSE}{$IFDEF ANDROID}
  Result := LerMetaData('AppKey');
{$ELSE}
  Result := '';
{$ENDIF}{$ENDIF}
end;

class function TGravarLogAuth.GerarBearer: string;
var
  LAppName: string;
  LAppKey : string;
begin
  Result   := '';
  LAppName := ObterAppName;
  LAppKey  := ObterAppKey;
  if LAppName.IsEmpty or LAppKey.IsEmpty then Exit;
  Result := THashSHA2.GetHashString(LAppName + ':' + LAppKey);
end;

end.
