<%response.buffer=true%>
<%sayfaadi="En Yeni Üyeler"%>
<%sayfaurl="enyeniuyeler.asp"%>
<!--#include file="kafa.asp"-->
<% if session_uyegiris = "evet" then%>
<%cc_sonkac=100%>
<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>En Yeni <%=cc_sonkac%> Üyemiz</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;background:white;">
<%call enyeniuyeler(cc_sonkac,bagg)%>
</td>
</tr>
</table>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>
<!--#include file="ayak.asp"-->