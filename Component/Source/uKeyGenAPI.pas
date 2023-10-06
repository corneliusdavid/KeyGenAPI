unit uKeyGenAPI;

interface

uses
  System.SysUtils, System.Classes, REST.Types, REST.Client, System.JSON, System.Generics.Collections;

type
  TKeyGenLicenseStatus = (lsUnknown, lsActive, lsInactive, lsExpiring, lsExpired, lsSuspended, lsBanned);

  TKeyGenLicense = class
  private
    FKey: string;
    FExpirationStr: string;
    FStatusStr: string;
    FProtected: Boolean;
    FUses: Integer;
    FVersion: string;
    FIsSuspended: Boolean;
    FIsEncrypted: Boolean;
    FIsFloating: Boolean;
    FIsStrict: Boolean;
    FMaxMachines: Integer;
    FMaxProcesses: Integer;
    FMaxCores: Integer;
    FMaxUses: Integer;
    FRequireHeartbeat: Boolean;
    FRequireCheckIn: Boolean;
    FLastValidatedStr: string;
    FLastCheckOutStr: string;
    FLastCheckInStr: string;
    FNextCheckInStr: string;
    FCreatedStr: string;
    FUpdatedStr: string;
    FLicensee: string;
    function GetExpirationDT: TDateTime;
    procedure SetExpirationDT(const Value: TDateTime);
    function GetStatus: TKeyGenLicenseStatus;
    function GetCreatedDT: TDateTime;
    function GetLastCheckInDT: TDateTime;
    function GetLastCheckOutDT: TDateTime;
    function GetLastValidatedDT: TDateTime;
    function GetNextCheckInDT: TDateTime;
    function GetUpdatedDT: TDateTime;
    procedure SetStatus(const Value: TKeyGenLicenseStatus);
    procedure SetCreatedDT(const Value: TDateTime);
    procedure SetLastCheckInDT(const Value: TDateTime);
    procedure SetLastCheckOutDT(const Value: TDateTime);
    procedure SetLastValidatedDT(const Value: TDateTime);
    procedure SetNextCheckInDt(const Value: TDateTime);
    procedure SetUpdatedDT(const Value: TDateTime);
  public
    property Key: string read FKey write FKey;
    property Licensee: string read FLicensee write FLicensee;
    property ExpirationStr: string read FExpirationStr write FExpirationStr;
    property Expiration: TDateTime read GetExpirationDT write SetExpirationDT;
    property StatusStr: string read FStatusStr write FStatusStr;
    property Status: TKeyGenLicenseStatus read GetStatus write SetStatus;
    property KeyUses: Integer read FUses write FUses;
    property IsProtected: Boolean read FProtected write FProtected;
    property Version: string read FVersion write FVersion;
    property IsSuspended: Boolean read FIsSuspended write FIsSuspended;
    property IsEncrypted: Boolean read FIsEncrypted write FIsEncrypted;
    property IsFloating: Boolean read FIsFloating write FIsFloating;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property MaxMachines: Integer read FMaxMachines write FMaxMachines;
    property MaxProcesses: Integer read FMaxProcesses write FMaxProcesses;
    property MaxCores: Integer read FMaxCores write FMaxCores;
    property MaxUses: Integer read FMaxUses write FMaxUses;
    property RequireHeartbeat: Boolean read FRequireHeartbeat write FRequireHeartbeat;
    property RequireCheckIn: Boolean read FRequireCheckIn write FRequireCheckIn;
    property LastValidatedStr: string read FLastValidatedStr write FLastValidatedStr;
    property LastValidated: TDateTime read GetLastValidatedDT write SetLastValidatedDT;
    property LastCheckOutStr: string read FLastCheckOutStr write FLastCheckOutStr;
    property LastCheckOut: TDateTime read GetLastCheckOutDT write SetLastCheckOutDT;
    property LastCheckInStr: string read FLastCheckInStr write FLastCheckInStr;
    property LastCheckIn: TDateTime read GetLastCheckInDT write SetLastCheckInDT;
    property NextCheckInStr: string read FNextCheckInStr write FNextCheckInStr;
    property NextCheckIn: TDateTime read GetNextCheckInDT write SetNextCheckInDt;
    property CreatedStr: string read FCreatedStr write FCreatedStr;
    property Created: TDateTime read GetCreatedDT write SetCreatedDT;
    property UpdatedStr: string read FUpdatedStr write FUpdatedStr;
    property Updated: TDateTime read GetUpdatedDT write SetUpdatedDT;
  end;

  TKeyGenLicenses = TList<TKeyGenLicense>;

  [ComponentPlatforms(pfidWindows or pfidAndroid or pfidOSX or pfidiOS)]
  TKeyGenAPIClient = class(TComponent)
  private
    // REST components
    FKeyGenRestClient: TRESTClient;

    // the LastStatus and LastError is set after every API call
    FLastStatus: Integer;
    FLastError: string;
    FLastResponse: string;
    // KeyGen access
    FAccountID: string;
    FBaseURL: string;
    // the licenses
    FKeyGenLicenses: TKeyGenLicenses;

    FMetaDataObj: TJSONValue;
    procedure SetAccountID(const Value: string);
    procedure SetAccountIDRequestParam(ARESTRequest: TRESTRequest);
    procedure SetIntRequestParam(ARESTRequest: TRESTRequest; const ParamName: string; const ParamValue: Integer);
    procedure SetBodyRequestParam(ARESTRequest: TRESTRequest; const ABody: string);
  protected
    const
      ERROR_ACCOUNTID_NOT_SET = 'KeyGen Account ID is not set';
      LICENSE_KEY_BODY = '{ "meta": { "key": "%s" } }';
    function IsAccountIDSet : Boolean;
    function FillNewLicenseFromJSON(const LicenseAttr: TJSONValue): TKeyGenLicense;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // KeyGen API functions
    function ListLicenses(const PageNum: Integer = 1; const Limit: Integer = 10): Boolean;
    function ValidateKey(const Key: string): Boolean;
    { TODO : add support for more functions later }
  published
    property BaseURL: string read FBaseURL write FBaseURL;
    property AccountID: string read FAccountID write SetAccountID;
    property KeyGenLicenses: TKeyGenLicenses read FKeyGenLicenses write FKeyGenLicenses;
  end;


