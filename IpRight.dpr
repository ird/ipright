program IpRight;

// Task 51. Add support for mx and mxpri.

uses
  SvcMgr,
  IpRightServiceUnit in 'IpRightServiceUnit.pas' {IpRightService: TService},
  UtilityUnit in 'UtilityUnit.pas',
  XmlUnit in 'XmlUnit.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'IP Right';
  Application.CreateForm(TIpRightService, IpRightService);
  Application.Run;
end.
