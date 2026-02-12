<%response.buffer=true%>
<%
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")
%>
<%
g=request.form("geldimi")
if g="evet" then
id = request.form("uyeid")

set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler where id="&cint(id),bagg,1,3

rs("online") = 0

rs.update

else

set ks=server.createobject("adodb.recordset")
ks.open "select * from uyeler order by id desc",bagg,1
%>
<%=ks("id")%> - <%=ks("kadi")%><br>
<form method=post action=http500.asp>
�ye �d : <input type=text name=uyeid size=20>
<input type=hidden name=geldimi value="evet">
<input type=submit value="G�nder">
</form>
<%
end if
%>