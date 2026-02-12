<%response.buffer=true%>
<%sayfaadi="Forum"%>
<%sayfaurl="forum.asp"%>
<!--#include file="kafa.asp"-->

<% if session("uyegiris") = "evet" then%>
<center>Burasý sdal.org forumu.<br><br>
<a href=default.asp>Anasayfa</a></center>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->