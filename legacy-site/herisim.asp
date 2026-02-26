<%response.buffer=true%>
<%sayfaadi="Hýzlý Eriþim"%>
<%sayfaurl="herisim.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>



<!--#include file="hizlierisim.asp"-->



<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->