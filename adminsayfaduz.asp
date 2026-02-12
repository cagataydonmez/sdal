<%response.buffer=true%>
<%sayfaadi="Yönetim Sayfa Düzenleme"%>
<%sayfaurl="adminsayfaduz.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
| <a href="adminsayfalar.asp">Sayfalar</a> | 
<hr color=brown size=1>
<%if request.form("geldimi") = "evet" then

sfid = request.form("sfid")

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
rs.open "select * from sayfalar where id="&sfid,bagg,1,3

rs("sayfaismi") = sayfaismi
rs("sayfaurl") = ysayfaurl
rs("babaid") = babaid
rs("menugorun") = menugorun
rs("yonlendir") = yonlendir
rs("mozellik") = mozellik
rs("resim") = resim

rs.update
rs.close
%>
Düzenleme iþlemi baþarýyla tamamlandý!<br>Sayfa ID:<%=sfid%> | Yeni sayfa ismi:<%=sayfaismi%><br><br>
<a href="adminsayfalar.asp">| Sayfalar |</a>
<%
else
sfid = request.querystring("sfid")
set ks=server.createobject("adodb.recordset")
ks.open "select * from sayfalar where id="&sfid,bagg,1
%>
<form method=post action="adminsayfaduz.asp" name="Sayfaduzform">
<table border=0 cellpadding=3 cellspacing=1>
<tr><td colspan=2 style="border:1 solid lightgreen;font-weight:bold;color:brown;font-size:14;">
<center>Sayfa Düzenle:<%=ks("sayfaismi")%></center>
</td></tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Sayfa Ýsmi : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=sayfaismi size=20 class=inptxt value="<%=ks("sayfaismi")%>">
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Sayfa URL : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=sayfaurl size=20 class=inptxt value="<%=ks("sayfaurl")%>">
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Baba ID : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=babaid size=20 class=inptxt value="<%=ks("babaid")%>">
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Menüde Görünsün mü? : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<select name=menugorun class=inptxt>
<option value="1"<%if ks("menugorun") = 1 then%> selected<%end if%>>Evet
<option value="0"<%if ks("menugorun") = 0 then%> selected<%end if%>>Hayýr
</select>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Yönlendirme var mý? : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<select name=yonlendir class=inptxt>
<option value="1"<%if ks("yonlendir") = 1 then%> selected<%end if%>>Evet
<option value="0"<%if ks("yonlendir") = 0 then%> selected<%end if%>>Hayýr
</select>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
M.Özellik? : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<select name=mozellik class=inptxt>
<option value="1"<%if ks("mozellik") = 1 then%> selected<%end if%>>Evet
<option value="0"<%if ks("mozellik") = 0 then%> selected<%end if%>>Hayýr
</select>
</td>
</tr>
<tr>
<td style="border:1 solid lightgreen;font-weight:bold;" align=right>
Resim : 
</td>
<td style="border:1 solid lightgreen;" align=left>
<input type=text name=resim size=20 class=inptxt value="<%=ks("resim")%>">
</td>
</tr>
<tr><td colspan=2 style="border:1 solid lightgreen;" align=center>
<input type=submit value="Kaydet" class=sub>
</table>
<input type=hidden name=geldimi value="evet">
<input type=hidden name=sfid value="<%=sfid%>">
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