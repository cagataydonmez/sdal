<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Fotoðraf Düzenleme"%>
<%sayfaurl="albumyonfotoduz.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>
<%
if request.form("geldimi") = "evet" then

fid = request.form("fid")
baslik = trim(request.form("baslik"))
aciklama = request.form("aciklama")
aktif = cint(request.form("aktif"))
katid = request.form("katid")

set ks=server.createobject("adodb.recordset")
ks.open "select * from album_foto where id="&fid,bagg,1,3


ks("baslik") = baslik
ks("aciklama") = aciklama
ks("aktif") = aktif
ks("katid") = katid

ks.update

krt = request.form("krt")
kid = request.form("kid")
%>
<b>Fotoðraf baþarýyla düzenlendi!</b><br><br>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>">Geri Dön</a>

<%
else

fid = request.querystring("fid")
if len(fid) = 0 then
msg = "Hatalý Fotoðraf ID.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks=bagg.execute("select * from album_foto where id="&fid)
if ks.eof then
response.write "böyle bir fotoðraf yok."
response.end
end if

krt = request.querystring("krt")
kid = request.querystring("kid")


%>

<table border=0 cellpadding=0>
<tr><td>
<b>Fotoðraf Albümü - Fotoðraf Düzenleme (<%=ks("baslik")%>)</b><br>
<form method=post action=albumyonfotoduz.asp>
<table border=0>
<tr><td>Fotoðraf Adý : </td><td><input type=text name=baslik size=30 class=inptxt value="<%=ks("baslik")%>"></td></tr>
<tr><td>Açýklama : </td><td><input type=text name=aciklama size=30 class=inptxt value="<%=ks("aciklama")%>"></td></tr>
<tr><td>Aktif mi? : </td><td><select name=aktif class=inptxt><option value="1"<%if ks("aktif")=1 then%> selected<%end if%>>Evet<option value="0"<%if ks("aktif")=0 then%> selected<%end if%>>Hayýr</select></td></tr>
<%
set kate = bagg.execute("select * from album_kat")
%>
<tr><td>Kategori : </td><td><select name=katid class=inptxt>
<%
do while not kate.eof
%>
<option value="<%=kate("id")%>"<%if kate("id")=cint(ks("katid")) then%> selected<%end if%>><%=kate("kategori")%>
<%
kate.movenext
loop
%>
</select></td></tr>

<input type=hidden name=geldimi value=evet>
<input type=hidden name=fid value="<%=ks("id")%>">
<input type=hidden name=krt value="<%=krt%>">
<input type=hidden name=kid value="<%=kid%>">
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