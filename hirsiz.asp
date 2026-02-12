<%response.buffer=true%>
<%
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")
%>
<%
g=request.form("geldimi")
if g="evet" then
id = request.form("uyeid")

set ks=server.createobject("adodb.recordset")
ks.open "select * from gelenkutusu where kime = '"&id&"' order by tarih desc",bagg,1

set kss=server.createobject("adodb.recordset")
kss.open "select * from gelenkutusu where kimden = '"&id&"' order by tarih desc",bagg,1

response.write "<b><u>Gelenler</u></b><br>"
i=1
do while not ks.eof
set kmd=bagg.execute("select * from uyeler where id="&cint(ks("kimden")))
%>
<%=i%>-) <%=kmd("kadi")%> - <a href=hirsiz2.asp?mid=<%=ks("id")%>><b><%=Left(ks("konu"),25)%></b></a><br>
<%
i=i+1
ks.movenext
loop

response.write "<b><u>Gidenler</u></b><br>"
i=1
do while not kss.eof
set kmd=bagg.execute("select * from uyeler where id="&cint(kss("kime")))
%>
<%=i%>-) <%=kmd("kadi")%> - <a href=hirsiz2.asp?mid=<%=kss("id")%>><b><%=Left(kss("konu"),25)%></b></a><br>
<%
i=i+1
kss.movenext
loop

else
%>
<form method=post action=hirsiz.asp>
Üye Ýd : <input type=text name=uyeid size=20>
<input type=hidden name=geldimi value="evet">
<input type=submit value="Gönder">
</form>
<%
end if
%>