unit XmlUnit;

interface

uses
  Classes;

type
  c_xml_element = class(TObject)
  private
    // Inserts a "\" in front of any """.
    class function escape(const p_value: string): string;
    // Deletes a "\" in front of any "\"".
    class function epacse(const p_value: string): string;
  public
    m_name: string;
    m_value: string;
    m_attributes: TStringList;
    m_elements: TStringList;
  private
    function load_element(): boolean;
    procedure write_to_stream(const p_stream: TStream; const p_value: string);
  public
    function add_element(const p_name: string): c_xml_element;
		procedure set_attribute(const p_name: string; const p_value: string);
    function get_attribute(const p_name: string): string;
    function get_element(const p_i: integer): c_xml_element;
    constructor create(const p_name: string);
    destructor destroy(); override;
    procedure save_to_stream(const p_stream: TStream; const p_indent: string);
    procedure load_from_stream(const p_stm: TStream);
    function as_string(): string;
  end;

  c_xml_attribute = class(TObject)
  private
    m_value: string;
  public
    function get_value(): string;
    procedure set_value(const p_value: string);
  end;

implementation

uses
  SysUtils;

var
  u_st: TStream;
  u_ch: char;
  u_str: string;

function QryCharacter(): char;
begin
  result := u_ch;
end;

function GetCharacter(): char;
begin
  result := QryCharacter();
  u_ch := #$00;
  if (u_st.Position < u_st.Size) then begin
    u_st.ReadBuffer(u_ch, sizeof(u_ch));
  end;
end;

