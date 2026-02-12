<%
Set bag = Server.CreateObject("ADODB.Connection")
bag.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("aiacx.mdb")

set rs=server.createobject("adodb.recordset")
rs.open "select * from hmes order by id desc",bag,1
%>

<table border=0 cellpadding=3 cellspacing=0 width=100% height=100%>
<tr>
<td valign=top style="border:1 solid #000033;background:white;font-family:tahoma;font-size:11;color:#000033;">
<%

if rs.eof then
response.write "Henüz mesaj yazýlmamýþ."
else

i=1
do while not rs.eof
%>

<%=i%> - <b><%=rs("kadi")%></b> - <%=rs("metin")%> - <%=rs("tarih")%>
<br>

<%
rs.movenext
i=i+1
loop

end if
%>
</td>
</tr>
</table>