unit AccountUnit;

interface

uses
  Contnrs, XmlUnit;
  
type
  c_account = class(TObject)
  public
    m_disabled: string;
    m_server: string;
    m_port: string;
    m_username: string;
    m_password: string;
    m_hosts: TObjectList;
    constructor create();
    destructor destroy(); override;
    function ui_html(): string;
    procedure load(const p_xml_element: c_xml_element);
    procedure save(const p_xml_element: c_xml_element);
  end;

implementation

uses
  SysUtils, HostUnit, HtmlUnit;

constructor c_account.create();
begin
  m_hosts := TObjectList.Create();
end;

destructor c_account.destroy();
begin
  FreeAndNil(m_hosts);
  inherited;
end;

procedure c_account.load(const p_xml_element: c_xml_element);
var
  i: integer;
  xml_element: c_xml_element;
  host: c_host;
begin
  m_disabled := p_xml_element.get_attribute('Disabled');
  m_server := 'www.dnsdynamic.org';
  m_port := '80';
  m_username := p_xml_element.get_attribute('Username');
  m_password := p_xml_element.get_attribute('Password');
  for i := 0 to p_xml_element.m_elements.Count - 1 do begin
    xml_element := p_xml_element.get_element(i);
    if ('Host' = xml_element.m_name) then begin
      host := c_host.Create();
      try
        host.load(xml_element);
        m_hosts.Add(host);
        // We'll only be updating one host for DNSdynamic for the mean time.
        break;
      except
        FreeAndNil(host);
      end;
    end;
  end;
end;

procedure c_account.save(const p_xml_element: c_xml_element);
var
  i: integer;
  xml_element: c_xml_element;
begin
  xml_element := p_xml_element.add_element('Account');
  xml_element.set_attribute('Disabled', m_disabled);
  xml_element.set_attribute('Username', m_username);
  xml_element.set_attribute('Password', m_password);
  for i := 0 to m_hosts.Count - 1 do begin
    c_host(m_hosts.Items[i]).save(xml_element);
    // We'll only be updating one host for DNSdynamic for the mean time.
    break;
  end;
end;

function c_account.ui_html(): string;
var
  host: c_host;
begin
  result :=
    '            <li>' + c_html.input_checkbox('DNSdynamic (testing)', 'account_enabled', m_disabled <> '1') + #$D#$A +
    '              <ul>' + #$D#$A +
    '                <li>' + c_html.input_text('Signin ID', 'account_username', m_username) + '</li>' + #$D#$A +
    '                <li>' + c_html.input_password('Password', 'account_password', m_password) + '</li>' + #$D#$A +
    '              </ul>' + #$D#$A +
    '            </li>' + #$D#$A;
    // For the time being we'll only try to update one DNSdynamic.org host so only display one host in the UI.
  if (m_hosts.Count = 0) then begin
    host := c_host.Create();
    try
      host.m_disabled := '1';
      result := result + host.ui_html(0);
    finally
      FreeAndNil(host);
    end;
  end else begin
    result := result + c_host(m_hosts.Items[0]).ui_html(0);
  end;
end;

end.
