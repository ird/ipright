unit XmlUnit;

interface

uses
  Classes;

type
  c_XmlElement = class(TObject)
  private

    {: Inserts a "\" in front of any """. }
    class function Escape(
      const p_str: string
    ): string;

    {: Deletes a "\" in front of andy "\"". }
    class function Epacse(
      const p_str: string
    ): string;

  public

    m_strName: string;
    m_strValue: string;
    m_strlAttribute: TStringList;
    m_strlElement: TStringList;

  private

    function LoadElement(
    ): boolean;

    procedure WriteToStream(
      const p_stm: TStream;
      const p_str: string
    );

  public

    function AddElement(
      const p_strName: string
    ): c_XmlElement;

    function QryAttribute(
      const p_strName: string
    ): boolean;

    procedure SetAttribute(
      const p_strName: string;
      const p_strValue: string
    );

    function GetAttribute(
      const p_strName: string
    ): string;

    function GetElement(
      const p_i: integer
    ): c_XmlElement;

    function GetName(
    ): string;

    constructor Create(
      const p_strName: string
    );

    destructor Destroy(
    ); override;

    procedure SaveToStream(
      const p_stm: TStream;
      const p_strIndent: string
    );

    procedure LoadFromStream(
      const p_stm: TStream
    );

    function AsString(
    ): string;

  end;

  c_XmlAttribute = class(TObject)
  private

    m_strValue: string;

  public

    function GetValue(
    ): string;

    procedure SetValue(
      const p_str: string
    );

  end;

implementation

uses
  SysUtils;

var
  u_st: TStream;
  u_ch: char;
  u_str: string;

function QryCharacter(
): char;
begin
  result := u_ch;
end;

function GetCharacter(
): char;
begin
  result := QryCharacter();
  u_ch := #$00;
  if (u_st.Position < u_st.Size) then begin
    u_st.ReadBuffer(u_ch, sizeof(u_ch));
  end;
end;

