program TestRunner;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  TesteGravarLogQueue in 'TesteGravarLogQueue.pas';

var
  LRunner : ITestRunner;
  LResults: IRunResults;
  LLogger : ITestLogger;
  LXmlFile: string;

begin
  try
    TDUnitX.RegisterTestFixture(TObject);  // dummy — fixtures reais registradas nas units

    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;

    // Logger de console
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);

    // Logger XML (NUnit) para CI
    LXmlFile := ExtractFilePath(ParamStr(0)) + 'TestResults.xml';
    LRunner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(LXmlFile));

    LResults := LRunner.Execute;

    if not LResults.AllPassed then
      ExitCode := 1;

    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      Writeln('');
      Writeln('Pressione ENTER para sair...');
      Readln;
    end;

  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 2;
    end;
  end;
end.
