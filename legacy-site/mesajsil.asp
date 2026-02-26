<!--#include file="kodlar.asp"-->
<%
mesid = request.querystring("mid")
k = request.querystring("kk")

if k="" then
k= "0"
end if

if mesid="" then
response.redirect "default.asp"
end if

set ks=server.createobject("adodb.recordset")
ks.open "select * from gelenkutusu where id="&cint(mesid),bag,1,3

if ks("kime") = cstr(request.cookies("uyeid")) then

ks("aktifgelen") = 0

end if

if ks("kimden") = cstr(request.cookies("uyeid")) then

ks("aktifgiden") = 0

end if

ks.update

response.redirect "mesajlar.asp?k="&k

%>