function EOF(): boolean;
begin
  result := (#$00 = QryCharacter());
end;

procedure Bing();
begin
  u_str := u_str + GetCharacter();
end;

function QryWord(): string;
begin
  result := u_str;
end;

function QryQuote(): boolean;
begin
  result := ((length(QryWord()) > 0) and ('"' = QryWord()[1]));
end;

function QryAlphaNumeric(): boolean;
begin
  result := ((length(QryWord()) > 0) and (QryWord()[1] in ['_', 'A'..'Z', 'a'..'z']));
end;

function GetWord(): string;
begin
  result := QryWord();
  u_str := '';
  while (QryCharacter() in [#$0A, #$0D, ' ']) do begin
    GetCharacter();
  end;
  if ('<' = QryCharacter()) then begin
    Bing();
    if ('/' <> QryCharacter()) then begin
      exit;
    end;
    Bing();
    exit;
  end;
  if ('/' = QryCharacter()) then begin
    Bing();
    if ('>' <> QryCharacter()) then begin
      exit;
    end;
    Bing();
    exit
  end;
  if ('>' = QryCharacter()) then begin
    Bing();
    exit;
  end;
  if ('=' = QryCharacter()) then begin
    Bing();
    exit;
  end;
  if ('"' = QryCharacter()) then begin
    repeat
      Bing();
      if (EOF()) then begin
        exit;
      end;
    until ('"' = QryCharacter);
    Bing();
    exit;
  end;
  if (QryCharacter() in ['_', 'A'..'Z', 'a'..'z']) then begin
    repeat
      Bing();
    until (not (QryCharacter() in ['_', '0'..'9', 'A'..'Z', 'a'..'z']));
    exit;
  end;
  if (QryCharacter() in ['0'..'9']) then begin
    repeat
      Bing();
    until (not (QryCharacter() in ['0'..'9']));
    exit;
  end;
end;

function c_xml_element.add_element(const p_name: string): c_xml_element;
begin
  result := c_xml_element.create(p_name);
  try
    m_elements.AddObject(p_name, result);
  except
    FreeAndNil(result);
    raise;
  end;
end;

constructor c_xml_element.create(const p_name: string);
begin
  m_name := p_name;
  m_attributes := TStringList.Create();
  m_elements := TStringList.Create();
  m_elements.Duplicates := dupAccept;
end;

destructor c_xml_element.destroy();
var
  i: integer;
begin
  for i := 0 to m_elements.Count - 1 do begin
    m_elements.Objects[i].Free();
    m_elements.Objects[i] := nil;
  end;
  FreeAndNil(m_elements);
  for i := 0 to m_attributes.Count - 1 do begin
    m_attributes.Objects[i].Free();
    m_attributes.Objects[i] := nil;
  end;
  FreeAndNil(m_attributes);
  inherited;
end;

function c_xml_element.get_attribute(const p_name: string): string;
var
  i: integer;
begin
  i := m_attributes.IndexOf(p_name);
  if (i = -1) then begin
    result := '';
    exit;
  end;
  result := c_xml_attribute(m_attributes.Objects[i]).get_value();
end;

function c_xml_element.get_element(const p_i: integer): c_xml_element;
begin
  if ((p_i < 0) or (p_i >= m_elements.Count)) then begin
    result := nil;
    exit;
  end;
  result := c_xml_element(m_elements.Objects[p_i]);
end;

function c_xml_element.load_element(): boolean;
var
  element_name: string;
  attribute_name: string;
  xml_element: c_xml_element;
  s: string;
begin
  result := false;
  if ('<' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  if (not QryAlphaNumeric()) then begin
    exit;
  end;
  element_name := GetWord();
  m_name := element_name;
  while (QryAlphaNumeric()) do begin
    attribute_name := GetWord();
    if ('=' <> QryWord()) then begin
      exit;
    end;
    GetWord();
    if (not QryQuote()) then begin
      exit;
    end;
    s := GetWord();
    delete(s, 1, 1);
    delete(s, length(s), 1);
    set_attribute(attribute_name, Epacse(s));
  end;
  if ('/>' = QryWord()) then begin
    GetWord();
    result := true;
    exit;
  end;
  if ('>' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  // either we get the value here or an open tag.
  while ('<' = QryWord()) do begin
    xml_element := add_element('');
    if (not xml_element.load_element()) then begin
      exit;
    end;
  end;
  if ('</' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  if (QryWord() <> element_name) then begin
    exit;
  end;
  GetWord();
  if ('>' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  result := true;
end;

procedure c_xml_element.load_from_stream(const p_stm: TStream);
begin
  u_st := p_stm;
  GetCharacter();
  GetWord();
  load_element();
end;

procedure c_xml_element.save_to_stream(const p_stream: TStream; const p_indent: string);
var
  l_i: integer;
begin
  write_to_stream(p_stream, p_indent);
  write_to_stream(p_stream, '<');
  write_to_stream(p_stream, m_name);
  for l_i := 0 to m_attributes.Count - 1 do begin
    write_to_stream(p_stream, ' ');
    write_to_stream(p_stream, m_attributes.Strings[l_i]);
    write_to_stream(p_stream, '="');
    write_to_stream(p_stream, escape(c_xml_attribute(m_attributes.Objects[l_i]).get_value()));
    write_to_stream(p_stream, '"');
  end;
  if (0 = m_elements.Count) then begin
    write_to_stream(p_stream, ' />'#$D#$A);
    exit;
  end;
  write_to_stream(p_stream, '>'#$D#$A);
  for l_i := 0 to m_elements.Count - 1 do begin
    c_xml_element(m_elements.Objects[l_i]).save_to_stream(p_stream, p_indent + '  ');
  end;
  write_to_stream(p_stream, p_indent);
  write_to_stream(p_stream, '</');
  write_to_stream(p_stream, m_name);
  write_to_stream(p_stream, '>'#$D#$A);
end;

procedure c_xml_element.set_attribute(const p_name: string; const p_value: string);
var
  i: integer;
begin
  i := m_attributes.IndexOf(p_name);
  if (i = -1) then begin
    i := m_attributes.AddObject(p_name, c_xml_attribute.Create());
  end;
  c_xml_attribute(m_attributes.Objects[i]).set_value(p_value);
end;

function c_xml_attribute.get_value(): string;
begin
  result := m_value;
end;

procedure c_xml_attribute.set_value(const p_value: string);
begin
  m_value := p_value;
end;

procedure c_xml_element.write_to_stream(const p_stream: TStream; const p_value: string);
begin
  p_stream.WriteBuffer(pchar(p_value)^, length(p_value));
end;

class function c_xml_element.escape(const p_value: string): string;
var
  i: integer;
  j: integer;
  c: cardinal; // Count of characters in string.
  d: cardinal; // Count of """'s in string.
begin
  {: Find out how many """'s and "%"'s we need to escape. }
  c := length(p_value);
  d := 0;
  for i := 1 to c do begin
    if (p_value[i] in ['%', '"', '<', '>', '&']) then begin
      inc(d);
    end;
  end;
  {: Make our resulting string the size of the original string plus the number
  of extra characters we need, which is two for each """ and "%". }
  setlength(result, c + d * 2);
  {: Copy the original string to the resulting string adding "%xx"'s where
  needed. }
  j := 1;
  for i := 1 to c do begin
    if ('"' = p_value[i]) then begin
      result[j] := '%';
      inc(j);
      result[j] := '2';
      inc(j);
      result[j] := '2';
      inc(j);
    end else if ('%' = p_value[i]) then begin
      result[j] := '%';
      inc(j);
      result[j] := '2';
      inc(j);
      result[j] := '5';
      inc(j);
    end else if ('<' = p_value[i]) then begin
      result[j] := '%';
      inc(j);
      result[j] := '3';
      inc(j);
      result[j] := 'C';
      inc(j);
    end else if ('>' = p_value[i]) then begin
      result[j] := '%';
      inc(j);
      result[j] := '3';
      inc(j);
      result[j] := 'E';
      inc(j);
    end else if ('&' = p_value[i]) then begin
      result[j] := '%';
      inc(j);
      result[j] := '2';
      inc(j);
      result[j] := '6';
      inc(j);
    end else begin
      result[j] := p_value[i];
      inc(j);
    end;
  end;

end;

class function c_xml_element.epacse(const p_value: string): string;
  function HexDigitToByte(const p_chr: char): byte;
  begin
    if (p_chr in ['a'..'z']) then begin
      result := byte(p_chr) - ord('a') + ord(#$A);
    end else if (p_chr in ['A'..'Z']) then begin
      result := byte(p_chr) - ord('A') + ord(#$A);
    end else if (p_chr in ['0'..'9']) then begin
      result := byte(p_chr) - ord('0');
    end else begin
      raise Exception.Create('Invalid hexidecimal digit.');
    end;
  end;
var
  c: cardinal;
  i: cardinal;
  j: cardinal;
begin
  c := length(p_value);
  setlength(result, c);
  i := 1;
  j := 0;
  while (i <= c) do begin
    if ('%' = p_value[i]) then begin
      inc(i);
      if (i >= c) then begin
        raise Exception.Create('Invalid hexidecimal digit.');
      end;
      inc(j);
      result[j] := char(HexDigitToByte(p_value[i]) * 16 + HexDigitToByte(p_value[i + 1]));
      inc(i, 2);
    end else begin
      inc(j);
      result[j] := p_value[i];
      inc(i);
    end;
  end;
  setlength(result, j);
end;

function c_xml_element.as_string(): string;
var
  l_ms: TMemoryStream;
  l_cb: integer;
begin
  l_ms := TMemoryStream.Create();
  try
    save_to_stream(l_ms, '');
    l_ms.Position := 0;
    l_cb := l_ms.Size;
    setlength(result, l_cb);
    l_ms.ReadBuffer(pchar(result)^, l_cb);
  finally
    FreeAndNil(l_ms);
  end;
end;

end.
