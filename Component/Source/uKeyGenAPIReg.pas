unit uKeyGenAPIReg;

interface

uses
  System.SysUtils, System.Classes,
  uKeyGenAPI;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Cornelius Concepts', [TKeyGenAPIClient]);
end;

end.
