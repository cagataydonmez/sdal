<%response.buffer=true%>
<%sayfaadi="Mesaj Panolarý"%>
<%sayfaurl="panolar.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>


<!--#include file="pano.asp"-->


<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->