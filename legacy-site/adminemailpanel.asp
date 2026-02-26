<%response.buffer=true%>
<%sayfaadi="Yönetim E-Mail Paneli"%>
<%sayfaurl="adminemailpanel.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>

<table border=0 cellpadding=3 cellspacing=1 width=250>
<tr>
<td style="border:1 solid #663300;background:white;">
<br>
<li><a href="admineptekgonder.asp" title="Tek Email gönder">Hýzlý E-mail Gönder</a><br><br>
<li><a href="adminepcokgonder.asp" title="Çoklu E-Mail Gönder">Çoklu E-Mail Gönder</a><br><br>
<li><a href="adminepkategori.asp" title="Kategori Ekle/Düzenle">Kategori Ekle/Düzenle</a><br><br>
<li><a href="adminepsablon.asp" title="Þablon Ekle/Düzenle">Þablon Ekle/Düzenle</a><br><br>

</td></tr></table>


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