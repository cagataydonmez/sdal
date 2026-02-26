<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Kategori Düzenleme"%>
<%sayfaurl="albumyonkatduz.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>
<%
if request.form("geldimi") = "evet" then

kid = request.form("kid")
kategori = trim(request.form("kategori"))
aciklama = request.form("aciklama")
aktif = cint(request.form("aktif"))

if Len(kategori) = 0 then
msg = "Bir kategori adý girmedin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if Len(aciklama) = 0 then
msg = "Bir açýklama girmedin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks=server.createobject("adodb.recordset")
ks.open "select * from album_kat where id="&kid,bagg,1,3

set kk=bagg.execute("select * from album_kat where kategori='"&kategori&"'")
do while not kk.eof
if not kk("kategori") = ks("kategori") then
if kk("kategori") = kategori then
msg = "Böyle bir kategori zaten kayýtlý!<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if
end if
kk.movenext
loop

ks("kategori") = kategori
ks("aciklama") = aciklama
ks("aktif") = aktif

ks.update
%>
<b>Kategori baþarýyla düzenlendi!</b><br><br>
<a href="albumyonkategori.asp">Geri Dön</a>

<%
else

kid = request.querystring("kid")
if len(kid) = 0 then
msg = "Hatalý Kategori ID.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks=bagg.execute("select * from album_kat where id="&kid)
if ks.eof then
response.write "böyle bir kategori yok."
response.end
end if




%>

<table border=0 cellpadding=0>
<tr><td>
<b>Fotoðraf Albümü - Kategori Düzenleme (<%=ks("kategori")%>)</b><br>
<form method=post action=albumyonkatduz.asp>
<table border=0>
<tr><td>Kategori Adý : </td><td><input type=text name=kategori size=30 class=inptxt value="<%=ks("kategori")%>"></td></tr>
<tr><td>Açýklama : </td><td><input type=text name=aciklama size=30 class=inptxt value="<%=ks("aciklama")%>"></td></tr>
<tr><td>Aktif mi? : </td><td><select name=aktif class=inptxt><option value="1"<%if ks("aktif")=1 then%> selected<%end if%>>Evet<option value="0"<%if ks("aktif")=0 then%> selected<%end if%>>Hayýr</select></td></tr>
<input type=hidden name=geldimi value=evet>
<input type=hidden name=kid value="<%=ks("id")%>">
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