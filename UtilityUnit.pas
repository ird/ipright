unit UtilityUnit;

interface

uses
  Classes,
  Controls,
  DBTables,
  StdCtrls,
  Windows;

const
  TAB = #9;

type
  c_Event = procedure(const p_p: pointer) of object;

procedure Focus(
  p_wc: TWinControl
);

function ValidateDate(
  const p_edt: TEdit): integer;

function ValidateInteger(
  const p_edt: TEdit): integer;

function ValidateLookUp(
  const p_edt: TEdit;
  const p_tb: TTable;
  const p_strName: string): integer;

procedure OpenDialog(
  const p_edt: TEdit
);

procedure FontDialog(
  const p_edt: TEdit
);

procedure BrowseForFolderDialog(
  const p_edt: TEdit);

function ExtractWord(
  var p_str: string): string;

function StrToFloatDef(
  const p_str: string;
  const p_e: extended): extended;

function StrToCurrDef(
  const p_str: string;
  const p_cur: currency): currency;

{: Appends a back slash to the filename if there isn't one there already and
the filename isn't an empty string. }
function AppendBackSlash(
  const p_strFilename: string
): string;

{: Writes a string into a stream. }
procedure WriteString(
  const p_st: TStream;
  const p_str: string
);

{: Writes a string and a CRLF into a stream. }
procedure WriteLine(
  const p_st: TStream;
  const p_str: string
);

{: Returns the string with backslashes inserted in front of each backslash and
quotation mark in the original string. }
function AddEscape(
  const p_str: string
): string;

{: Executes and application. }
function ExecuteApp(
  const p_strExecutable: string;
  const p_strParameters: string
): THandle;

procedure m_btnFolderClick(
  Sender: TObject
);

{: If both one and two are empty, returns empty. If one is empty and two is not
empty, returns two. If one is not empty and two is empty, returns one. If
neither one and two are empty, returns one plus join plus two. }
function StringsToString(
  const p_strOne: string;
  const p_strJoin: string;
  const p_strTwo: string
): string;

{: Pass in any date/time and the first of that month will be returned. }
function FirstOfMonth(
  const p_dt: TDateTime
): TDateTime;

{: Pass in any date/time and the first of the next month will be returned. }
function FirstOfNextMonth(
  const p_dt: TDateTime
): TDateTime;

{: Pass in any date/time and the first of the previous month will be
returned.}
function FirstOfPreviousMonth(
  const p_dt: TDateTime
): TDateTime;

{: Returns a name suitable for an ini file. Takes the application name,
excluding the path, removes the exe and adds ini. }
function GetIniFilename(
): string;

function GetIniOption(
  const p_strName: string;
  const p_strDefault: string
): string;

procedure SetIniOption(
  const p_strName: string;
  const p_strValue: string
);

{: Returns the number of months since Jan 0000, Jan 0000 being 0, Feb 0000
begin 1, and so forth. }
function DateTimeToMonth(
  const p_dt: TDateTime
): cardinal;

{: The reverse of DateTimeToMonth. Always returns the first of the month at
12am. }
function MonthToDateTime(
  c_n: cardinal
): TDateTime;

function StringToBase64(
  const p_str: string
): string;

function Base64ToString(
  const p_str: string
): string;

function GetEnvironmentVariable(
  const p_str: string
): string;

{: Returns local IP addresses in a comma delimited string.}
function GetIpAddresses(
): string;

{: Returns the passed string but removes %xx's and replaces them the the
appropriate character, assuming that the xx's are hex for the character. }
function Epacse(
  const p_str: string
): string;

implementation

uses
  ActiveX,
  Buttons,
  ComCtrls,
  DB,
  Dialogs,
  Forms,
  IniFiles,
  ShellAPI,
  ShlObj,
  SysUtils,
  WinSock;

function Epacse(
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

function GetIpAddresses(
): string;
type
  PPInAddr = ^PInAddr;
var
  l_wd: TWsaData;
  l_achr: array[0..255] of char;
  l_phe: PHostEnt;
  l_ppia: PPInAddr;
begin
  result := '';
  if (0 <> WsaStartup($0102, l_wd)) then begin
    exit;
  end;
  try
    if (0 <> GetHostName(l_achr, sizeof(l_achr))) then begin
      exit;
    end;
    l_phe := GetHostByName(l_achr);
    if (nil = l_phe) then begin
      exit;
    end;
    l_ppia := pointer(l_phe^.h_addr_list);
    if (nil = l_ppia) then begin
      exit;
    end;
    while (nil <> l_ppia^) do begin
      if ('' <> result) then begin
        result := result + ',';
      end;
      result := result + string(inet_ntoa(l_ppia^^));
      inc(l_ppia);
    end;
  finally
    WsaCleanUp();
  end;
end;

function GetLocalIPs: string;
type PPInAddr= ^PInAddr;
var
   wsaData: TWSAData;
   HostInfo: PHostEnt;
   HostName: array[0..255] of char;
   Addr: PPInAddr;
begin
   Result:='';
   if WSAStartup($0102, wsaData)<>0 then exit;
   try
     if gethostname(HostName, SizeOf(HostName)) <> 0 then exit;
     HostInfo:=gethostbyname(HostName);
     if HostInfo=nil then Exit;
     Addr:=Pointer(HostInfo^.h_addr_list);
     if (Addr=nil) or (Addr^=nil) then exit;
     Result:=StrPas(inet_ntoa(Addr^^));
     inc(Addr);
     while Addr^<>nil do begin
       Result:=Result+^M^J+StrPas(inet_ntoa(Addr^^));
       inc(Addr);
     end;
   finally
     WSACleanup;
   end;
end;


function GetEnvironmentVariable(
  const p_str: string
): string;
var
  l_cb: cardinal;
begin
  l_cb := Windows.GetEnvironmentVariable(pchar(p_str), nil, 0);
  setlength(result, l_cb - 1);
  Windows.GetEnvironmentVariable(pchar(p_str), pchar(result), l_cb);
end;

const
  BASE_64: array[0..64] of char = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno' +
      'pqrstuvwxyz0123456789+/=';

function StringToBase64(
  const p_str: string
): string;
var
  l_i: integer;
  l_j: integer;
  l_byt1: byte;
  l_byt2: byte;
  l_byt3: byte;
begin
  setlength(result, (length(p_str) + 2) div 3 * 4);
  l_i := 0;
  l_j := 0;
  while l_i < length(p_str) do begin
    inc(l_i);
    l_byt1 := byte(p_str[l_i]);
    // take the top 6 bits from the first byte.
    inc(l_j);
    result[l_j] := BASE_64[l_byt1 shr 2];
    if (l_i < length(p_str)) then begin
      inc(l_i);
      l_byt2 := byte(p_str[l_i]);
      // take the bottom 2 bits from the first byte and the top 4 bits from
      // the second byte.
      inc(l_j);
      result[l_j] := BASE_64[((l_byt1 and 3) shl 4) or (l_byt2 shr 4)];
      if (l_i < length(p_str)) then begin
        inc(l_i);
        l_byt3 := byte(p_str[l_i]);
        // take the bottom 4 bits from the second byte and the top 2 bits from
        // the third byte.
        inc(l_j);
        result[l_j] := BASE_64[((l_byt2 and 15) shl 2) or (l_byt3 shr 6)];
        // take the bottom 6 bits from the third byte.
        inc(l_j);
        result[l_j] := BASE_64[l_byt3 and 63];
      end else begin
        // take the bottom 4 bits from the second byte.
        inc(l_j);
        result[l_j] := BASE_64[(l_byt2 and 15) shl 2];
        inc(l_j);
        result[l_j] := '=';
      end;
    end else begin
      // take the bottom 2 bits from the first byte.
      inc(l_j);
      result[l_j] := BASE_64[(l_byt1 and 3) shl 4];
      inc(l_j);
      result[l_j] := '=';
      inc(l_j);
      result[l_j] := '=';
    end;
  end;
end;

function Base64ToString(
  const p_str: string
): string;
var
  l_i: integer;
  l_j: integer;
  l_byt1: byte;
  l_byt2: byte;
  l_byt3: byte;
  l_byt4: byte;
begin
  setlength(result, (length(p_str) + 3) div 4 * 3);
  l_i := 0;
  l_j := 0;
  while l_i < length(p_str) do begin
    inc(l_i);
    l_byt1 := byte(pos(p_str[l_i], BASE_64));
    inc(l_i);
    l_byt2 := byte(pos(p_str[l_i], BASE_64));
    inc(l_i);
    l_byt3 := byte(pos(p_str[l_i], BASE_64));
    inc(l_i);
    l_byt4 := byte(pos(p_str[l_i], BASE_64));
    inc(l_j);
    // take the 6 bits from the first byte and the top 2 bits from the second
    // byte.
    result[l_j] := char((l_byt1 shl 2) or (l_byt2 shr 4));
    inc(l_j);
    // take the bottom 4 bits from the second byte and the top 4 bits from the
    // third byte.
    result[l_j] := char((l_byt2 shl 4) or (l_byt3 shr 2));
    inc(l_j);
    // take the bottom 2 bits from the tird byte and the 6 bits from the fourth
    // byte.
    result[l_j] := char((l_byt3 shl 6) or l_byt4);
  end;
//  if (64 = l_byt3) then begin
//  end else if (64 = l_byt4) then begin
//  end;
end;

function GetIniOption(
  const p_strName: string;
  const p_strDefault: string
): string;
var
  l_if: TIniFile;
begin
  l_if := TIniFile.Create(GetIniFilename());
  try
    result := l_if.ReadString('Options', p_strName, p_strDefault);
  finally
    FreeAndNil(l_if);
  end;
end;

procedure SetIniOption(
  const p_strName: string;
  const p_strValue: string
);
var
  l_if: TIniFile;
begin
  l_if := TIniFile.Create(GetIniFilename());
  try
    l_if.WriteString('Options', p_strName, p_strValue);
  finally
    FreeAndNil(l_if);
  end;
end;

function GetIniFilename(
): string;
begin
  result := ExtractFileName(Application.ExeName);
  result := copy(result, 1, length(result) - 3);
  result := result + 'ini';
end;

function FirstOfNextMonth(
  const p_dt: TDateTime
): TDateTime;
var
  l_wY: word;
  l_wM: word;
  l_wD: word;
begin
  DecodeDate(p_dt, l_wY, l_wM, l_wD);
  inc(l_wM);
  if (l_wM > 12) then begin
    l_wM := 1;

    { Fixed a little oversite. I should have incremented the year but only
    just noticed that I don't... until now. }
    inc(l_wY);

  end;
  result := EncodeDate(l_wY, l_wM, 1);
end;

function FirstOfPreviousMonth(
  const p_dt: TDateTime
): TDateTime;
var
  l_wY: word;
  l_wM: word;
  l_wD: word;
begin
  DecodeDate(p_dt, l_wY, l_wM, l_wD);
  dec(l_wM);
  if (l_wM < 1) then begin
    l_wM := 12;
    dec(l_wY);
  end;
  result := EncodeDate(l_wY, l_wM, 1);
end;

function FirstOfMonth(
  const p_dt: TDateTime
): TDateTime;
var
  l_wY: word;
  l_wM: word;
  l_wD: word;
begin
  DecodeDate(p_dt, l_wY, l_wM, l_wD);
  result := EncodeDate(l_wY, l_wM, 1);
end;

function StringsToString(
  const p_strOne: string;
  const p_strJoin: string;
  const p_strTwo: string
): string;
begin
  result := p_strOne;
  if ('' <> result) and ('' <> p_strTwo) then begin
    result := result + p_strJoin;
  end;
  result := result + p_strTwo;
end;

procedure Focus(
  p_wc: TWinControl
);
begin
  p_wc.Show();
  if (p_wc.Enabled and p_wc.Visible) then begin
    p_wc.SetFocus();
  end;
end;

function ExecuteApp(
  const p_strExecutable: string;
  const p_strParameters: string
): THandle;
begin
  result := ShellExecute(0, pchar('open'), pchar(p_strExecutable), pchar(
      p_strParameters), pchar(ExtractFilePath(p_strExecutable)),
      SW_SHOWNORMAL);
end;

procedure m_btnFolderClick(
  Sender: TObject
);
var
  l_btn: TBitBtn absolute Sender;
  l_edt: TEdit;
begin
  Assert(nil <> Sender);
  Assert(Sender is TBitBtn);
  l_edt := TEdit(l_btn.Tag);
  Assert(nil <> l_edt);
  Assert(l_edt is TEdit);
  BrowseForFolderDialog(l_edt);
end;

function AddEscape(
  const p_str: string
): string;
var
  l_i: integer;
begin
  result := '';
  for l_i := 1 to length(p_str) do begin
    if (('\' = p_str[l_i]) or ('"' = p_str[l_i])) then begin
      result := result + '\';
    end;
    result := result + p_str[l_i];
  end;
end;

procedure WriteString(
  const p_st: TStream;
  const p_str: string
);
begin
  if (nil = p_st) then begin
    exit;
  end;
  p_st.WriteBuffer(pchar(p_str)^, length(p_str));
end;

procedure WriteLine(
  const p_st: TStream;
  const p_str: string
);
begin
  WriteString(p_st, p_str + #$D#$A);
end;

function AppendBackSlash(
  const p_strFilename: string
): string;
var
  l_i: integer;
begin
  result := p_strFilename;
  l_i := length(result);
  if (0 = l_i) then begin
    exit;
  end;
  if ('\' <> result[l_i]) then begin
    result := result + '\';
  end;
end;

function StrToCurrDef(
  const p_str: string;
  const p_cur: currency): currency;
var
  l_cur: currency;
begin
  if not TextToFloat(pchar(p_str), l_cur, fvCurrency) then begin
    l_cur := p_cur;
  end;
  result := l_cur;
end;

function StrToFloatDef(
  const p_str: string;
  const p_e: extended): extended;
var
  l_e: extended;
begin
  if not TextToFloat(pchar(p_str), l_e, fvExtended) then begin
    l_e := p_e;
  end;
  result := l_e;
end;

function ExtractWord(
  var p_str: string): string;
var
  l_i: integer;
begin
  p_str := trim(p_str);
  l_i := pos(' ', p_str);
  if (0 = l_i) then begin
    l_i := length(p_str) + 1;
  end;
  result := copy(p_str, 1, l_i - 1);
  delete(p_str, 1, l_i);
  p_str := trim(p_str);
end;

procedure BrowseForFolderDialog(
  const p_edt: TEdit);
var
  l_bi: TBrowseInfo;
  l_piidl: PItemIDList;
  l_im: IMalloc;
  l_str: string;
begin
  SetLength(l_str, MAX_PATH);
  ZeroMemory(pchar(l_str), MAX_PATH);
  l_bi.hwndOwner := 0;
  l_bi.pidlRoot := nil;
  l_bi.pszDisplayName := pchar(l_str);
  l_bi.lpszTitle := nil;
  l_bi.ulFlags := BIF_RETURNONLYFSDIRS;
  l_bi.lpfn := nil;
  l_bi.lParam := 0;
  l_bi.iImage := 0;
  l_piidl := SHBrowseForFolder(l_bi);
  if (l_piidl <> nil) then begin
    try
      SHGetPathFromIDList(l_piidl, pchar(l_str));
    finally
      if (ActiveX.CoGetMalloc(1, l_im) = S_OK) then begin
        l_im.Free(l_piidl);
      end;
    end;
  end;
  SetLength(l_str, pos(#$00, l_str) - 1);
  if (l_str <> '') then begin
    p_edt.Text := l_str;
  end;
end;

procedure OpenDialog(
  const p_edt: TEdit);
var
  l_od: TOpenDialog;
begin
  l_od := TOpenDialog.Create(nil);
  try
    if (l_od <> nil) then  begin
      l_od.Options := [ofNoChangeDir];
      if (p_edt.Text <> '') then begin
        l_od.FileName := p_edt.Text;
      end;
      if (l_od.Execute()) then begin
        p_edt.Text := l_od.FileName;
      end;
    end;
  finally
    FreeAndNil(l_od);
  end;
end;

procedure FontDialog(
  const p_edt: TEdit
);
var
  l_fd: TFontDialog;
begin
  l_fd := TFontDialog.Create(nil);
  try
    if (l_fd <> nil) then  begin
      l_fd.Font := p_edt.Font;
      if (p_edt.Text <> '') then begin
      end;
      if (l_fd.Execute()) then begin
        p_edt.Font := l_fd.Font;
      end;
    end;
  finally
    FreeAndNil(l_fd);
  end;
end;

function LookUpIntegerFromID(
  const p_tb: TTable;
  const p_id: integer;
  const p_strFieldName: string): integer;
begin
  p_tb.Open();
  try
    if (p_tb.Locate('ID', p_id, [])) then begin
      result := p_tb.FieldByName(p_strFieldName).AsInteger;
    end else begin
      result := 0;
    end;
  finally
    p_tb.Close();
  end;
end;

function ValidateDate(
  const p_edt: TEdit): integer;
begin
  try
    result := trunc(StrToDate(p_edt.Text));
  except
    if (p_edt.Visible and p_edt.Enabled) then begin
      p_edt.SetFocus();
    end;
    raise;
  end;
end;

function ValidateInteger(
  const p_edt: TEdit): integer;
begin
  try
    result := trunc(StrToInt(p_edt.Text));
  except
    if (p_edt.Visible and p_edt.Enabled) then begin
      p_edt.SetFocus();
    end;
    raise;
  end;
end;

function ValidateLookUp(
  const p_edt: TEdit;
  const p_tb: TTable;
  const p_strName: string): integer;
begin
  p_tb.Open();
  try
    if (p_tb.Locate('Info', p_edt.Text, [])) then begin
      result := p_tb.FieldByName('ID').AsInteger;
    end else begin
      result := 0;
      if (p_edt.Visible and p_edt.Enabled) then begin
        p_edt.SetFocus();
      end;
      raise Exception.Create('''' + p_edt.Text + ''' is not a valid ' +
          p_strName + '.');
    end;
  finally
    p_tb.Close();
  end;
end;

function DateTimeToMonth(
  const p_dt: TDateTime
): cardinal;
var
  l_wY: word;
  l_wM: word;
  l_wD: word;
begin
  DecodeDate(p_dt, l_wY, l_wM, l_wD);
  result := l_wY * 12 + l_wM;
  dec(result);
end;

function MonthToDateTime(
  c_n: cardinal
): TDateTime;
begin
  inc(c_n);
  result := EncodeDate(c_n div 12, c_n mod 12, 1);
end;

end.
