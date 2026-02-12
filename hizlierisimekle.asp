<%response.buffer=true%>
<%sayfaadi="Hýzlý Eriþim Listesine Ekle"%>
<%sayfaurl="hizlierisimekle.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
huye = request.querystring("uid")

set fsd=server.createobject("adodb.recordset")
fsd.open "select * from uyeler where id="&session_uyeid,bagg,1,3

set hlk=bagg.execute("select * from uyeler where id="&cint(huye))
if hlk.eof then
response.redirect "default.asp"
end if

hdizi = split(fsd("hizliliste"),",",-1,1)
for each uyuz in hdizi
if cint(uyuz) = cint(huye) then
msg = "Bu üye zaten hýzlý eriþim listenizde!"
call hatamsg(msg,sayfaurl)
response.end
end if
next

fsd("hizliliste") = fsd("hizliliste") & "," & huye
fsd.update

response.redirect "herisim.asp?hle=e"
%>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->