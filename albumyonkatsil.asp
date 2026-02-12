<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Kategori Silme"%>
<%sayfaurl="albumyonkatsil.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>


<%
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

kat_isim = ks("kategori")

set fk=bagg.execute("select * from album_foto where katid='"&ks("id")&"'")
if not fk.eof then
msg = "Kategori boþ deðil.<br>Kategorinin silinebilmesi için içinde resim olmamasý gerekir. <br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set sil = bagg.execute("delete from album_kat where id="&kid)

%>

<table border=0 cellpadding=0>
<tr><td>

<b>Kategori (<i><%=kat_isim%></i>) baþarýyla silindi.</b><br><br>
<a href="albumyonkategori.asp">Albüm Yönetim Kategoriler sayfasýna geri dön</a>

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