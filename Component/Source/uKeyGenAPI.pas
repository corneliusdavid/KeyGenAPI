unit uKeyGenAPI;

interface

uses
  System.SysUtils, System.Classes, REST.Types, REST.Client, System.JSON, System.Generics.Collections;

type
  [ComponentPlatforms(pfidWindows or pfidAndroid or pfidOSX or pfidiOS)]
  TKeyGenAPIClient = class(TComponent)
  private
    // REST components
    FKeyGenRestClient: TRESTClient;

    // the LastStatus and LastError is set after every API call
    FLastStatus: Integer;
    FLastError: string;
    FLastResponse: string;
    // KeyGen fields
    FAccountID: string;
    FBaseURL: string;
    FLicenseStatusStr: string;
    FLicenseKey: string;
    FLastValidatedStr: string;
    FExpirationStr: string;
    FLicensee: string;
    FMetaDataObj: TJSONValue;
    procedure SetAccountID(const Value: string);
    procedure SetAccountIDRequestParam(ARESTRequest: TRESTRequest);
    procedure SetBodyRequestParam(ARESTRequest: TRESTRequest; const ABody: string);
  protected
    const
      ERROR_ACCOUNTID_NOT_SET = 'KeyGen Account ID is not set';
      LICENSE_KEY_BODY = '{ "meta": { "key": "%s" } }';
    function IsAccountIDSet : Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    // KeyGen API functions
    function ValidateKey(const Key: string): Boolean;
    { TODO : add support for more functions later }
  published
    property BaseURL: string read FBaseURL write FBaseURL;
    property AccountID: string read FAccountID write SetAccountID;
    property LicenseStatusStr: string read FLicenseStatusStr write FLicenseStatusStr;
    property LicenseKey: string read FLicenseKey write FLicenseKey;
    property Licensee: string read FLicensee write FLicensee;
    property LastValidatedStr: string read FLastValidatedStr write FLastValidatedStr;
    property ExpirationStr: string read FExpirationStr write FExpirationStr;
  end;


implementation


{ TKeyGenAPIClient }

constructor TKeyGenAPIClient.Create(AOwner: TComponent);
begin
  inherited;

  FKeyGenRestClient := TRESTClient.Create(Self);

  FKeyGenRestClient.Name := 'restCliKeygen';
  FKeyGenRestClient.Accept := 'application/json, text/plain; q=0.9, text/html;q=0.8,';
  FKeyGenRestClient.AcceptCharset := 'utf-8, *;q=0.8';
  FKeyGenRestClient.SynchronizedEvents := False;
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

procedure TKeyGenAPIClient.SetBodyRequestParam(ARESTRequest: TRESTRequest; const ABody: string);
begin
  ARESTRequest.Params.AddItem('body', ABody, TRESTRequestParameterKind.pkREQUESTBODY, [], ctAPPLICATION_JSON);
end;

function TKeyGenAPIClient.ValidateKey(const Key: string): Boolean;
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
    reqValidateLicenseKey.Resource := 'accounts/{ACCOUNT}/licenses/actions/validate-key';
    reqValidateLicenseKey.Method := rmPOST;

    respValidateLicenseKey := TRESTResponse.Create(nil);
    try
      respValidateLicenseKey.Name := 'respValidateLicenseKey';
      respValidateLicenseKey.ContentType := 'application/json';

      reqValidateLicenseKey.Response := respValidateLicenseKey;

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
          if not SameText(LMetaObj.P['valid'].Value, 'true') then
            FLicenseStatusStr := 'INVALID';

          LDataObj := LStatusResponse.P['data'];
          if LDataObj <> nil then begin
            LAttrObj := LDataObj.P['attributes'];
            if LAttrObj <> nil then begin
              {$REGION 'sample valid result'}
          (*
            {
              "data": {
                "id": "ee337fed-fb6a-4470-af96-a09ee3453849",
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

              try
                FLicenseKey := LAttrObj.P['key'].Value;
                FLicensee := LAttrObj.P['name'].Value;
                FLicenseStatusStr := LAttrObj.P['status'].Value;
                FLastValidatedStr := LAttrObj.P['lastValidated'].Value;
                FExpirationStr    := LAttrObj.P['expiry'].Value;
                FMetaDataObj      := LAttrObj.P['metadata'];
              except
                on e:Exception do begin
                  FLicenseStatusStr := 'PARSE_ERROR';
                end;
              end;
            end;
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

end.
