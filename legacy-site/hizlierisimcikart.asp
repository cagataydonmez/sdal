<%response.buffer=true%>
<%sayfaadi="Hızlı Erişim Listesinden Çıkart"%>
<%sayfaurl="hizlierisimcikart.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
huye = request.querystring("uid")

set fsd=server.createobject("adodb.recordset")
fsd.open "select * from uyeler where id="&session_uyeid,bagg,1,3

if fsd("hizliliste") = "0" then
response.redirect "default.asp"
end if

hdizi = split(fsd("hizliliste"),",",-1,1)

sondizi = "0"
for each huy in hdizi
if huy <> "0" then
if cint(huy) <> cint(huye) then
sondizi = sondizi & "," & huy 
end if
end if
next

fsd("hizliliste") = sondizi
fsd.update

response.redirect "herisim.asp?hlc=e"
%>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->