function EOF(
): boolean;
begin
  result := (#$00 = QryCharacter());
end;

procedure Bing(
);
begin
  u_str := u_str + GetCharacter();
end;

function QryWord(
): string;
begin
  result := u_str;
end;

function QryQuote(
): boolean;
begin
  result := ((length(QryWord()) > 0) and ('"' = QryWord()[1]));
end;

function QryAlphaNumeric(
): boolean;
begin
  result := ((length(QryWord()) > 0) and (QryWord()[1] in ['_', 'A'..'Z', 'a'..
      'z']));
end;

function QryNumeric(
): boolean;
begin
  result := ((length(QryWord()) > 0) and (QryWord()[1] in ['0'..'9']));
end;

function GetWord(
): string;
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

procedure Open(
  const p_strFilename: string
);
begin
  u_st := TFileStream.Create(p_strFilename, (fmOpenRead or fmShareDenyWrite));
  try
    GetCharacter();
    GetWord();
  except
    FreeAndNil(u_st);
    raise;
  end;
end;

procedure Close(
);
begin
end;


function c_XmlElement.AddElement(
  const p_strName: string
): c_XmlElement;
begin
  result := c_XmlElement.Create(p_strName);
  try
    m_strlElement.AddObject(p_strName, result);
  except
    FreeAndNil(result);
    raise;
  end;
end;

constructor c_XmlElement.Create(
  const p_strName: string
);
begin
  m_strName := p_strName;
  m_strlAttribute := TStringList.Create();
//  m_strlAttribute.Sorted := true;
  m_strlElement := TStringList.Create();
  m_strlElement.Duplicates := dupAccept;
//  m_strlElement.Sorted := true;
end;

destructor c_XmlElement.Destroy(
);
var
  l_i: integer;
  l_strl: TStringList;
begin
  l_strl := m_strlElement;
  for l_i := 0 to l_strl.Count - 1 do begin
    l_strl.Objects[l_i].Free();
  end;
  FreeAndNil(m_strlElement);
  l_strl := m_strlAttribute;
  for l_i := 0 to l_strl.Count - 1 do begin
    l_strl.Objects[l_i].Free();
  end;
  FreeAndNil(m_strlAttribute);
  inherited;
end;

function c_XmlElement.GetAttribute(
  const p_strName: string
): string;
var
  l_i: integer;
  l_strl: TStringList;
begin
  l_strl := m_strlAttribute;
  l_i := l_strl.IndexOf(p_strName);
  if (- 1 = l_i) then begin
    result := '';
    exit;
  end;
  result := c_XmlAttribute(l_strl.Objects[l_i]).GetValue();
end;

function c_XmlElement.GetElement(
  const p_i: integer
): c_XmlElement;
var
  l_strl: TStringList;
begin
  l_strl := m_strlElement;
  if ((p_i < 0) or (p_i >= l_strl.Count)) then begin
    result := nil;
    exit;
  end;
  result := c_XmlElement(l_strl.Objects[p_i]);
end;

function c_XmlElement.GetName(
): string;
begin
  result := m_strName;
end;

function c_XmlElement.LoadElement(
): boolean;
var
  l_strElementName: string;
  l_strAttributeName: string;
  l_xe: c_XmlElement;
  l_str: string;
begin
  result := false;
  if ('<' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  if (not QryAlphaNumeric()) then begin
    exit;
  end;
  l_strElementName := GetWord();
  m_strName := l_strElementName;

  while (QryAlphaNumeric()) do begin
    l_strAttributeName := GetWord();
    if ('=' <> QryWord()) then begin
      exit;
    end;
    GetWord();
    if (not QryQuote()) then begin
      exit;
    end;
    l_str := GetWord();
    delete(l_str, 1, 1);
    delete(l_str, length(l_str), 1);
    SetAttribute(l_strAttributeName, Epacse(l_str));
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

  // either we get the value here are an open tag.

  while ('<' = QryWord()) do begin
    l_xe := AddElement('');
    if (not l_xe.LoadElement()) then begin
      exit;
    end;
  end;
  if ('</' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  if (QryWord() <> l_strElementName) then begin
    exit;
  end;
  GetWord();
  if ('>' <> QryWord()) then begin
    exit;
  end;
  GetWord();
  result := true;
end;

procedure c_XmlElement.LoadFromStream(
  const p_stm: TStream
);
begin
  u_st := p_stm;
  GetCharacter();
  GetWord();
  LoadElement();
end;

function c_XmlElement.QryAttribute(
  const p_strName: string
): boolean;
begin
  result := (- 1 <> m_strlAttribute.IndexOf(p_strName));
end;

procedure c_XmlElement.SaveToStream(
  const p_stm: TStream;
  const p_strIndent: string
);
var
  l_i: integer;
begin
  WriteToStream(p_stm, p_strIndent);
  WriteToStream(p_stm, '<');
  WriteToStream(p_stm, m_strName);
  for l_i := 0 to m_strlAttribute.Count - 1 do begin
    WriteToStream(p_stm, ' ');
    WriteToStream(p_stm, m_strlAttribute.Strings[l_i]);
    WriteToStream(p_stm, '="');
    WriteToStream(p_stm, Escape(c_XMLAttribute(m_strlAttribute.Objects[
        l_i]).GetValue()));
    WriteToStream(p_stm, '"');
  end;
  if (0 = m_strlElement.Count) then begin
    WriteToStream(p_stm, ' />'#$D#$A);
    exit;
  end;
  WriteToStream(p_stm, '>'#$D#$A);
  for l_i := 0 to m_strlElement.Count - 1 do begin
    c_XmlElement(m_strlElement.Objects[l_i]).SaveToStream(p_stm, p_strIndent +
        '  ');
  end;
  WriteToStream(p_stm, p_strIndent);
  WriteToStream(p_stm, '</');
  WriteToStream(p_stm, m_strName);
  WriteToStream(p_stm, '>'#$D#$A);
end;

procedure c_XmlElement.SetAttribute(
  const p_strName: string;
  const p_strValue: string
);
var
  l_i: integer;
  l_strl: TStringList;
begin
  l_strl := m_strlAttribute;
  l_i := l_strl.IndexOf(p_strName);
  if (- 1 = l_i) then begin
    l_i := l_strl.AddObject(p_strName, c_XmlAttribute.Create());
  end;
  c_XmlAttribute(l_strl.Objects[l_i]).SetValue(p_strValue);
end;

function c_XmlAttribute.GetValue(
): string;
begin
  result := m_strValue;
end;

procedure c_XmlAttribute.SetValue(
  const p_str: string
);
begin
  m_strValue := p_str;
end;

procedure c_XmlElement.WriteToStream(
  const p_stm: TStream;
  const p_str: string
);
begin
  p_stm.WriteBuffer(pchar(p_str)^, length(p_str));
end;

class function c_XmlElement.Escape(
  const p_str: string
): string;
var
  l_i: integer;
  l_j: integer;
  l_c: cardinal; // Count of characters in string.
  l_d: cardinal; // Count of """'s in string.
begin

  {: Find out how many """'s and "%"'s we need to escape. }
  l_c := length(p_str);
  l_d := 0;
  for l_i := 1 to l_c do begin
    if (p_str[l_i] in ['%', '"', '<', '>', '&']) then begin
      inc(l_d);
    end;
  end;

  {: Make our resulting string the size of the original string plus the number
  of extra characters we need, which is two for each """ and "%". }
  setlength(result, l_c + l_d * 2);

  {: Copy the original string to the resulting string adding "%xx"'s where
  needed. }
  l_j := 1;
  for l_i := 1 to l_c do begin
    if ('"' = p_str[l_i]) then begin
      result[l_j] := '%';
      inc(l_j);
      result[l_j] := '2';
      inc(l_j);
      result[l_j] := '2';
      inc(l_j);
    end else if ('%' = p_str[l_i]) then begin
      result[l_j] := '%';
      inc(l_j);
      result[l_j] := '2';
      inc(l_j);
      result[l_j] := '5';
      inc(l_j);
    end else if ('<' = p_str[l_i]) then begin
      result[l_j] := '%';
      inc(l_j);
      result[l_j] := '3';
      inc(l_j);
      result[l_j] := 'C';
      inc(l_j);
    end else if ('>' = p_str[l_i]) then begin
      result[l_j] := '%';
      inc(l_j);
      result[l_j] := '3';
      inc(l_j);
      result[l_j] := 'E';
      inc(l_j);
    end else if ('&' = p_str[l_i]) then begin
      result[l_j] := '%';
      inc(l_j);
      result[l_j] := '2';
      inc(l_j);
      result[l_j] := '6';
      inc(l_j);
    end else begin
      result[l_j] := p_str[l_i];
      inc(l_j);
    end;
  end;

end;

class function c_XmlElement.Epacse(
  const p_str: string
): string;
  function HexDigitToByte(
    const p_chr: char
  ): byte;
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
  l_c: cardinal;
  l_i: cardinal;
  l_j: cardinal;
begin
  l_c := length(p_str);                                   
  setlength(result, l_c);
  l_i := 1;
  l_j := 0;
  while (l_i <= l_c) do begin
    if ('%' = p_str[l_i]) then begin
      inc(l_i);
      if (l_i >= l_c) then begin
        raise Exception.Create('Invalid hexidecimal digit.');
      end;
      inc(l_j);
      result[l_j] := char(HexDigitToByte(p_str[l_i]) * 16 + HexDigitToByte(
          p_str[l_i + 1]));
      inc(l_i, 2);
    end else begin
      inc(l_j);
      result[l_j] := p_str[l_i];
      inc(l_i);
    end;
  end;
  setlength(result, l_j);
end;

function c_XmlElement.AsString(
): string;
var
  l_ms: TMemoryStream;
  l_cb: integer;
begin
  l_ms := TMemoryStream.Create();
  try
    SaveToStream(l_ms, '');
    l_ms.Position := 0;
    l_cb := l_ms.Size;
    setlength(result, l_cb);
    l_ms.ReadBuffer(pchar(result)^, l_cb);
  finally
    FreeAndNil(l_ms);
  end;
end;

end.
