unit HostUnit;

interface

uses
  XmlUnit;

type
  c_host = class(TObject)
  public
    m_disabled: string;
    m_name: string;
    m_updated: string; // when host was last successfully updated.
    m_ip_address: string; // last ip address successfully updated.
    m_result_code: string; // last reply status
    function ui_html(p_index: integer): string;
    procedure load(const p_xml_element: c_xml_element);
    procedure save(const p_xml_element: c_xml_element);
  end;

implementation

uses
  HtmlUnit, SysUtils;

procedure c_host.load(const p_xml_element: c_xml_element);
begin
  m_disabled := p_xml_element.get_attribute('Disabled');
  m_name := p_xml_element.get_attribute('Name');
  m_ip_address := p_xml_element.get_attribute('IpAddress');
  m_updated := p_xml_element.get_attribute('Updated');
  m_result_code := p_xml_element.get_attribute('ResultCode');
end;

procedure c_host.save(const p_xml_element: c_xml_element);
var
  xml_element: c_xml_element;
begin
  xml_element := p_xml_element.add_element('Host');
  xml_element.set_attribute('Disabled', m_disabled);
  xml_element.set_attribute('Name', m_name);
  xml_element.set_attribute('IpAddress', m_ip_address);
  xml_element.set_attribute('Updated', m_updated);
  xml_element.set_attribute('ResultCode', m_result_code);
end;

function c_host.ui_html(p_index: integer): string;
begin
  result :=
    '            <li>' + c_html.input_checkbox('Host', 'host_' + IntToStr(p_index) + '_enabled', m_disabled <> '1') + #$D#$A +
    '              <ul>' + #$D#$A +
    '                <li>' + c_html.input_text('Name', 'host_' + IntToStr(p_index) + '_name', m_name) + '</li>' + #$D#$A +
    '              </ul>' + #$D#$A +
    '            </li>' + #$D#$A;

end;

end.
