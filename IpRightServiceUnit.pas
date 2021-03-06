unit IpRightServiceUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ScktComp, ExtCtrls, Contnrs, XmlUnit;

type
  c_Account = class(TObject)
  private

    m_strDisabled: string;
    m_strServer: string;
    m_strPort: string;
    m_strUsername: string;
    m_strPassword: string;
    m_olHost: TObjectList;

    // Task 51.

    m_strMx: string;

    // Task 51.

    m_strMxPri: string;

	public

    constructor Create(
    );

    destructor Destroy(
    ); override;

    procedure Load(
      const p_xe: c_XmlElement
    );

		procedure Save(
      const p_xe: c_XmlElement
    );

  end;

  TIpRightService = class(TService)
  
    procedure ServiceExecute(Sender: TService);
    procedure ServiceShutdown(Sender: TService);

  private

    m_strLog: string; // master switch, if this is not '1', nothing logs.
    m_strLogMethod: string; // entry into some methods.
    m_strLogOption: string; // what's loaded and saved.
    m_strLogCheck: string; // what's sent and received.
    m_strLogUpdate: string; // what's sent and received.
    m_strCheckIp: string; // master switch, if this is not '1', no checks are done.
    m_strCheckIpTick: string;
    m_strCheckIpInternet: string; // when '1' uses server, port, usename, password, and get to determine the IP address, otherwise gets the machine's IP addresss.
    m_strCheckIpServer: string;
    m_strCheckIpPort: string;
    m_strCheckIpUsername: string;
    m_strCheckIpPassword: string;
    m_strCheckIpGet: string;
    m_strCheckIpExcludeIpAddresses: string;

    m_csCheckIpAddress: TClientSocket;
    m_strCheckIpReply: string;

    m_csUpdateIpAddress: TClientSocket;
    m_strUpdateIpReply: string;

    m_tmrCheckIpAddress: TTimer;
    m_nTicker: integer;

    m_strIpAddress: string;

		m_acc: c_Account;

//    m_olHost: TObjectList;

    m_strHostNames: string;

    m_ss: TServerSocket;

    procedure Log(p_str: string);

    procedure LogMethod(
      const p_str: string
    );

    procedure LogOptions(
      const p_xe: c_XmlElement
    );

    procedure Load();

    procedure Save();

    procedure EnableTimer(
		);

    procedure DisableTimer(
    );

    procedure m_csCheckIpAddressWrite(
      p_objSender: TObject;
      p_sck: TCustomWinSocket
    );

    procedure m_csCheckIpAddressRead(
      p_objSender: TObject;
			p_sck: TCustomWinSocket
    );

    procedure m_csCheckIpAddressDisconnect(
      p_objSender: TObject;
      p_sck: TCustomWinSocket
    );

    procedure m_csCheckIpAddressError(
      p_objSender: TObject;
      p_cws: TCustomWinSocket;
      p_ee: TErrorEvent;
      var p_nErrorCode: integer
    );

    procedure m_csUpdateIpAddressWrite(
      p_objSender: TObject;
      p_sck: TCustomWinSocket
    );

    procedure m_csUpdateIpAddressRead(
      p_objSender: TObject;
      p_sck: TCustomWinSocket
    );

    procedure m_csUpdateIpAddressDisconnect(
      p_objSender: TObject;
			p_sck: TCustomWinSocket
    );

    procedure m_csUpdateIpAddressError(
      p_objSender: TObject;
      p_cws: TCustomWinSocket;
      p_ee: TErrorEvent;
      var p_nErrorCode: integer
    );

    procedure m_ssClientError(
      p_objSender: TObject;
			p_cws: TCustomWinSocket;
      p_ee: TErrorEvent;
      var p_nErrorCode: integer
    );

    procedure m_ssClientRead(
      p_objSender: TObject;
      p_cws: TCustomWinSocket
    );

    procedure m_tmrInterval(
      p_objSender: TObject
    );

    function GetIpAddresses(
      const p_str: string
    ): string;

    procedure CheckIpAddress(
    );

    procedure UpdateIpAddress(
    );

  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
	end;

  c_Host = class(TObject)
  private

    m_strDisabled: string;
    m_strName: string;
    m_strUpdated: string; // when host was last successfully updated.
    m_strIpAddress: string; // last ip address successfully updated.
    m_strResultCode: string; // last reply status


	public

		procedure Load(
			const p_xe: c_XmlElement
		);

		procedure Save(
			const p_xe: c_XmlElement
		);

	end;

var
	IpRightService: TIpRightService;

implementation

{$R *.DFM}

uses
	FileCtrl,
	UtilityUnit;

const
	LOG_FILENAME = 'IpRight.log';
	XML_FILENAME = 'IpRight.xml';
	CLIENT_VERSION = '0.9.8';
	CLIENT_COMPANY = 'Independent Rapid Development Limited';
	CLIENT_EMAIL = 'stacey.richards@ird.co.nz';
	CONFIG_PORT = 54321;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  IpRightService.Controller(CtrlCode);
end;

procedure TIpRightService.CheckIpAddress(
);
begin
	LogMethod('Checking IP address.');

	if ('1' <> m_strCheckIp) then begin
    Log('Checking is disabled.');
    exit;
  end;

  DisableTimer();

  if ('1' <> m_strCheckIpInternet) then begin
    m_strCheckIpReply := #$D#$A + UtilityUnit.GetIpAddresses();
    Log(m_strCheckIpReply);
    m_csCheckIpAddressDisconnect(nil, nil);
    exit;
  end;
  FreeAndNil(m_csCheckIpAddress);
  m_strCheckIpReply := '';
  m_csCheckIpAddress := TClientSocket.Create(nil);
  m_csCheckIpAddress.Host := m_strCheckIpServer;
  m_csCheckIpAddress.Port := StrToIntDef(m_strCheckIpPort, 80);
  m_csCheckIpAddress.OnWrite := m_csCheckIpAddressWrite;
  m_csCheckIpAddress.OnRead := m_csCheckIpAddressRead;
  m_csCheckIpAddress.OnDisconnect := m_csCheckIpAddressDisconnect;
  m_csCheckIpAddress.OnError := m_csCheckIpAddressError;
  m_csCheckIpAddress.Open();
end;

procedure TIpRightService.DisableTimer(
);
begin
  m_tmrCheckIpAddress.Enabled := false;
end;

procedure TIpRightService.EnableTimer(
);
const
  DNS_PARK_DOMAIN = 'dnspark.com';
begin
  m_nTicker := StrToIntDef(m_strCheckIpTick, 600);
  if ((0 <> pos(DNS_PARK_DOMAIN, lowercase(m_strCheckIpServer))) and (
      m_nTicker < 600)) then begin
    m_nTicker := 600;
  end;
  m_tmrCheckIpAddress.Enabled := true;