implementation

uses
  System.DateUtils, System.StrUtils;

{ TKeyGenAPIClient }

constructor TKeyGenAPIClient.Create(AOwner: TComponent);
begin
  inherited;

  FKeyGenLicenses := TList<TKeyGenLicense>.Create;

  FKeyGenRestClient := TRESTClient.Create(Self);

  FKeyGenRestClient.Name := 'restCliKeygen';
  FKeyGenRestClient.Accept := 'application/json, text/plain; q=0.9, text/html;q=0.8,';
  FKeyGenRestClient.AcceptCharset := 'utf-8, *;q=0.8';
  FKeyGenRestClient.SynchronizedEvents := False;
end;

destructor TKeyGenAPIClient.Destroy;
begin
  FKeyGenLicenses.Free;

  inherited;
end;

function TKeyGenAPIClient.IsAccountIDSet: Boolean;
begin
  Result := not FAccountID.IsEmpty;
  if Result then
    FLastError := EmptyStr
  else
    FLastError := ERROR_ACCOUNTID_NOT_SET;
end;

procedure TKeyGenAPIClient.SetAccountID(const Value: string);
begin
  FAccountID := Trim(Value);
end;

procedure TKeyGenAPIClient.SetAccountIDRequestParam(ARESTRequest: TRESTRequest);
begin
  ARESTRequest.Params.AddItem('ACCOUNT', FAccountID, TRESTRequestParameterKind.pkURLSEGMENT);
end;

procedure TKeyGenAPIClient.SetIntRequestParam(ARESTRequest: TRESTRequest; const ParamName: string; const ParamValue: Integer);
begin
  ARESTRequest.Params.AddItem(ParamName, IntToStr(ParamValue), TRESTRequestParameterKind.pkURLSEGMENT);
end;

procedure TKeyGenAPIClient.SetBodyRequestParam(ARESTRequest: TRESTRequest; const ABody: string);
begin
  ARESTRequest.Params.AddItem('body', ABody, TRESTRequestParameterKind.pkREQUESTBODY, [], ctAPPLICATION_JSON);
