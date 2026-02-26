<%
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")
%>

<%
set sitler=server.createobject("adodb.recordset")
sitler.open "select * from uyeler where online = 1 order by kadi",bagg,1,3
i=1
if sitler.eof then
response.write " Şu an sitede online üye bulunmamaktadır."
else

%>
<br>&nbsp;Şu anda sitede dolaşanlar : 
<%

do while not sitler.eof

%>
<%if request.cookies("uyegiris") = "evet" then%>
<%if i<>1 then%>,<%end if%><a href="uyedetay.asp?id=<%=sitler("id")%>" title="Üye Detayları" style="color:#ffffcc;"><%=sitler("kadi")%></a>
<%else%>
<%if i<>1 then%>,<%end if%><%=sitler("kadi")%>
<%end if%>
<%

sitler.movenext
i=i+1
loop
end if%>