<%response.buffer=true%>
<%sayfaadi="Özel Deðiþtir - " & request.querystring("n")%>
<%sayfaurl="ozeldegistir.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<%
if session_uyegiris = "evet" then

set ks=bag.execute("select * from uyeler where id="&session_uyeid)
if ks.eof then
response.write "Böyle bir kullanýcý sistemimizde kayýtlý deðildir."
response.end
end if

islem = request.querystring("n")

if islem = "sifre" then
if request.form("geldimi") = "evet" then

eskisif = trim(request.form("eskisifre"))
yenisif = trim(request.form("yenisifre"))
yenisiftek = trim(request.form("yenisifretekrar"))

if len(eskisif)=0 then
msg = "Þifreni deðiþtirebilmek için eski þifreni girmen gerekiyor<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(yenisif)=0 then
msg = "Þifreni deðiþtirebilmek için yeni þifreni girmen gerekiyor<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(yenisiftek)=0 then
msg = "Þifreni deðiþtirebilmek için yeni þifreni tekrar girmen gerekiyor<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if ks("sifre") <> eskisif then
msg = "Þifreni yanlýþ girdin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

call uzunlukkontrol(yenisif,20,"<i>yeni þifre</i>","ozeldegistir.asp")

if yenisif <> yenisiftek then
msg = "Girdiðin þifreler birbirleriyle uyuþmuyor<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler where id="&session_uyeid,bag,1,3

rs("sifre") = yenisif

rs.update
rs.close

response.write "Tebrikler!Þifreniz baþarýyla deðiþtirildi.<br><br><a href=uyeduzenle.asp>Bilgilerim sayfasýna dönmek için týklayýnýz</a>"

else
%>
<br>
<form method="post" name="sifreduzenleform" action="ozeldegistir.asp?n=sifre">
<table border=0 cellpadding=0 cellspacing=0 width=330>
<tr>
<td width=15 height=15 background="kose_su.gif">
</td>
<td style=background:#FFFFCC;" width=300 height=15>

</td>
<td width=15 height=15 background="kose_sau.gif">
</td>
</tr>

<tr>
<td width=15 height=150 style="background:#FFFFCC;">

</td>
<td width=300 height=150 bgcolor=#FFFFCC style="font-size:11;">

<table border=0 cellpadding=2 cellspacing=2>
<CAPTION ALIGN=top>
<font class=inptxt style="color:red;font-size:12;border:0;">

Lütfen bilgilerinizi eksiksiz giriniz.

</font>
</CAPTION>
<tr>
<td align=right>
<b>Eski Þifre : </b>
</td>
<td align=left>
<input type=password name=eskisifre size=20 class=inptxt>
</td></tr>
<tr>
<td align=right>
<b>Yeni Þifre : </b>
</td>
<td align=left>
<input type=password name=yenisifre size=20 class=inptxt>
</td></tr>
<tr>
<td align=right>
<b>Yeni Þifre Tekrar : </b>
</td>
<td align=left>
<input type=password name=yenisifretekrar size=20 class=inptxt>
</td></tr>
<tr>
<td align=right colspan=2>
<input type=submit name=sbit class=sub value="Kaydet">
</td>
</tr>
<tr>
<td align=center colspan=2>
<small>...............sdal.org............</small>
</td>
</tr>
</table>

</td>
<td width=15 height=150 style="background:#FFFFCC;">

</td>
</tr>

<tr>
<td width=15 height=15 background="kose_sa.gif">
</td>
<td style=background:#FFFFCC;" width=300 height=15>

</td>
<td width=15 height=15 background="kose_saa.gif">
</td>
</tr>
</table>
<input type=hidden name=geldimi value="evet">

</form>
<br>
<%
end if

elseif islem = "email" then
response.write "Bu servis þu anda hizmet dýþýdýr."
else
response.redirect "uyeduzenle.asp"
end if


%>
<br>



<%
else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->