end;

function TKeyGenAPIClient.FillNewLicenseFromJSON(const LicenseAttr: TJSONValue): TKeyGenLicense;
{$REGION 'sample valid result'}
(*
  {
    "data": {
      "id": "ef337fed-fc6a-4270-af91-a09ee3353849",
      "type": "licenses",
      "attributes": {
        "name": "Thimsfrabble Enterprises Trial",
        "key": "7P4C-JX7W-3LXN-HC9J-9C99-TNP4-UKF7-FPRF",
        "expiry": null,
        "status": "ACTIVE",
        "uses": 0,
        "suspended": false,
        "scheme": null,
        "encrypted": false,
        "strict": false,
        "floating": true,
        "concurrent": false,
        "protected": true,
        "maxMachines": null,
        "maxCores": null,
        "maxUses": null,
        "requireHeartbeat": false,
        "requireCheckIn": true,
        "lastValidated": "2022-03-07T05:50:47.689Z",
        "lastCheckIn": "2022-03-07T01:11:03.193Z",
        "nextCheckIn": "2022-03-14T01:11:03.193Z",
        "metadata": {
          "storeName": "Monte's Monkey Sales",
          "rproClientId": 44223,
          "rproSiteCount": 50
        },
        "created": "2022-03-07T01:11:03.188Z",
        "updated": "2022-03-07T05:50:47.695Z"
      },
      "relationships": {
        "account": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25"
          },
          "data": {
            "type": "accounts",
            "id": "17c505af-838c-48e9-9f64-e25c72757d25"
          }
        },
        "product": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849/product"
          },
          "data": {
            "type": "products",
            "id": "299e4916-4c87-49dd-b6d1-1b91bc242230"
          }
        },
        "policy": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849/policy"
          },
          "data": {
            "type": "policies",
            "id": "304c024d-ac62-4c7f-bd7e-3e578105cff4"
          }
        },
        "user": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849/user"
          },
          "data": {
            "type": "users",
            "id": "e642c952-4afa-488e-b59c-3949b7a50a5b"
          }
        },
        "machines": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849/machines"
          },
          "meta": {
            "cores": 0,
            "count": 0
          }
        },
        "tokens": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849/tokens"
          }
        },
        "entitlements": {
          "links": {
            "related": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849/entitlements"
          }
        }
      },
      "links": {
        "self": "/v1/accounts/17c505af-838c-48e9-9f64-e25c72757d25/licenses/ee337fed-fb6a-4470-af96-a09ee3453849"
      }
    },
    "meta": {
      "ts": "2022-03-07T05:50:47.699Z",
      "valid": true,
      "detail": "is valid",
      "constant": "VALID"
    }
  }
