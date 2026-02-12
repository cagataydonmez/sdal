<%response.buffer=true%>
<%sayfaadi="Yorum Ekleme"%>
<%sayfaurl="albumyorumekle.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->


<% if session_uyegiris = "evet" then%>

<%
fid = request.form("fid")
sf = request.form("sf")
set kn=bagg.execute("select * from album_foto where id="&fid)
if kn.eof then
response.redirect "album.asp"
end if

yorum = request.form("yorum")
if Len(yorum) = 0 then
msg = "Yorum girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

yorum = metinduzenle(yorum)

set ks = server.createobject("adodb.recordset")
ks.open "select * from album_fotoyorum",bagg,1,3

ks.addnew

ks("fotoid") = fid
ks("uyeadi") = session_kadi
ks("yorum") = yorum
ks("tarih") = now()

ks.update

response.redirect "fotogoster.asp?fid="&fid&"&sf="&sf
%>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->