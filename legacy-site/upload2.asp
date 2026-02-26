<%

set ul = server.createobject("w3.upload")

set vesika = ul.form("vesika")

if vesika.IsFile then
vesika.savetofile(Request.servervariables("APPL_PHYSICAL_PATH")&"\vesikalik\\yeniresim")
end if
%>

Yüklendi!!!