*)
{$ENDREGION}
begin
  Result := TKeyGenLicense.Create;
  try
    Result.Key := LicenseAttr.P['key'].Value;
    Result.Licensee := IfThen(LicenseAttr.P['name'].Null, EmptyStr, LicenseAttr.P['name'].Value);
    Result.StatusStr        := IfThen(LicenseAttr.P['status'].Null, EmptyStr, LicenseAttr.P['status'].Value);
    if LicenseAttr.P['uses'].Null then
      Result.KeyUses        := 0
    else
      Result.KeyUses        := LicenseAttr.P['uses'].AsType<Integer>;
    Result.IsProtected      := SameText(IfThen(LicenseAttr.P['protected'].Null, EmptyStr, LicenseAttr.P['protected'].Value), 'true');
    Result.Version          := IfThen(LicenseAttr.P['version'].Null, EmptyStr, LicenseAttr.P['version'].Value);
    Result.IsSuspended      := SameText(IfThen(LicenseAttr.P['suspended'].Null, EmptyStr, LicenseAttr.P['suspended'].Value), 'true');
    Result.IsEncrypted      := SameText(IfThen(LicenseAttr.P['encrypted'].Null, EmptyStr, LicenseAttr.P['encrypted'].Value), 'true');
    Result.IsFloating       := SameText(IfThen(LicenseAttr.P['floating'].Null, EmptyStr, LicenseAttr.P['floating'].Value), 'true');
    Result.IsStrict         := SameText(IfThen(LicenseAttr.P['strict'].Null, EmptyStr, LicenseAttr.P['strict'].Value), 'true');
    if LicenseAttr.P['maxMachines'].Null then
      Result.MaxMachines    := 0
    else
      Result.MaxMachines    := LicenseAttr.P['maxMachines'].AsType<Integer>;
    if LicenseAttr.P['maxProcesses'].Null then
      Result.MaxProcesses   := 0
    else
      Result.MaxProcesses   := LicenseAttr.P['maxProcesses'].AsType<Integer>;
    if LicenseAttr.P['maxCores'].Null then
      Result.MaxCores       := 0
    else
      Result.MaxCores       := LicenseAttr.P['maxCores'].AsType<Integer>;
    if LicenseAttr.P['maxUses'].Null then
      Result.MaxUses        := 0
    else
      Result.MaxUses        := LicenseAttr.P['maxUses'].AsType<Integer>;
    Result.RequireHeartbeat := SameText(IfThen(LicenseAttr.P['requireHeartbeat'].Null, EmptyStr, LicenseAttr.P['requireHeartbeat'].Value), 'true');
    Result.RequireCheckIn   := SameText(IfThen(LicenseAttr.P['requireCheckIn'].Null, EmptyStr, LicenseAttr.P['requireCheckIn'].Value), 'true');
    Result.LastValidatedStr := IfThen(LicenseAttr.P['lastValidated'].Null, EmptyStr, LicenseAttr.P['lastValidated'].Value);
    Result.LastCheckOutStr  := IfThen(LicenseAttr.P['lastCheckOut'].Null, EmptyStr, LicenseAttr.P['lastCheckOut'].Value);
    Result.LastCheckInStr   := IfThen(LicenseAttr.P['lastCheckIn'].Null, EmptyStr, LicenseAttr.P['lastCheckIn'].Value);
    Result.NextCheckInStr   := IfThen(LicenseAttr.P['nextCheckIn'].Null, EmptyStr, LicenseAttr.P['nextCheckIn'].Value);
    Result.ExpirationStr    := IfThen(LicenseAttr.P['expiry'].Null, EmptyStr, LicenseAttr.P['expiry'].Value);
    Result.CreatedStr       := IfThen(LicenseAttr.P['created'].Null, EmptyStr, LicenseAttr.P['created'].Value);
    Result.UpdatedStr       := IfThen(LicenseAttr.P['updated'].Null, EmptyStr, LicenseAttr.P['updated'].Value);
    //FMetaDataObj      := LicenseAttr.P['metadata'];
  except
    on e:Exception do begin
      FLastError := 'PARSE_ERROR';
    end;
  end;
end;

function TKeyGenAPIClient.ListLicenses(const PageNum: Integer = 1; const Limit: Integer = 10): Boolean;
const
  LIST_LICENSES_RESOURCE = 'accounts/{ACCOUNT}/licenses?limit={LIMIT}&page={PAGE}';
var
  reqListLicenses: TRESTRequest;
  respListLicenses: TRESTResponse;
  LStatusResponse: TJSONValue;
  LMetaObj: TJSONValue;
  LDataArray: TJSONArray;
  LAttrObj: TJSONValue;
