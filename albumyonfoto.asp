<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Fotoðraf Göster"%>
<%sayfaurl="albumyonfoto.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>
<%
krt = request.querystring("krt")
diz = request.querystring("diz")
set ks=server.createobject("adodb.recordset")

if krt = "onaybekleyen" then
ks.open "select * from album_foto where aktif=0",bagg,1
if ks.eof then
response.write "Onay bekleyen fotoðraf yok!<br><br><a href=albumyonetim.asp>Albüm Yönetim</a>"
response.end
end if
response.write "<hr color=#663300 size=1><a href=albumyonetim.asp>Albüm Yönetim</a><hr color=#663300 size=1>"

elseif krt = "kategori" then
kid = request.querystring("kid")
if len(kid) = 0 or not isnumeric(kid) then
response.redirect "albumyonetim.asp"
end if

if diz="baslikartan" then
ks.open "select * from album_foto where katid='"&kid&"' order by baslik",bagg,1
elseif diz="baslikazalan" then
ks.open "select * from album_foto where katid='"&kid&"' order by baslik desc",bagg,1

elseif diz="acikartan" then
ks.open "select * from album_foto where katid='"&kid&"' order by aciklama",bagg,1
elseif diz="acikazalan" then
ks.open "select * from album_foto where katid='"&kid&"' order by aciklama desc",bagg,1

elseif diz="aktifartan" then
ks.open "select * from album_foto where katid='"&kid&"' order by aktif",bagg,1
elseif diz="aktifazalan" then
ks.open "select * from album_foto where katid='"&kid&"' order by aktif desc",bagg,1

elseif diz="ekleyenartan" then
ks.open "select * from album_foto where katid='"&kid&"' order by ekleyenid",bagg,1
elseif diz="ekleyenazalan" then
ks.open "select * from album_foto where katid='"&kid&"' order by ekleyenid desc",bagg,1

elseif diz="tarihartan" then
ks.open "select * from album_foto where katid='"&kid&"' order by tarih",bagg,1
elseif diz="tarihazalan" then
ks.open "select * from album_foto where katid='"&kid&"' order by tarih desc",bagg,1

elseif diz="hitartan" then
ks.open "select * from album_foto where katid='"&kid&"' order by hit",bagg,1
elseif diz="hitazalan" then
ks.open "select * from album_foto where katid='"&kid&"' order by hit desc",bagg,1

else
ks.open "select * from album_foto where katid='"&kid&"' order by aktif desc",bagg,1
end if

response.write "<hr color=#663300 size=1><a href=albumyonkategori.asp>Albüm Yönetim Kategoriler</a><hr color=#663300 size=1>"

else
response.redirect "albumyonetim.asp"
end if

%>
<form method=post action="albumyonaktivet.asp" name="fotoisl">
<table border=0 cellpadding=3 cellspacing=1>
<tr>
<td style="border:1 solid #663300;"><b>
#
</b>
</td>
<td style="border:1 solid #663300;"><b>
Foto
</b>
</td>
<td style="border:1 solid #663300;"><b>
Kategori
</b>
</td>
<td style="border:1 solid #663300;"><b>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=baslikartan"><img src="artan.gif" border=0></a>Baþlýk<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=baslikazalan"><img src="azalan.gif" border=0></a>
</b>
</td>
<td style="border:1 solid #663300;"><b>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=acikartan"><img src="artan.gif" border=0></a>Açýklama<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=acikazalan"><img src="azalan.gif" border=0></a>
</b>
</td>
<td style="border:1 solid #663300;"><b>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=aktifartan"><img src="artan.gif" border=0></a>Aktif mi?<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=aktifazalan"><img src="azalan.gif" border=0></a>
</b>
</td>
<td style="border:1 solid #663300;"><b>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=ekleyenartan"><img src="artan.gif" border=0></a>Ekleyen<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=ekleyenazalan"><img src="azalan.gif" border=0></a>
</b>
</td>
<td style="border:1 solid #663300;"><b>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=tarihartan"><img src="artan.gif" border=0></a>Tarih<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=tarihazalan"><img src="azalan.gif" border=0></a>
</b>
</td>
<td style="border:1 solid #663300;"><b>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=hitartan"><img src="artan.gif" border=0></a>Hit<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>&diz=hitazalan"><img src="azalan.gif" border=0></a>
</b>
</td>
<td style="border:1 solid #663300;"><b>
Yorumlar
</b>
</td>
<td style="border:1 solid #663300;"><b>
Ýþlem
</b>
</td>
</tr>
<%
do while not ks.eof
%>

<tr>
<td style="border:1 solid #663300;background:#ffffcc;">
<input type=checkbox name=fotolar value="<%=ks("id")%>">
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<a href="kucukresim3.asp?r=<%=ks("dosyaadi")%>" target="_blank" title="Tam boy olarak görmek için týklayýn"><img src="kucukresim.asp?iwidth=50&r=<%=ks("dosyaadi")%>" border=0></a>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%
set kt=bagg.execute("select * from album_kat where id="&ks("katid"))
%>
<%=kt("kategori")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("baslik")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("aciklama")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%if ks("aktif") = 1 then%>Evet<%else%>Hayýr<%end if%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%
set fe=bagg.execute("select * from uyeler where id="&ks("ekleyenid"))
if fe.eof then
response.write "Üye silinmiþ"
else
%>
<%=fe("kadi")%>
<%end if%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("tarih")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("hit")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%
set yr=server.createobject("adodb.recordset")
yr.open "select * from album_fotoyorum where fotoid='"&ks("id")&"'",bagg,1
%>
<a href="albumyonfotoyorum.asp?fid=<%=ks("id")%>&krt=<%=krt%>&kid=<%=kt("id")%>">Yorumlar ( <b><i><%=yr.recordcount%></i></b> )</a>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<a href="albumyonfotoduz.asp?fid=<%=ks("id")%>&krt=<%=krt%>&kid=<%=kt("id")%>">Düzenle</a> / <a href="albumyonfotosil.asp?fid=<%=ks("id")%>&krt=<%=krt%>&kid=<%=kt("id")%>">Sil</a>
</td>
</tr>

<%
ks.movenext
loop
%>
<script language="Javascript">
function akt() {
document.fotoisl.isl.value='aktiv';
document.fotoisl.submit();
}
function inakt() {
document.fotoisl.isl.value='deaktiv';
document.fotoisl.submit();
}
</script>
<tr>
<td colspan=11 align=left>
<input type=hidden name=isl value="aktiv">
<input type=button value="Seçilenleri Aktifleþtir" class=sub onclick="akt();">
<input type=button value="Seçilenleri Ýnaktifleþtir" class=sub onclick="inakt();">
</td>
</tr>
</table>
</form>


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