end;

function TIpRightService.GetIpAddresses(
  const p_str: string
): string;
var
  l_b: boolean;
  l_i: integer;
  l_j: integer;
  l_an: array[0..3] of integer;
begin
  result := '';
  l_b := false;
  l_i := 0;
  l_j := 0;
  while (l_i < length(p_str)) do begin
    inc(l_i);
    if (p_str[l_i] in ['0'..'9']) then begin
      if (not l_b) then begin
        l_b := true;
        l_j := 0;
        ZeroMemory(@l_an, sizeof(l_an));
			end;
      l_an[l_j] := l_an[l_j] * 10 + byte(p_str[l_i]) - ord('0');
      if (l_an[l_j] > 255) then begin
        l_b := false;
      end;
    end else if ('.' = p_str[l_i]) then begin
      if (l_b) then begin
        inc(l_j);
        if (l_j > 3) then begin
          l_b := false;
        end;
      end;
    end else begin
      if (l_b) then begin
        if (3 = l_j) then begin
          result := result + IntToStr(l_an[0]) + '.' + IntToStr(l_an[1]) +
              '.' + IntToStr(l_an[2]) + '.' + IntToStr(l_an[3]) + #$D#$A;
        end;
        l_b := false;
      end;
    end;
  end;
  if (l_b) then begin
    if (3 = l_j) then begin
      result := result + IntToStr(l_an[0]) + '.' + IntToStr(l_an[1]) + '.' +
          IntToStr(l_an[2]) + '.' + IntToStr(l_an[3]) + #$D#$A;
    end;
  end;
end;

function TIpRightService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TIpRightService.Load(
);
var
  filename: string;
  filestream: TFileStream;
  l_xeRoot: c_XmlElement;
  l_i: integer;
  l_xe: c_XmlElement;
begin
  filename := ExtractFilePath(ParamStr(0)) + XML_FILENAME;
  if (not FileExists(filename)) then begin
    exit;
  end;
  l_xeRoot := c_XmlElement.Create('');
  try
    filestream := TFileStream.Create(filename, (fmOpenRead or fmShareDenyWrite));
    try
      l_xeRoot.LoadFromStream(filestream);
    finally
      FreeAndNil(filestream);
    end;
    for l_i := 0 to l_xeRoot.m_strlElement.Count - 1 do begin
      l_xe := c_XMLElement(l_xeRoot.m_strlElement.Objects[l_i]);
      if ('Log' = l_xe.m_strName) then begin
        m_strLog := l_xe.GetAttribute('Enabled');
        m_strLogMethod := l_xe.GetAttribute('Methods');
        m_strLogOption := l_xe.GetAttribute('Options');
        m_strLogCheck := l_xe.GetAttribute('Checks');
        m_strLogUpdate := l_xe.GetAttribute('Updates');
      end else if ('Check' = l_xe.m_strName) then begin
        m_strCheckIp := l_xe.GetAttribute('Enabled');
        m_strCheckIpTick := l_xe.GetAttribute('Tick');
        m_strCheckIpInternet := l_xe.GetAttribute('Internet');
        m_strCheckIpServer := l_xe.GetAttribute('Server');
        m_strCheckIpPort := l_xe.GetAttribute('Port');
        m_strCheckIpUsername := l_xe.GetAttribute('Username');
        m_strCheckIpPassword := l_xe.GetAttribute('Password');
        m_strCheckIpGet := l_xe.GetAttribute('Get');
        m_strCheckIpExcludeIpAddresses := l_xe.GetAttribute('ExcludeIpAddresses');
      end else if ('Account' = l_xe.m_strName) then begin
        m_acc.Load(l_xe);
      end;
    end;

    // Usually a log like this would go at the top of the method. This is a
    // little different though because the log option needs to be loaded before
    // the attempt to log occurs.
    LogMethod('Loading.');

    LogOptions(l_xeRoot);
  finally
    FreeAndNil(l_xeRoot);
  end;
end;

procedure TIpRightService.Log(p_str: string);
var
  filename: string;
  filestream: TFileStream;
begin
  filename := ExtractFilePath(ParamStr(0)) + LOG_FILENAME;
  if ('1' <> m_strLog) then begin
    exit;
  end;
  // Make sure there is a log file that we can log to.
  if (not FileExists(filename)) then begin
    try
      filestream := TFileStream.Create(filename, (fmCreate or fmShareDenyWrite));
    finally
      FreeAndNil(filestream);
    end;
  end;
  filestream := TFileStream.Create(filename, fmOpenReadWrite or fmShareDenyWrite);
  try
    filestream.Seek(0, soFromEnd);
    filestream.Position := filestream.Size;
    p_str := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now()) + ' ' + p_str + #$D#$A;
		filestream.WriteBuffer(pchar(p_str)^, length(p_str));
  finally
    FreeAndNil(filestream);
  end;
end;

procedure TIpRightService.m_csCheckIpAddressDisconnect(
  p_objSender: TObject;
  p_sck: TCustomWinSocket
);
var
  l_sl: TStringList;
  l_str: string;
  l_strHostNames: string;
  l_i: integer;
  l_hst: c_Host;
  l_slExcludeIpAddress: TStringList;
