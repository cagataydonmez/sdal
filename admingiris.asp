<!--#include file="kodlar.asp"-->
<%
if session_admingiris <> "evet" then
set gh=bag.execute("select * from uyeler where id="&session_uyeid)
if gh("admin") = 1 then
if request.form("geldimi") = "evet" then

asilsifre = "guuk"

sifre = request.form("sifre")
if sifre <> asilsifre then
call hatamsg("Þifre yanlýþ!!",sayfaurl)
response.end
else
response.cookies("admingiris") = "evet"
response.redirect "admin.asp"
end if
%>


<%else%>
<form name=admingir method=post action=admin.asp>
Þifre : <input type=password name=sifre size=20 class=inptxt> <input type=submit value="Gir" class=sub>
<input type=hidden name=geldimi value="evet">
</form>
<%end if%>
<%else%>

<%
response.write "<center><font style=""font-family:verdana;font-size:12;color:red;""><b>Yanlýþ Giriþ!!<br>Eðer yönetici deðilseniz bu sayfayý kullanamazsýnýz.<br><br><a href=""default.asp"">Anasayfaya gitmek için týkla...</a></b></font></center>"
%>

<%end if%>
<%else%>
<!--#include file="kafa.asp"-->
<%
response.write "<center><font style=""font-family:verdana;font-size:12;color:red;""><b>Yanlýþ giriþ!!<br>Admin giriþi yapýlmýþ...<br><br><a href=""default.asp"">Anasayfaya gitmek için týkla...</a></b></font></center>"
%>
<!--#include file="ayak.asp"-->
<%end if%>