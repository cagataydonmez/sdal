<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Kategoriler"%>
<%sayfaurl="albumyonkategori.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>

<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from album_kat order by aktif desc",bagg,1

if ks.eof then
response.write "Hiçbir kategori yok.."
response.end
end if
%>
<hr color=#663300 size=1>
<a href="albumyonetim.asp">Albüm Yönetim Anasayfa</a>
<hr color=#663300 size=1>
<table border=0 cellpadding=3 cellspacing=1>
<tr>
<td style="border:1 solid #663300;"><b>ID</b></td>
<td style="border:1 solid #663300;"><b>KATEGORÝ</b></td>
<td style="border:1 solid #663300;"><b>AÇIKLAMA</b></td>
<td style="border:1 solid #663300;"><b>ÝLK TARÝH</b></td>
<td style="border:1 solid #663300;"><b>SON EKLEME TARÝHÝ</b></td>
<td style="border:1 solid #663300;"><b>SON EKLEYEN</b></td>
<td style="border:1 solid #663300;"><b>AKTÝF MÝ?</b></td>
<td style="border:1 solid #663300;"><b>ÝÞLEM</b></td>
</tr>
<%
do while not ks.eof
if not len(ks("sonekleyen")) = 0 then
set ucek=bagg.execute("select * from uyeler where id="&ks("sonekleyen"))
if ucek.eof then
sonekleyen = "Üye silinmiþ."
else
sonekleyen = ucek("kadi")
end if
else
sonekleyen = "Kategori yeni."
end if

set xx = server.createobject("adodb.recordset")
xx.open "select * from album_foto where aktif=1 and katid='"&ks("id")&"'",bagg,1
akfoto=xx.recordcount
xx.close
xx.open "select * from album_foto where aktif=0 and katid='"&ks("id")&"'",bagg,1
inakfoto=xx.recordcount
%>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;"><%=ks("id")%></td>
<td style="border:1 solid #663300;background:#ffffcc;"><a href="albumyonfoto.asp?krt=kategori&kid=<%=ks("id")%>" title="Bu kategorideki fotoðraflarý görmek için týklayýn."><%=ks("kategori")%> - (Aktif:<%=akfoto%>,Ýnaktif:<%=inakfoto%>)</a></td>
<td style="border:1 solid #663300;background:#ffffcc;"><%=ks("aciklama")%></td>
<td style="border:1 solid #663300;background:#ffffcc;"><%=ks("ilktarih")%></td>
<td style="border:1 solid #663300;background:#ffffcc;"><%=ks("sonekleme")%></td>
<td style="border:1 solid #663300;background:#ffffcc;"><%=sonekleyen%></td>
<%if ks("aktif")=1 then akt="evet" else akt="hayir" end if%>
<td style="border:1 solid #663300;background:#ffffcc;"><%=akt%></td>
<td style="border:1 solid #663300;background:#ffffcc;"><a href="albumyonkatduz.asp?kid=<%=ks("id")%>">Düzenle</a> / <a href="albumyonkatsil.asp?kid=<%=ks("id")%>">Sil</a></td>
</tr>
<%
ks.movenext
loop
%>
</table>

<hr color=#663300 size=1>
<a href="albumyonetim.asp">Albüm Yönetim Anasayfa</a>
<hr color=#663300 size=1>

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