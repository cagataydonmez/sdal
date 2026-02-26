<%response.buffer=true%>
<%sayfaadi="Albüm Yönetim Aktiv-Deaktiv"%>
<%sayfaurl="albumyonaktivet.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>

<%
isl = request.form("isl")
set rs=server.createobject("adodb.recordset")
For i=1 to Request.Form("fotolar").count
id = cint(Request.Form("fotolar") (i))
rs.open "select * from album_foto where id="&id,bagg,1,3

if isl = "aktiv" then
rs("aktif") = 1
elseif isl = "deaktiv" then
rs("aktif") = 0
end if

rs.update
rs.close

Next

set rs=Nothing

response.redirect request.servervariables("HTTP_REFERER")
%>

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