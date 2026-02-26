<%response.buffer=true%>
<!--#include file="kodlar.asp"-->

<%
if request.cookies("uyegiris") = "evet" then

uid = cint(request.cookies("uyeid"))
set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler where id="&uid,bag,1,3

rs("online") = 0

rs.update
rs.close

response.cookies("uyegiris") = ""
response.cookies("uyeid") = ""
response.cookies("kadi") = ""
response.cookies("admingiris") = ""

session("osontarkon") = ""
response.redirect "default.asp"
%>

<%
else
response.write "<center><font style=""font-family:verdana;font-size:14;color:red;""><b>yanlış giriş!!<br><br><a href=""default.asp"">anasayfaya gitmek için tıklayınız...</a></b></font></center>"
end if
%>