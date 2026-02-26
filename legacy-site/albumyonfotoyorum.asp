<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Fotoðraf Yorumlarý"%>
<%sayfaurl="albumyonfotoyorum.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>

<%
krt = request.querystring("krt")
kid = request.querystring("kid")
fid = request.querystring("fid")
yid = request.querystring("yid")
if Len(yid)<>0 then

set sil = bagg.execute("delete from album_fotoyorum where id="&yid)

response.redirect "albumyonfotoyorum.asp?fid="&fid&"&krt="&krt&"&kid="&kid

else

set ks=bagg.execute("select * from album_fotoyorum where fotoid='"&fid&"'")
if ks.eof then
response.write "Henüz yorum eklenmemiþ.<br><br><a href=javascript:history.back();>Geri dÖn</a>"
response.end
end if
%>
<hr color=#663300 size=1>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>">Geri Dön</a>
<hr color=#663300 size=1>
<table border=0 cellpadding=3 cellspacing=1>
<tr>
<td colspan=4 style="border:1 solid #663300;">
<b>YORUMLAR</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;">
<b>Yorumcu</b>
</td>
<td style="border:1 solid #663300;">
<b>Yorum</b>
</td>
<td style="border:1 solid #663300;">
<b>Tarih</b>
</td>
<td style="border:1 solid #663300;">
<b>Ýþlem</b>
</td>
</tr>
<%
do while not ks.eof
%>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("uyeadi")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("yorum")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<%=ks("tarih")%>
</td>
<td style="border:1 solid #663300;background:#ffffcc;">
<a href="albumyonfotoyorum.asp?fid=<%=fid%>&yid=<%=ks("id")%>&krt=<%=krt%>&kid=<%=kid%>">Sil</a>
</td>
</tr>

<%
ks.movenext
loop
%>
</table>
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