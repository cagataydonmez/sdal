<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Anasayfa"%>
<%sayfaurl="albumyonetim.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>
<table border=0 cellpadding=0>
<tr><td>


<u><b>Albüm Yönetim Paneli</b></u><br><br>
<ul>
<li><a href="albumyonkatekle.asp">Kategori Ekle</a>
<li><a href="albumyonkategori.asp">Kategoriler</a>
<%
set s=server.createobject("adodb.recordset")
s.open "select * from album_foto where aktif=0",bagg,1
%>
<li><a href="albumyonfoto.asp?krt=onaybekleyen">Onay Bekleyen Fotoðraflar<%if not s.recordcount=0 then%> ( <b><%=s.recordcount%></b> )<%end if%></a>
</ul>

</td></tr></table>

<%
else
response.redirect "album.asp"
end if
%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->