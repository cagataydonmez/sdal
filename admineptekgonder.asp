<%response.buffer=true%>
<%sayfaadi="Yönetim E-Mail Paneli - Hızlı E-Mail Gönderme"%>
<%sayfaurl="admineptekgonder.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris") = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<a href="adminemailpanel.asp">Yönetim E-Mail Paneli</a>
<hr color=brown size=1>


<%
if request.form("geldimi") = "evet" then
kime = trim(request.form("kime"))
kimden = trim(request.form("kimden"))
konu = trim(request.form("konu"))
metin = request.form("")

if len(kime)=0 then
msg = "E-Mailin kime gideceğini girmedin.<br>İstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(kimden)=0 then
msg = "E-Mailin kimden gideceğini girmedin.<br>İstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(konu)=0 then
msg = "E-Mailin konusunu girmedin.<br>İstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(metin)=0 then
msg = "E-Mailin metnini girmedin.<br>İstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if


else
%>
<table border=0 cellpadding=3 cellspacing=1 width=500>
<tr>
<td style="border:1 solid #663300;background:white;">


<form method=post action="admineptekgonder.asp">
<table border=0 cellpadding=3 width=100%>
<tr>
<td align=left colspan=2 style="font-size:15;color:#663300;">
<b>Hızlı E-Mail Gönder</b>
</td>
</tr>
<tr>
<td align=right>
<b>Kime : </b>
</td>
<td align=left>
<input type=text size=30 name=kime class=inptxt>
</td>
</tr>
<tr>
<td align=right>
<b>Kimden : </b>
</td>
<td align=left>
<input type=text size=30 name=kimden class=inptxt>
</td>
</tr>
<tr>
<td align=right>
<b>Konu : </b>
</td>
<td align=left>
<input type=text size=30 name=konu class=inptxt>
</td>
</tr>
<tr>
<td align=right valign=top>
<b>Metin : </b>
</td>
<td align=left>
<textarea cols=50 rows=10 class=inptxt></textarea>
</td>
</tr>
<tr>
<td align=right colspan=2>
<input type=submit value="Gönder" class=sub>
<input type=hidden name=geldimi value="evet">
</td>
</tr>
</table>
</form>

</td></tr></table>
<%end if%>



<br>

  <%else%>
<!--#include file="admingiris.asp"-->
<%end if%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->