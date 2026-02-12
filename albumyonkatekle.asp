<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Kategori Ekleme"%>
<%sayfaurl="albumyonkatekle.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>
<%
if request.form("geldimi") = "evet" then

kategori = request.form("kategori")
aciklama = request.form("aciklama")
aktif = cint(request.form("aktif"))

if len(kategori)=0 then
msg = "Kategori girmedin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(aciklama)=0 then
msg = "Açýklama girmedin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ksk = server.createobject("adodb.recordset")
ksk.open "select * from album_kat where kategori='"&kategori&"'",bagg,1

if not ksk.eof then
msg = "Girdiðin kategori ismi zaten kayýtlý.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from album_kat",bagg,1,3

ks.addnew

ks("kategori") = kategori
ks("aciklama") = aciklama
ks("ilktarih") = now()
ks("aktif") = aktif

ks.update
%>
<b>Kategori baþarýyla eklendi!<br>
<a href="albumyonkategori.asp">Kategoriler</a></b>

<%
else
%>
<hr color=#663300 size=1>
<a href="albumyonetim.asp">Albüm Yönetim Anasayfa</a>
<hr color=#663300 size=1>

<table border=0 cellpadding=0>
<tr><td>
<b>Fotoðraf Albümü - Kategori Ekleme</b><br>
<form method=post action=albumyonkatekle.asp>
<table border=0>
<tr><td>Kategori Adý : </td><td><input type=text name=kategori size=30 class=inptxt></td></tr>
<tr><td>Açýklama : </td><td><input type=text name=aciklama size=30 class=inptxt></td></tr>
<tr><td>Aktif mi? : </td><td><select name=aktif class=inptxt><option value="1">Evet<option value="0">Hayýr</select></td></tr>
<input type=hidden name=geldimi value=evet>
<tr><td colspan=2><input type=submit value="Kaydet" class=sub></td></tr>
</table>
</form>

</td></tr></table>
<%end if%>
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