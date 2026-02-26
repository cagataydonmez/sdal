<%response.buffer=true%>
<%sayfaadi="Anasayfa"%>
<%sayfaurl="default.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>


Sayaf bu arada olacak...




<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->