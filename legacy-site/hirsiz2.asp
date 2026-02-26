<%response.buffer=true%>
<%
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")
%>
<%
mesid = request.querystring("mid")

set rs=server.createobject("adodb.recordset")
rs.open "select * from gelenkutusu where id="&cint(mesid),bagg,1,3

%>
<u><b>Konu : <%=rs("konu")%></b></u><br>
<%=rs("mesaj")%>