begin
  LogMethod('Check IP address socket disconnected.');
  l_sl := TStringList.Create();
  try
    l_sl.Text := m_strCheckIpReply;
    // remove header.
    while (l_sl.Count > 0) and ('' <> l_sl.Strings[0]) do begin
      l_sl.Delete(0);
    end;
    // remove the blank line between the header and the body.
    if (l_sl.Count > 0) then begin
      l_sl.Delete(0);
    end;
    // now we can get ip addresses from the body of the reply.
    l_sl.Text := GetIpAddresses(l_sl.Text);
    l_sl.Sorted := true;

    // exclude any known not right ip addresses.
    l_slExcludeIpAddress := TStringList.Create();
    try
      l_slExcludeIpAddress.CommaText := m_strCheckIpExcludeIpAddresses;
      for l_i := l_sl.Count - 1 downto 0 do begin
				if (- 1 <> l_slExcludeIpAddress.IndexOf(l_sl.Strings[l_i])) then begin
          l_sl.Delete(0);
        end;
      end;
    finally
      FreeAndNil(l_slExcludeIpAddress);
    end;

    if (0 = l_sl.Count) then begin
      Log('Got no IP addresses.');
      EnableTimer();
      exit;
    end;

    if (l_sl.Count > 1) then begin
      Log('Got too many IP addresses:'#$D#$A + l_sl.Text);
      EnableTimer();
      exit;
    end;

    l_str := l_sl.Strings[0];

  finally
    FreeAndNil(l_sl);
  end;

  Log('Got IP address "' + l_str + '".');

  l_strHostNames := '';
  for l_i := 0 to m_acc.m_olHost.Count - 1 do begin
    l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
    if (('1' <> l_hst.m_strDisabled) and (l_str <>
        l_hst.m_strIpAddress)) then begin
      if ('' <> l_strHostNames) then begin
        l_strHostNames := l_strHostNames + ',';
      end;
      l_strHostNames := l_strHostNames + l_hst.m_strName;
    end;
  end;
	if ('' <> l_strHostNames) then begin
    m_strIpAddress := l_str;
    m_strHostNames := l_strHostNames;
    Log('Out of date hosts: ' + m_strHostNames);
    UpdateIpAddress();
  end else begin
    EnableTimer();
  end;
end;

procedure TIpRightService.m_csCheckIpAddressRead(
  p_objSender: TObject;
  p_sck: TCustomWinSocket
);
var
  l_str: string;
begin
  LogMethod('Reading from check IP address socket.');
  l_str := p_sck.ReceiveText();
  if ('1' = m_strLogCheck) then begin
    Log('Reading: ' + l_str);
  end;
  m_strCheckIpReply := m_strCheckIpReply + l_str
end;

procedure TIpRightService.m_csCheckIpAddressWrite(
  p_objSender: TObject;
  p_sck: TCustomWinSocket
);
var
  l_str: string;
  l_strUsernamePassword: string;
  l_strGet: string;
begin
  LogMethod('Writing to check IP address socket.');

  if (('' <> m_strCheckIpUsername) or ('' <> m_strCheckIpPassword)) then begin
    l_strUsernamePassword := StringToBase64(m_strCheckIpUsername + ':' +
         m_strCheckIpPassword);
	end else begin
    l_strUsernamePassword := '';
  end;

  // Make sure there is at least a "/" in our get.
  l_strGet := m_strCheckIpGet;
  if ('' = l_strGet) then begin
    l_strGet := '/';
  end;

  l_str := 'GET ' + l_strGet + ' HTTP/1.0'#$D#$A'Host: ' +
      m_strCheckIpServer + #$D#$A;

  if ('' <> l_strUsernamePassword) then begin
    l_str := l_str + 'Authorization: Basic ' + l_strUsernamePassword + #$D#$A;
  end;

  if ('1' = m_strLogCheck) then begin
    Log('Writing: ' + l_str);
  end;
  
  p_sck.SendText(l_str + #$D#$A);
end;

procedure TIpRightService.m_csUpdateIpAddressDisconnect(
  p_objSender: TObject;
  p_sck: TCustomWinSocket
);
var
  l_str: string;
  l_sl: TStringList;
  l_strResultCode: string;
  l_hst: c_Host;
  l_i: integer;
  l_bSave: boolean;
begin
  LogMethod('Update IP address socket disconnected.');
  // see if we get an ok response for each of the host names.
  l_sl := TStringList.Create();
	try
    l_sl.Text := m_strUpdateIpReply;
    // remove header.
    while (l_sl.Count > 0) and ('' <> l_sl.Strings[0]) do begin
      l_str := l_sl.Strings[0];
      while ('' <> l_str) do begin
        if ('401' = Trim(ExtractWord(l_str))) then begin
          Log('Unauthorized. Check update server, username, and password.');
          Log('Disabling update.');
          m_acc.m_strDisabled := '1';
          Save();
          EnableTimer();
          exit;
        end;
      end;
      l_sl.Delete(0);
    end;
    // remove the blank line between the header and the body.
    if (l_sl.Count > 0) then begin
      l_sl.Delete(0);
    end;
    l_bSave := false;
    l_str := m_strIpAddress;
    for l_i := 0 to m_acc.m_olHost.Count - 1 do begin
      l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
      if (('1' <> l_hst.m_strDisabled) and (l_str <>
          l_hst.m_strIpAddress) and (l_sl.Count > 0)) then begin
        l_strResultCode := l_sl.Strings[0];
        l_sl.Delete(0);
        l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
        l_hst.m_strResultCode := l_strResultCode;
        Log('Result status for ' + l_hst.m_strName + ': ' + l_strResultCode);
//Normal Result Codes
        if ('ok' = l_strResultCode) then begin // The update was successful.
          Log('The update was successful.');
          // if ok save change.
          Log('Update IP address for ' + l_hst.m_strName + ' changed from "' +
              l_hst.m_strIpAddress + '" to "' + l_str + '".');
          l_hst.m_strIpAddress := l_str;
					l_hst.m_strUpdated := FormatDateTime('', Now());
        end else if ('nochange' = l_strResultCode) then begin // No changes were made to the hostname(s). Continual updates with no changes will lead to blocked clients.
          Log('No changes were made to the hostname(s). Continual updates with no changes will lead to blocked clients.');
          // if nochange save change - ip must have been corrected externally.
          Log('Update IP address for ' + l_hst.m_strName + ' changed from "' +
              l_hst.m_strIpAddress + '" to "' + l_str + '".');
          l_hst.m_strIpAddress := l_str;
          l_hst.m_strUpdated := FormatDateTime('', Now());
//Input Error Result Codes
        end else if ('nofqdn' = l_strResultCode) then begin // No valid FQDN (fully qualified domain name) was specified.
          Log('No valid FQDN (fully qualified domain name) was specified.');
          Log('Disabling host.');
          l_hst.m_strDisabled := '1';
        end else if ('nohost' = l_strResultCode) then begin // An invalid hostname was specified. This due to the fact the hostname has not been created in the system. Creating new host names via clients is not supported.
          Log('An invalid hostname was specified. This due to the fact the hostname has not been created in the system. Creating new host names via clients is not supported.');
          Log('Disabling host.');
          l_hst.m_strDisabled := '1';
        end else if ('abuse' = l_strResultCode) then begin // The hostname specified has been blocked for abuse.
          Log('The hostname specified has been blocked for abuse.');
          Log('Disabling host.');
          l_hst.m_strDisabled := '1';
//System Error Result Codes
        end else if ('unauth' = l_strResultCode) then begin // The username specified is not authorized to update this hostname and domain.
          Log('The username specified is not authorized to update this hostname and domain.');
          Log('Disabling host.');
          l_hst.m_strDisabled := '1';
        end else if ('blocked' = l_strResultCode) then begin // The dynamic update client (specified by the user-agent) has been blocked from the system.
          Log('The dynamic update client (specified by the user-agent) has been blocked from the system.');
          Log('Disabling host.');
          l_hst.m_strDisabled := '1';
        end else if ('notdyn' = l_strResultCode) then begin // The hostname specified has not been marked as a dynamic host. Hosts must be marked as dynamic in the system in order to be updated via clients. This prevents unwanted or accidental updates.
          Log('The hostname specified has not been marked as a dynamic host. Hosts must be marked as dynamic in the system in order to be updated via clients. This prevents unwanted or accidental updates.');
          Log('Disabling host.');
          l_hst.m_strDisabled := '1';
        end;
        l_bSave := true;
      end;
    end;
    if (l_bSave) then begin
			Save();
    end;
  finally
    FreeAndNil(l_sl);
  end;
  EnableTimer();
end;

procedure TIpRightService.m_csUpdateIpAddressRead(
  p_objSender: TObject;
  p_sck: TCustomWinSocket
);
var
  l_str: string;
begin
  LogMethod('Reading from update IP address socket.');
  l_str := p_sck.ReceiveText();
  if ('1' = m_strLogUpdate) then begin
    Log('Reading: ' + l_str);
  end;
  m_strUpdateIpReply := m_strUpdateIpReply + l_str
end;

procedure TIpRightService.m_csUpdateIpAddressWrite(
  p_objSender: TObject;
  p_sck: TCustomWinSocket
);
var
  l_str: string;
  l_strUsernamePassword: string;
  l_strMxMxPri: string;
begin
  LogMethod('Writing to update IP address socket.');
  l_strUsernamePassword := StringToBase64(m_acc.m_strUsername + ':' +
       m_acc.m_strPassword);

  // Task 51.

  if ('1' = m_acc.m_strMx) then begin
		l_strMxMxPri := '&mx=ON&mxpri=' + IntToStr(StrToIntDef(m_acc.m_strMxPri,
        0));
  end else begin
    l_strMxMxPri := '';
  end;

  l_str := 'GET /visitors/update.html?hostname=' + m_strHostNames +
      '&myip=' + m_strIpAddress + l_strMxMxPri + ' HTTP/1.0'#$D#$A'Host: ' +
			m_acc.m_strServer + #$D#$A'Authorization: Basic ' +
			l_strUsernamePassword + #$D#$A +
			'User-Agent: IP Right/' + CLIENT_VERSION + ' ' + CLIENT_EMAIL + #$D#$A;
	if ('1' = m_strLogUpdate) then begin
    Log('Writing: ' + l_str);
  end;
  p_sck.SendText(l_str + #$D#$A);
end;

procedure TIpRightService.m_tmrInterval(
  p_objSender: TObject
);
begin
  if (0 = m_nTicker) then begin
    CheckIpAddress();
  end else begin
    dec(m_nTicker);
  end;
end;

procedure TIpRightService.Save();
var
  filestream: TFileStream;
  l_xeRoot: c_XMLElement;
  l_xe: c_XmlElement;
begin
  LogMethod('Saving.');
  l_xeRoot := c_XMLElement.Create('IpRight');
  try
    l_xe := l_xeRoot.AddElement('Log');
		l_xe.SetAttribute('Enabled', m_strLog);
    l_xe.SetAttribute('Methods', m_strLogMethod);
    l_xe.SetAttribute('Options', m_strLogOption);
    l_xe.SetAttribute('Checks', m_strLogCheck);
    l_xe.SetAttribute('Updates', m_strLogUpdate);
    l_xe := l_xeRoot.AddElement('Check');
    l_xe.SetAttribute('Enabled', m_strCheckIp);
    l_xe.SetAttribute('Tick', m_strCheckIpTick);
    l_xe.SetAttribute('Internet', m_strCheckIpInternet);
    l_xe.SetAttribute('Server', m_strCheckIpServer);
    l_xe.SetAttribute('Port', m_strCheckIpPort);
    l_xe.SetAttribute('Username', m_strCheckIpUsername);
    l_xe.SetAttribute('Password', m_strCheckIpPassword);
    l_xe.SetAttribute('Get', m_strCheckIpGet);
    l_xe.SetAttribute('ExcludeIpAddresses', m_strCheckIpExcludeIpAddresses);
    m_acc.Save(l_xeRoot);
    filestream := TFileStream.Create(ExtractFilePath(ParamStr(0)) + XML_FILENAME, (fmCreate or fmShareDenyWrite));
    try
      l_xeRoot.SaveToStream(filestream, '');
    finally
      FreeAndNil(filestream);
    end;
    LogOptions(l_xeRoot);
  finally
    FreeAndNil(l_xeRoot);
  end;
end;

procedure TIpRightService.ServiceExecute(Sender: TService);
begin
  m_acc := c_Account.Create();
  Load();
  m_tmrCheckIpAddress := TTimer.Create(nil);
  m_tmrCheckIpAddress.Interval := 1000;
  m_tmrCheckIpAddress.OnTimer := m_tmrInterval;
  m_tmrCheckIpAddress.Enabled := true;

  m_ss := TServerSocket.Create(nil);
	m_ss.Port := CONFIG_PORT;
  m_ss.OnClientError := m_ssClientError;
  m_ss.OnClientRead := m_ssClientRead;
  m_ss.Active := true;

  ServiceThread.ProcessRequests(true);
end;

procedure TIpRightService.UpdateIpAddress(
);
begin
  LogMethod('Updating IP address.');

  if ('1' = m_acc.m_strDisabled) then begin
    Log('Updating is disabled.');
    EnableTimer();
    exit;
  end;

  Log('Updating hosts: ' + m_strHostNames);
  FreeAndNil(m_csUpdateIpAddress);
  m_strUpdateIpReply := '';
  m_csUpdateIpAddress := TClientSocket.Create(nil);
  m_csUpdateIpAddress.Host := m_acc.m_strServer;
  m_csUpdateIpAddress.Port := StrToIntDef(m_acc.m_strPort, 80);
  m_csUpdateIpAddress.OnWrite := m_csUpdateIpAddressWrite;
  m_csUpdateIpAddress.OnRead := m_csUpdateIpAddressRead;
  m_csUpdateIpAddress.OnDisconnect := m_csUpdateIpAddressDisconnect;
  m_csUpdateIpAddress.OnError := m_csUpdateIpAddressError;
  m_csUpdateIpAddress.Open();
end;

procedure TIpRightService.ServiceShutdown(Sender: TService);
begin
  FreeAndNil(m_ss);
  FreeAndNil(m_acc);
end;

procedure c_Host.Load(
  const p_xe: c_XmlElement
);
begin
  m_strDisabled := p_xe.GetAttribute('Disabled');
  m_strName := p_xe.GetAttribute('Name');
  m_strIpAddress := p_xe.GetAttribute('IpAddress');
  m_strUpdated := p_xe.GetAttribute('Updated');
  m_strResultCode := p_xe.GetAttribute('ResultCode');
end;

procedure c_Host.Save(
  const p_xe: c_XmlElement
);
var
  l_xe: c_XmlElement;
begin
  l_xe := p_xe.AddElement('Host');
  l_xe.SetAttribute('Disabled', m_strDisabled);
  l_xe.SetAttribute('Name', m_strName);
  l_xe.SetAttribute('IpAddress', m_strIpAddress);
  l_xe.SetAttribute('Updated', m_strUpdated);
  l_xe.SetAttribute('ResultCode', m_strResultCode);
end;

procedure TIpRightService.LogMethod(
  const p_str: string
);
begin
  if ('1' = m_strLogMethod) then begin
    Log(p_str);
  end;
end;

procedure TIpRightService.LogOptions(
  const p_xe: c_XmlElement
);
begin
  if ('1' = m_strLogOption) then begin
    Log(p_xe.AsString);
  end;
end;

constructor c_Account.Create(
);
begin
  m_olHost := TObjectList.Create();
end;

destructor c_Account.Destroy(
);
begin
  FreeAndNil(m_olHost);
  inherited;
end;

procedure c_Account.Load(
  const p_xe: c_XmlElement
);
var
  l_i: integer;
  l_xe: c_XmlElement;
  l_hst: c_Host;
begin
  m_strDisabled := p_xe.GetAttribute('Disabled');
  m_strServer := 'www.dnspark.com'; //p_xe.GetAttribute('Server');
  m_strPort := '80'; //p_xe.GetAttribute('Port');
  m_strUsername := p_xe.GetAttribute('Username');
  m_strPassword := p_xe.GetAttribute('Password');
  m_strMx := p_xe.GetAttribute('Mx');
  m_strMxPri := p_xe.GetAttribute('MxPri');
  for l_i := 0 to p_xe.m_strlElement.Count - 1 do begin
    l_xe := p_xe.GetElement(l_i);
    if ('Host' = l_xe.m_strName) then begin
      l_hst := c_Host.Create();
      try
        l_hst.Load(l_xe);
        m_olHost.Add(l_hst);
      except
        FreeAndNil(l_hst);
      end;
    end;
  end;
end;

procedure c_Account.Save(
  const p_xe: c_XmlElement
);
var
  l_i: integer;
  l_xe: c_XmlElement;
begin
  l_xe := p_xe.AddElement('Account');
  l_xe.SetAttribute('Disabled', m_strDisabled);
//  l_xe.SetAttribute('Server', m_strServer);
//  l_xe.SetAttribute('Port', m_strPort);
  l_xe.SetAttribute('Username', m_strUsername);
  l_xe.SetAttribute('Password', m_strPassword);
  l_xe.SetAttribute('Mx', m_strMx);
  l_xe.SetAttribute('MxPri', m_strMxPri);
  for l_i := 0 to m_olHost.Count - 1 do begin
    (m_olHost.Items[l_i] as c_Host).Save(l_xe);
  end;
end;

const
  ERROR: array[eeGeneral..eeAccept] of string = (
    'The socket received an error message that does not fit into any of the following categories.',
    'An error occurred when trying to write to the socket connection.',
    'An error occurred when trying to read from the socket connection.',
    'A connection request that was already accepted could not be completed.',
    'An error occurred when trying to close a connection.',
    'A problem occurred when trying to accept a client connection request.');

procedure TIpRightService.m_csCheckIpAddressError(
  p_objSender: TObject;
  p_cws: TCustomWinSocket;
  p_ee: TErrorEvent;
  var p_nErrorCode: integer
);
begin
  LogMessage(ERROR[p_ee]);
  Log(ERROR[p_ee]);
  p_nErrorCode := 0;
  EnableTimer();
end;

procedure TIpRightService.m_csUpdateIpAddressError(p_objSender: TObject;
  p_cws: TCustomWinSocket; p_ee: TErrorEvent; var p_nErrorCode: integer);
begin
  LogMessage(ERROR[p_ee]);
  Log(ERROR[p_ee]);
  p_nErrorCode := 0;
  EnableTimer();
end;

procedure TIpRightService.m_ssClientError(
  p_objSender: TObject;
  p_cws: TCustomWinSocket;
  p_ee: TErrorEvent;
  var p_nErrorCode: integer
);
begin
  LogMessage(ERROR[p_ee]);
  Log(ERROR[p_ee]);
  p_nErrorCode := 0;
end;

procedure TIpRightService.m_ssClientRead(
  p_objSender: TObject;
  p_cws: TCustomWinSocket
);
const
	HOST = 'host_';
	HOST_LENGTH = length(HOST);
	GET = 'GET ';
	GET_LENGTH = length(GET);
	TAIL = #$D#$A#$D#$A;
	TAIL_LENGTH = length(TAIL);
var
  hosts: string;
  response: string;
	l_str: string;
	l_i: integer;
	l_hst: c_Host;
	l_strName: string;
	l_strValue: string;
	l_n: integer;
	l_strlHostEnabled: TStringList;
	l_strlHostName: TStringList;
	l_strlHostAddress: TStringList;
	l_strlHostUpdated: TStringList;
	l_strlHostResult: TStringList;
	l_strGet: string;

  function Checkbox(p_label: string; p_name: string; p_value: boolean): string;
  var
    checked: string;
  begin
    if (p_value) then begin
      checked := 'checked="checked" ';
    end else begin
      checked := '';
    end;
    result := '<label for="' + p_name + '">' + p_label + '</label><input ' + checked + 'id="' + p_name + '" name="' + p_name + '" type="checkbox" />';
  end;

  function Text(p_label: string; p_name: string; p_value: string): string;
  begin
    result := '<label for="' + p_name + '">' + p_label + '</label><input id="' + p_name + '" name="' + p_name + '" type="text" value="' + p_value + '" />';
  end;

  function Password(p_label: string; p_name: string; p_value: string): string;
  begin
    result := '<label for="' + p_name + '">' + p_label + '</label><input id="' + p_name + '" name="' + p_name + '" type="password" value="' + p_value + '" />';
  end;

begin
	l_str := '';
	repeat
		l_str := l_str + p_cws.ReceiveText();
	until (TAIL = copy(l_str, length(l_str) - (TAIL_LENGTH - 1), length(TAIL)));
		// Expect "GET " then some path and filename then a "?" then our name/value
		// pairs then a space.
    if (GET = copy(l_str, 1, GET_LENGTH)) then begin
      delete(l_str, 1, GET_LENGTH);
      l_i := pos('?', l_str);
      if (0 <> l_i) then begin

        // Grab the requested filename from the url.
        l_strGet := copy(l_str, 1, l_i - 1);
        delete(l_str, 1, l_i);

        if ('/commit.html' = l_strGet) then begin

          l_i := pos(' ', l_str);
          if (0 <> l_i) then begin
            delete(l_str, l_i, length(l_str) - l_i + 1);

            m_strLog := '0';
            m_strLogMethod := '0';
            m_strLogOption := '0';
            m_strLogCheck := '0';
            m_strLogUpdate := '0';
            m_strCheckIp := '0';
            m_strCheckIpInternet := '0';
            m_acc.m_strDisabled := '1';
            m_acc.m_strMx := '0';

            l_strlHostEnabled := nil;
            l_strlHostName := nil;
            l_strlHostAddress := nil;
            l_strlHostUpdated := nil;
            l_strlHostResult := nil;
            try

              l_strlHostEnabled := TStringList.Create();
              l_strlHostName := TStringList.Create();
              l_strlHostAddress := TStringList.Create();
              l_strlHostUpdated := TStringList.Create();
              l_strlHostResult := TStringList.Create();

              for l_i := 0 to m_acc.m_olHost.Count - 1 do begin
                l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
                l_strlHostEnabled.Add('0');
                l_strlHostName.Add(l_hst.m_strName);
                l_strlHostAddress.Add(l_hst.m_strIpAddress);
                l_strlHostUpdated.Add(l_hst.m_strUpdated);
                l_strlHostResult.Add(l_hst.m_strResultCode);
              end;

              while ('' <> l_str) do begin
                l_i := pos('=', l_str);
                if (0 = l_i) then begin
                  break;
                end;
                l_strName := copy(l_str, 1, l_i - 1);
                delete(l_str, 1, l_i);
                l_i := pos('&', l_str);
                if (0 = l_i) then begin
                  l_strValue := l_str;
                  l_str := '';
                end else begin
                  l_strValue := copy(l_str, 1, l_i - 1);
                  delete(l_str, 1, l_i);
                end;
                l_strValue := Epacse(l_strValue);
                if (('log_enabled' = l_strName) and ('on' = l_strValue)) then begin
                  m_strLog := '1';
                end else if (('log_methods' = l_strName) and ('on' = l_strValue)) then begin
                  m_strLogMethod := '1';
                end else if (('log_options' = l_strName) and ('on' = l_strValue)) then begin
                  m_strLogOption := '1';
                end else if (('log_checks' = l_strName) and ('on' = l_strValue)) then begin
                  m_strLogCheck := '1';
                end else if (('log_updates' = l_strName) and ('on' = l_strValue)) then begin
                  m_strLogUpdate := '1';
                end else if (('check_enabled' = l_strName) and ('on' = l_strValue)) then begin
                  m_strCheckIp := '1';
                end else if ('check_tick' = l_strName) then begin
                  l_n := StrToIntDef(l_strValue, - 1);
                  if (l_n >= 0) then begin
                    m_strCheckIpTick := IntToStr(l_n);
                  end;
                end else if (('check_internet' = l_strName) and ('on' = l_strValue)) then begin
                  m_strCheckIpInternet := '1';
                end else if ('check_server' = l_strName) then begin
                  m_strCheckIpServer := l_strValue;
                end else if ('check_port' = l_strName) then begin
                  l_n := StrToIntDef(l_strValue, - 1);
                  if ((l_n >= low(word)) and (l_n <= high(word))) then begin
                    m_strCheckIpPort := IntToStr(l_n);
                  end;
                end else if ('check_username' = l_strName) then begin
                  m_strCheckIpUsername := l_strValue;
                end else if ('check_password' = l_strName) then begin
                  m_strCheckIpPassword := l_strValue;
                end else if ('check_get' = l_strName) then begin
                  m_strCheckIpGet := l_strValue;
                end else if ('check_exclude' = l_strName) then begin
                  m_strCheckIpExcludeIpAddresses := l_strValue;
                end else if (('account_enabled' = l_strName) and ('on' = l_strValue)) then begin
                  m_acc.m_strDisabled := '0';
                end else if ('account_username' = l_strName) then begin
                  m_acc.m_strUsername := l_strValue;
                end else if ('account_password' = l_strName) then begin
                  m_acc.m_strPassword := l_strValue;
                end else if (('account_mail' = l_strName) and ('on' = l_strValue)) then begin
                  m_acc.m_strMx := '1';
                end else if ('account_priority' = l_strName) then begin
                  l_n := StrToIntDef(l_strValue, - 1);
                  if (l_n > 0) then begin
                    m_acc.m_strMxPri := IntToStr(l_n);
                  end;
                end else if (HOST = copy(l_strName, 1, HOST_LENGTH)) then begin
                  delete(l_strName, 1, HOST_LENGTH);
                  l_i := pos('_', l_strName);
                  if (0 <> l_i) then begin
                    l_n := StrToIntDef(copy(l_strName, 1, l_i - 1), - 1);
                    delete(l_strName, 1, l_i);
                    if (l_n >= 0) then begin
                      while (l_strlHostEnabled.Count <= l_n) do begin
                        l_strlHostEnabled.Add('0');
                        l_strlHostName.Add('');
                        l_strlHostAddress.Add('');
                        l_strlHostUpdated.Add('');
                        l_strlHostResult.Add('');
                      end;
                      if (('enabled' = l_strName) and ('on' = l_strValue)) then begin
                        l_strlHostEnabled.Strings[l_n] := '1';
                      end else if ('name' = l_strName) then begin
                        l_strlHostName.Strings[l_n] := l_strValue;
                      end;
                    end;
                  end;
                end;
              end;

              for l_i := 0 to l_strlHostEnabled.Count - 1 do begin
                if (l_i < m_acc.m_olHost.Count) then begin
                  l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
                  if ('1' = l_strlHostEnabled.Strings[l_i]) then begin
                    l_hst.m_strDisabled := '0';
                  end else begin
                    l_hst.m_strDisabled := '1';
                  end;
                  l_hst.m_strName := l_strlHostName.Strings[l_i];
                  l_hst.m_strIpAddress := l_strlHostAddress.Strings[l_i];
                  l_hst.m_strUpdated := l_strlHostUpdated.Strings[l_i];
                  l_hst.m_strResultCode := l_strlHostResult.Strings[l_i];
                end else begin
                  l_hst := c_Host.Create();
                  try
                    if ('1' = l_strlHostEnabled.Strings[l_i]) then begin
                      l_hst.m_strDisabled := '0';
                    end else begin
                      l_hst.m_strDisabled := '1';
                    end;
                    l_hst.m_strName := l_strlHostName.Strings[l_i];
                    l_hst.m_strIpAddress := l_strlHostAddress.Strings[l_i];
                    l_hst.m_strUpdated := l_strlHostUpdated.Strings[l_i];
                    l_hst.m_strResultCode := l_strlHostResult.Strings[l_i];
                    m_acc.m_olHost.Add(l_hst);
                  except
                    FreeAndNil(l_hst);
                    raise;
                  end;
                end;
              end;

              for l_i := m_acc.m_olHost.Count - 1 downto 0 do begin
                l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
                if ('' = l_hst.m_strName) then begin
                  m_acc.m_olHost.Delete(l_i);
                end;
              end;

            finally
              FreeAndNil(l_strlHostResult);
              FreeAndNil(l_strlHostUpdated);
              FreeAndNil(l_strlHostAddress);
              FreeAndNil(l_strlHostName);
              FreeAndNil(l_strlHostEnabled);
            end;
            Save();
          end;

        end;
      end;
    end;
    hosts := '';
    for l_i := 0 to m_acc.m_olHost.Count - 1 do begin
      l_hst := m_acc.m_olHost.Items[l_i] as c_Host;
      hosts :=
        hosts +
        '            <li>' + Checkbox('Host', 'host_' + IntToStr(l_i) + '_enabled', '1' <> l_hst.m_strDisabled) + #$D#$A +
        '              <ul>' + #$D#$A +
        '                <li>' + Text('Name', 'host_' + IntToStr(l_i) + '_name', l_hst.m_strName) + '</li>' + #$D#$A +
        '              </ul>' + #$D#$A +
        '            </li>' + #$D#$A;
    end;
		hosts :=
      hosts +
      '            <li>' + Checkbox('Host', 'host_' + IntToStr(m_acc.m_olHost.Count) + '_enabled', False) + #$D#$A +
      '              <ul>' + #$D#$A +
      '                <li>' + Text('Name', 'host_' + IntToStr(m_acc.m_olHost.Count) + '_name', '') + '</li>' + #$D#$A +
      '              </ul>' + #$D#$A +
      '            </li>' + #$D#$A;
  response :=
    '<!DOCTYPE html>' + #$D#$A +
    '<html>' + #$D#$A +
    '  <head>' + #$D#$A +
    '    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">' + #$D#$A +
    '    <title>IP Right Version ' + CLIENT_VERSION + ' ' + CLIENT_COMPANY + '</title>' + #$D#$A +
    '    <style>' + #$D#$A +
    '      body' + #$D#$A +
    '      {' + #$D#$A +
    '        margin: 0px;' + #$D#$A +
    '        font-family: "wf_SegoeUILight", "wf_SegoeUI", "Segoe UI Light", "Segoe WP Light", "Segoe UI", "Segoe", "Segoe WP", "Tahoma", "Verdana", "Arial", "sans-serif";' + #$D#$A +
    '        font-weight: 300;' + #$D#$A +
    '        letter-spacing: 0.02em;' + #$D#$A +
    '      }' + #$D#$A +
    '      div.header' + #$D#$A +
    '      {' + #$D#$A +
    '        background-color: #1570a6;' + #$D#$A +
    '        padding: 10px 0;' + #$D#$A +
    '        color: #fff;' + #$D#$A +
    '        -moz-box-shadow: 0px 2px 4px #ccc;' + #$D#$A +
    '        -webkit-box-shadow: 0px 2px 4px #ccc;' + #$D#$A +
    '        box-shadow: 0px 2px 4px #ccc;' + #$D#$A +
    '        text-align: center;' + #$D#$A +
    '      }' + #$D#$A +
    '      div.footer_wrapper' + #$D#$A +
    '      {' + #$D#$A +
    '        background-color: #1570a6;' + #$D#$A +
    '        padding: 10px 0;' + #$D#$A +
    '        color: #fff;' + #$D#$A +
    '        -moz-box-shadow: 0px -2px 4px #ccc;' + #$D#$A +
    '        -webkit-box-shadow: 0px -2px 4px #ccc;' + #$D#$A +
    '        box-shadow: 0px -2px 4px #ccc;' + #$D#$A +
    '        text-align: center;' + #$D#$A +
    '      }' + #$D#$A +
    '      div.footer' + #$D#$A +
    '      {' + #$D#$A +
    '        width: 1020px;' + #$D#$A +
    '        margin: 0px auto;' + #$D#$A +
    '      }' + #$D#$A +
    '      div.footer a' + #$D#$A +
    '      {' + #$D#$A +
    '        color: #fff;' + #$D#$A +
    '      }' + #$D#$A +
    '      div.content_wrapper' + #$D#$A +
    '      {' + #$D#$A +
    '        width: 1020px;' + #$D#$A +
    '        margin: 0px auto;' + #$D#$A +
    '        border-radius: 5px;' + #$D#$A +
    '      }' + #$D#$A +
    '      div.content' + #$D#$A +
    '      {' + #$D#$A +
    '        padding: 2px 20px 20px 20px;' + #$D#$A +
    '      }' + #$D#$A +
    '      input' + #$D#$A +
    '      {' + #$D#$A +
    '        margin-left: 10px;' + #$D#$A +
    '        padding-left: 5px;' + #$D#$A +
    '        padding-right: 5px;' + #$D#$A +
    '        font-size: 0.8em;' + #$D#$A +
    '        font-weight: 300;' + #$D#$A +
    '        font-family: "wf_SegoeUILight", "wf_SegoeUI", "Segoe UI Light", "Segoe WP Light", "Segoe UI", "Segoe", "Segoe WP", "Tahoma", "Verdana", "Arial", "sans-serif";' + #$D#$A +
    '        font-weight: 300;' + #$D#$A +
    '        letter-spacing: 0.02em;' + #$D#$A +
    '      }' + #$D#$A +
    '      input[type="checkbox"]' + #$D#$A +
    '      {' + #$D#$A +
    '        width: 0.7em;' + #$D#$A +
    '        height: 0.7em;' + #$D#$A +
    '      }' + #$D#$A +
    '      ul li ul li label' + #$D#$A +
    '      {' + #$D#$A +
    '        white-space: nowrap;' + #$D#$A +
    '        overflow: visible;' + #$D#$A +
    '        display: inline-block;' + #$D#$A +
    '        text-align: right;' + #$D#$A +
    '        min-width: 190px;' + #$D#$A +
    '      }' + #$D#$A +
    '      ul' + #$D#$A +
    '      {' + #$D#$A +
    '        list-style: none;' + #$D#$A +
    '      }' + #$D#$A +
    '      ul li' + #$D#$A +
    '      {' + #$D#$A +
    '        font-size: 1.8em;' + #$D#$A +
    '        border-bottom: 1px solid #ccc;' + #$D#$A +
    '        padding-bottom: 20px;' + #$D#$A +
    '        margin-bottom: 10px;' + #$D#$A +
    '      }' + #$D#$A +
    '      ul li ul' + #$D#$A +
    '      {' + #$D#$A +
    '        border: 0px solid blue;' + #$D#$A +
    '        column-count: 2;' + #$D#$A +
    '        column-gap: 10px;' + #$D#$A +
    '        -webkit-column-count: 2;' + #$D#$A +
    '        -webkit-column-gap: 10px;' + #$D#$A +
    '        -moz-column-count: 2;' + #$D#$A +
    '        -moz-column-gap: 10px;' + #$D#$A +
    '        -ms-column-count: 2;' + #$D#$A +
    '        -ms-column-gap: 10px;' + #$D#$A +
    '        -o-column-count: 2;' + #$D#$A +
    '        -o-column-gap: 10px;' + #$D#$A +
    '      }' + #$D#$A +
    '      ul li ul li' + #$D#$A +
    '      {' + #$D#$A +
    '        padding: 5px 0;' + #$D#$A +
    '        font-size: 0.8em;' + #$D#$A +
    '        border-bottom: 0px;' + #$D#$A +
    '        margin-bottom: 0;' + #$D#$A +
    '      }' + #$D#$A +
    '    </style>' + #$D#$A +
    '  </head>' + #$D#$A +
    '  <body>' + #$D#$A +
    '    <div class="header"><h1>IP Right Version ' + CLIENT_VERSION + ' ' + CLIENT_COMPANY + '</h1></div>' + #$D#$A +
    '    <div class="content_wrapper">' + #$D#$A +
    '      <div class="content">' + #$D#$A +
    '        <form action="commit.html" method="get">' + #$D#$A +
    '          <ul>' + #$D#$A +
    '            <li>' + Checkbox('Log', 'log_enabled', '1' = m_strLog) + #$D#$A +
    '              <ul>' + #$D#$A +
    '                <li>' + Checkbox('Log Checks', 'log_checks', '1' = m_strLogCheck) + '</li>' + #$D#$A +
    '                <li>' + Checkbox('Log Methods', 'log_methods', '1' = m_strLogMethod) + '</li>' + #$D#$A +
    '                <li>' + Checkbox('Log Options', 'log_options', '1' = m_strLogOption) + '</li>' + #$D#$A +
    '                <li>' + Checkbox('Log Updates', 'log_updates', '1' = m_strLogUpdate) + '</li>' + #$D#$A +
    '              </ul>' + #$D#$A +
    '            </li>' + #$D#$A +
    '            <li>' + Checkbox('Checks', 'check_enabled', '1' = m_strCheckIp) + #$D#$A +
    '              <ul>' + #$D#$A +
    '               <li>' + Text('Interval In Seconds', 'check_tick', m_strCheckIpTick) + '</li>' + #$D#$A +
    '               <li>' + Checkbox('Internet', 'check_internet', '1' = m_strCheckIpInternet) + '</li>' + #$D#$A +
    '               <li>' + Text('Server', 'check_server', m_strCheckIpServer) + '</li>' + #$D#$A +
    '               <li>' + Text('Port', 'check_port', m_strCheckIpPort) + '</li>' + #$D#$A +
    '               <li>' + Text('Username', 'check_username', m_strCheckIpUsername) + '</li>' + #$D#$A +
    '               <li>' + Password('Password', 'check_password', m_strCheckIpPassword) + '</li>' + #$D#$A +
    '               <li>' + Text('Get', 'check_get', m_strCheckIpGet) + '</li>' + #$D#$A +
    '               <li>' + Text('Exclude', 'check_exclude', m_strCheckIpExcludeIpAddresses) + '</li>' + #$D#$A +
    '              </ul>' + #$D#$A +
    '            </li>' + #$D#$A +
    '            <li>' + Checkbox('Account', 'account_enabled', '1' <> m_acc.m_strDisabled) + #$D#$A +
    '              <ul>' + #$D#$A +
    '                <li>' + Text('Signin ID', 'account_username', m_acc.m_strUsername) + '</li>' + #$D#$A +
    '                <li>' + Password('Password', 'account_password', m_acc.m_strPassword) + '</li>' + #$D#$A +
    '                <li>' + Checkbox('Mail', 'account_mail', '1' = m_acc.m_strMx) + '</li>' + #$D#$A +
    '                <li>' + Text('Priority', 'account_priority', m_acc.m_strMxPri) + '</li>' + #$D#$A +
    '              </ul>' + #$D#$A +
    '            </li>' + #$D#$A +
    hosts +
    '          </ul>' + #$D#$A +
    '          <input type="submit">' + #$D#$A +
    '        </form>' + #$D#$A +
    '      </div>' + #$D#$A +
    '    </div>' + #$D#$A +
    '    <div class="footer_wrapper">' + #$D#$A +
    '      <div class="footer">' + #$D#$A +
    '        <p>This is free and unencumbered software released into the public domain.</p>' + #$D#$A +
    '        <p>Anyone is free to copy, modify, publish, use, compile, sell, or' + #$D#$A +
    '        distribute this software, either in source code form or as a compiled' + #$D#$A +
    '        binary, for any purpose, commercial or non-commercial, and by any' + #$D#$A +
    '        means.</p>' + #$D#$A +
    '        <p>In jurisdictions that recognize copyright laws, the author or authors' + #$D#$A +
    '        of this software dedicate any and all copyright interest in the' + #$D#$A +
    '        software to the public domain. We make this dedication for the benefit' + #$D#$A +
    '        of the public at large and to the detriment of our heirs and' + #$D#$A +
    '        successors. We intend this dedication to be an overt act of' + #$D#$A +
    '        relinquishment in perpetuity of all present and future rights to this' + #$D#$A +
    '        software under copyright law.</p>' + #$D#$A +
    '        <p>THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,' + #$D#$A +
    '        EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF' + #$D#$A +
    '        MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.' + #$D#$A +
    '        IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR' + #$D#$A +
    '        OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,' + #$D#$A +
    '        ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR' + #$D#$A +
    '        OTHER DEALINGS IN THE SOFTWARE.</p>' + #$D#$A +
    '        <p>For more information, please refer to <a href="http://unlicense.org/">http://unlicense.org/</a></p>' + #$D#$A +
    '      </div>' + #$D#$A +
    '    </div>' + #$D#$A +
    '  </body>' + #$D#$A +
    '</html>' + #$D#$A;
  p_cws.SendText
  (
        'HTTP/1.1 200 OK' + #$D#$A +
        'Content-Length: ' + IntToStr(length(response)) + #$D#$A +
        'Content-Type: text/html' + #$D#$A +
        #$D#$A +
        response
  );
  p_cws.Close();
end;

end.

