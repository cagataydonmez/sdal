<%response.buffer=true%>
<%sayfaadi="Yönetim Sayfa Sil"%>
<%sayfaurl="adminsayfasil.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
| <a href="adminsayfalar.asp">Sayfalar</a> |
<hr color=brown size=1>
<%
sfid = request.querystring("sfid")
set sl = server.createobject("adodb.recordset")
sl.open "delete from sayfalar where id="&sfid,bagg,1,3
%>

<b><%=sfid%></b> ID numaralý sayfa baþarýyla silindi.

<br>

  <%else%>
<!--#include file="admingiris.asp"-->
<%end if%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->