<%response.buffer=true%>
<%sayfaadi="karikatur1"%>
<%sayfaurl="karikatur1.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<b>YÝÐÝT ÖZGÜR KARÝKATÜRLERÝ</b>
<hr color=#660000 size=1>
<%
id = request.querystring("id")

if Len(id) = 0 then
id=1
end if
if not isNumeric(id) then
id=1
end if
id=cint(id)
%>
<a href="karikatur1.asp?id=<%=id+1%>" title="sonraki"><img src=karikatur1/<%=id%>.jpg border=1></a>
<hr color=#660000 size=1>
| 
<%
k=1
for i=1 to 607
%>
<%if id=i then%>
<b><%=i%></b> | 
<%else%>
<a href=karikatur1.asp?id=<%=i%> title="görmek için týklayýn"><%=i%></a> | 
<%end if%>
<%
if k=20 then
response.write "<br>| "
k=0
end if
k=k+1
%>

<%next%>




<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->