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

function ExtractWord(
  var p_str: string): string;

function StringToBase64(
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

end.
