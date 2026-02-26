<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Fotoðraf Silme"%>
<%sayfaurl="albumyonfotosil.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>


<%
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

foto_isim = ks("baslik")

Set fsil = CreateObject("Scripting.FileSystemObject")
fyol = Request.servervariables("APPL_PHYSICAL_PATH")
fyol = fyol & "foto0905\"
fyol = fyol & ks("dosyaadi")
if fsil.FileExists(fyol) = True then
fsil.DeleteFile fyol

response.write "<b>Dosya baþarýyla silindi!!</b><br><br>"
else
response.write "<b>Dosya bulunamadý!!</b><br><br>"
end if

set sil = bagg.execute("delete from album_foto where id="&fid)

%>

<table border=0 cellpadding=0>
<tr><td>

<%
krt = request.querystring("krt")
kid = request.querystring("kid")
%>
<b>Fotoðraf (<i><%=foto_isim%></i>) baþarýyla silindi.</b><br><br>
<%
set sil2 = bagg.execute("delete from album_fotoyorum where fotoid='"&fid&"'")
%>
<b>Fotoðrafa yapýlan yorumlar baþarýyla silindi.</b><br><br>
<a href="albumyonfoto.asp?krt=<%=krt%>&kid=<%=kid%>">Geri Dön</a>

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