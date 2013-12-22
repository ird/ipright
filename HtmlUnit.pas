unit HtmlUnit;

interface

type
  c_html = class(TObject)
  public
    class function input_checkbox(p_label: string; p_name: string; p_value: boolean): string;
    class function input_text(p_label: string; p_name: string; p_value: string): string;
    class function input_password(p_label: string; p_name: string; p_value: string): string;
  end;

implementation

class function c_html.input_checkbox(p_label: string; p_name: string; p_value: boolean): string;
var
  checked: string;
begin
  if (p_value) then begin
    checked := 'checked="checked" ';
  end else begin
    checked := '';
  end;
  result :=
    '<label for="' + p_name + '">' + p_label + '</label>' +
    '<input ' + checked + 'id="' + p_name + '" name="' + p_name + '" type="checkbox" />';
end;

class function c_html.input_password(p_label, p_name, p_value: string): string;
begin
  result :=
    '<label for="' + p_name + '">' + p_label + '</label>' +
    '<input id="' + p_name + '" name="' + p_name + '" type="password" value="' + p_value + '" />';
end;

class function c_html.input_text(p_label, p_name, p_value: string): string;
begin
  result :=
    '<label for="' + p_name + '">' + p_label + '</label>' +
    '<input id="' + p_name + '" name="' + p_name + '" type="text" value="' + p_value + '" />';
end;

end.