begin
  Result := False;

  FreeAndNil(FMetaDataObj);

  FKeyGenRestClient.BaseURL := FBaseURL;

  reqListLicenses := TRESTRequest.Create(Self);
  try
    reqListLicenses.Name := 'reqListLicenses';
    reqListLicenses.AssignedValues := [TCustomRESTRequest.TAssignedValue.rvConnectTimeout,
                                       TCustomRESTRequest.TAssignedValue.rvReadTimeout];
    reqListLicenses.Client := FKeyGenRestClient;
    reqListLicenses.Resource := LIST_LICENSES_RESOURCE;
    reqListLicenses.Method := rmPOST;

    respListLicenses := TRESTResponse.Create(nil);
    try
      respListLicenses.Name := 'respListLicenses';
      respListLicenses.ContentType := 'application/json';

      reqListLicenses.Response := respListLicenses;

      FKeyGenLicenses.Clear;

      if IsAccountIDSet then begin
        reqListLicenses.Params.Clear;
        SetAccountIDRequestParam(reqListLicenses);
        SetIntRequestParam(reqListLicenses, 'LIMIT', Limit);
        SetIntRequestParam(reqListLicenses, 'PAGE', PageNum);
        reqListLicenses.Execute; /////////////////// get unauthorized ... ???

        FLastStatus := respListLicenses.StatusCode;
        FLastError := respListLicenses.StatusText;

        if respListLicenses.Status.SuccessOK_200 then begin
          Result := True;
          FLastResponse := respListLicenses.Content;

          LStatusResponse := respListLicenses.JSONValue;

          LMetaObj := LStatusResponse.P['meta'];
          if not SameText(LMetaObj.P['valid'].Value, 'true') then begin
            FLastError := 'INVALID LICENSE';
            Result := False;
          end;

          LDataArray := TJSONArray(LStatusResponse.P['data']);
          for var LDataItem in LDataArray do begin
            LAttrObj := LDataItem.P['attributes'];
            if LAttrObj <> nil then
              FKeyGenLicenses.Add(FillNewLicenseFromJSON(LAttrObj));
          end;
        end;
      end;
    finally
      respListLicenses.Free;
    end;
  finally
    reqListLicenses.Free;
  end;
end;

function TKeyGenAPIClient.ValidateKey(const Key: string): Boolean;
const
  VALIDATE_KEY_RESOURCE = 'accounts/{ACCOUNT}/licenses/actions/validate-key';
var
  reqValidateLicenseKey: TRESTRequest;
  respValidateLicenseKey: TRESTResponse;
  LStatusResponse: TJSONValue;
  LMetaObj: TJSONValue;
  LDataObj: TJSONValue;
  LAttrObj: TJSONValue;
begin
  Result := False;

  FreeAndNil(FMetaDataObj);

  FKeyGenRestClient.BaseURL := FBaseURL;

  reqValidateLicenseKey := TRESTRequest.Create(Self);
  try
    reqValidateLicenseKey.Name := 'reqValidateLicenseKey';
    reqValidateLicenseKey.AssignedValues := [TCustomRESTRequest.TAssignedValue.rvConnectTimeout,
                                             TCustomRESTRequest.TAssignedValue.rvReadTimeout];
    reqValidateLicenseKey.Client := FKeyGenRestClient;
    reqValidateLicenseKey.Resource := VALIDATE_KEY_RESOURCE;
    reqValidateLicenseKey.Method := rmPOST;

    respValidateLicenseKey := TRESTResponse.Create(nil);
    try
      respValidateLicenseKey.Name := 'respValidateLicenseKey';
      respValidateLicenseKey.ContentType := 'application/json';

      reqValidateLicenseKey.Response := respValidateLicenseKey;

      FKeyGenLicenses.Clear;

      if IsAccountIDSet then begin
        reqValidateLicenseKey.Params.Clear;
        SetAccountIDRequestParam(reqValidateLicenseKey);
        SetBodyRequestParam(reqValidateLicenseKey, Format(LICENSE_KEY_BODY, [Key]));
        reqValidateLicenseKey.Execute;

        FLastStatus := respValidateLicenseKey.StatusCode;
        FLastError := respValidateLicenseKey.StatusText;

        if respValidateLicenseKey.Status.SuccessOK_200 then begin
          Result := True;
          FLastResponse := respValidateLicenseKey.Content;
          LStatusResponse := respValidateLicenseKey.JSONValue;

          LMetaObj := LStatusResponse.P['meta'];
          if not SameText(LMetaObj.P['valid'].Value, 'true') then begin
            FLastError := 'INVALID LICENSE';
            Result := False;
          end;

          LDataObj := LStatusResponse.P['data'];
          if LDataObj <> nil then begin
            LAttrObj := LDataObj.P['attributes'];
            if LAttrObj <> nil then
              FKeyGenLicenses.Add(FillNewLicenseFromJSON(LAttrObj));
          end;
        end;
      end;
    finally
      respValidateLicenseKey.Free;
    end;
  finally
    reqValidateLicenseKey.Free;
  end;
end;

{ TKeyGenLicense }

