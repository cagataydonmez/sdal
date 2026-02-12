<%response.buffer=true%>
<%sayfaadi="Yönetim Anasayfa"%>
<%sayfaurl="admin.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>



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