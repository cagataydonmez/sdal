<%response.buffer=true%>
<%sayfaadi="Yönetici Çıkış"%>
<%sayfaurl="admincikis.asp"%>

<%
if session_admingiris = "evet" then

response.cookies("admingiris") = ""
response.redirect "admin.asp"

else
response.write "<center><font style=""font-family:verdana;font-size:14;color:red;""><b>yanlış giriş!!<br><br><a href=""default.asp"">anasayfaya gitmek için tıklayınız...</a></b></font></center>"
end if
%>