function TKeyGenLicense.GetStatus: TKeyGenLicenseStatus;
begin
  if SameText(FStatusStr, 'ACTIVE') then
    Result := lsActive
  else if SameText(FStatusStr, 'INACTIVE') then
    Result := lsInactive
  else if SameText(FStatusStr, 'EXPIRING') then
    Result := lsExpiring
  else if SameText(FStatusStr, 'EXPIRED') then
    Result := lsExpired
  else if SameText(FStatusStr, 'SUSPENDED') then
    Result := lsSuspended
  else if SameText(FStatusStr, 'BANNED') then
    Result := lsBanned
  else
    Result := lsUnknown;
end;

function TKeyGenLicense.GetCreatedDT: TDateTime;
begin
  Result := 0.0;

  if not FCreatedStr.IsEmpty then
    try
      Result := ISO8601ToDate(FCreatedStr, False);
    except
    end;
end;

function TKeyGenLicense.GetExpirationDT: TDateTime;
begin
  Result := 0.0;

  if not FExpirationStr.IsEmpty then
    try
      Result := ISO8601ToDate(FExpirationStr, False);
    except
    end;
end;

function TKeyGenLicense.GetLastCheckInDT: TDateTime;
begin
  Result := 0.0;

  if not FLastCheckInStr.IsEmpty then
    try
      Result := ISO8601ToDate(FLastCheckInStr, False);
    except
    end;
end;

function TKeyGenLicense.GetLastCheckOutDT: TDateTime;
begin
  Result := 0.0;

  if not FLastCheckOutStr.IsEmpty then
    try
      Result := ISO8601ToDate(FLastCheckOutStr, False);
    except
    end;
end;

function TKeyGenLicense.GetLastValidatedDT: TDateTime;
begin
  Result := 0.0;

  if not FLastValidatedStr.IsEmpty then
    try
      Result := ISO8601ToDate(FLastValidatedStr, False);
    except
    end;
end;

function TKeyGenLicense.GetNextCheckInDT: TDateTime;
begin
  Result := 0.0;

  if not FNextCheckInStr.IsEmpty then
    try
      Result := ISO8601ToDate(FNextCheckInStr, False);
    except
    end;
end;

function TKeyGenLicense.GetUpdatedDT: TDateTime;
begin
  Result := 0.0;

  if not FUpdatedStr.IsEmpty then
    try
      Result := ISO8601ToDate(FUpdatedStr, False);
    except
    end;
end;

procedure TKeyGenLicense.SetStatus(const Value: TKeyGenLicenseStatus);
begin
  case Value of
    lsUnknown:   FStatusStr := EmptyStr;
    lsActive:    FStatusStr := 'ACTIVE';
    lsInactive:  FStatusStr := 'INACTIVE';
    lsExpiring:  FStatusStr := 'EXPIRING';
    lsExpired:   FStatusStr := 'EXPIRED';
    lsSuspended: FStatusStr := 'SUSPENDED';
    lsBanned:    FStatusStr := 'BANNED';
  end;
end;

procedure TKeyGenLicense.SetCreatedDT(const Value: TDateTime);
begin
  FCreatedStr := DateToISO8601(Value, False);
end;

procedure TKeyGenLicense.SetExpirationDT(const Value: TDateTime);
begin
  FExpirationStr := DateToISO8601(Value, False);
end;

procedure TKeyGenLicense.SetLastCheckInDT(const Value: TDateTime);
begin
  FLastCheckInStr := DateToISO8601(Value, False);
end;

procedure TKeyGenLicense.SetLastCheckOutDT(const Value: TDateTime);
begin
  FLastCheckOutStr := DateToISO8601(Value, False);
end;

procedure TKeyGenLicense.SetLastValidatedDT(const Value: TDateTime);
begin
  FLastValidatedStr := DateToISO8601(Value, False);
end;

procedure TKeyGenLicense.SetNextCheckInDt(const Value: TDateTime);
begin
  FNextCheckInStr := DateToISO8601(Value, False);
end;

procedure TKeyGenLicense.SetUpdatedDT(const Value: TDateTime);
begin
  FUpdatedStr := DateToISO8601(Value, False);
end;

end.
