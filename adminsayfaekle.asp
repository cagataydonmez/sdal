<%response.buffer=true%>
<%sayfaadi="Yönetim Sayfa Ekleme"%>
<%sayfaurl="adminsayfaekle.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
| <a href="adminsayfalar.asp">Sayfalar</a> | 
<hr color=brown size=1>
<%if request.form("geldimi") = "evet" then

sayfaismi = trim(request.form("sayfaismi"))
ysayfaurl = trim(request.form("sayfaurl"))
babaid = trim(request.form("babaid"))
menugorun = request.form("menugorun")
yonlendir = request.form("yonlendir")
mozellik = request.form("mozellik")
resim = trim(request.form("resim"))

if Len(sayfaismi) = 0 then
msg = "Sayfa ismini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if Len(ysayfaurl) = 0 then
msg = "Sayfa adresini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if not Isnumeric(babaid) then
msg = "BabaID bir sayý olmalýdýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if Len(resim) = 0 then
msg = "Resim girmedin. Eðer resim yoksa <i>yok</i> yazmalýsýn<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

menugorun = cint(menugorun)
yonlendir = cint(yonlendir)
mozellik = cint(mozellik)

set rs = server.createobject("adodb.recordset")
rs.open "select * from sayfalar",bagg,1,3

rs.addnew

rs("sayfaismi") = sayfaismi
rs("sayfaurl") = ysayfaurl
rs("babaid") = babaid
rs("menugorun") = menugorun
rs("yonlendir") = yonlendir
rs("mozellik") = mozellik
rs("resim") = resim

rs.update
rs.close

response.redirect "adminsayfalar.asp"
else
%>
<form method=post action="adminsayfaekle.asp" name="Sayfaekleform">
<table border=0 cellpadding=3 cellspacing=1>
<tr><td colspan=2 style="border:1 solid lightgreen;font-weight:bold;color:brown;font-size:14;">
<center>Yeni Sayfa Ekle</center>
</td></tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Sayfa Ýsmi : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=sayfaismi size=20 class=inptxt>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Sayfa URL : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=sayfaurl size=20 class=inptxt>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Baba ID : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=babaid size=20 class=inptxt value="0">
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Menüde Görünsün mü? : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<select name=menugorun class=inptxt>
<option value="1">Evet
<option value="0">Hayýr
</select>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Yönlendirme var mý? : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<select name=yonlendir class=inptxt>
<option value="1">Evet
<option value="0" selected>Hayýr
</select>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
M.Özellik? : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<select name=mozellik class=inptxt>
<option value="1">Evet
<option value="0" selected>Hayýr
</select>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Resim : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=resim size=20 class=inptxt value="yok">
</td>
</tr>
<tr><td colspan=2 style="border:1 solid lightgreen;" align=center>
<input type=submit value="Kaydet" class=sub>
</table>
<input type=hidden name=geldimi value="evet">
</form>

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