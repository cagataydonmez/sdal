<%response.buffer=true%>
<%sayfaadi="Þifre Hatýrlama"%>
<%sayfaurl="sifrehatirla.asp"%>
<%sifresiz = "evet"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<% if session_uyegiris = "evet" then%>
Zaten giriþ yapmýþsýn!<br><br>
<a href="default.asp" title="Anasayfa">Anasayfaya gidebilirsin..</a>
<%else
step=request.form("step")
if step = "iki" then

set ks=server.createobject("adodb.recordset")
if request.form("deg") = "kadi" then
ks.open "select * from uyeler where kadi = '"&request.form("kadi")&"'",bag,1
elseif request.form("deg") = "email" then
ks.open "select * from uyeler where email = '"&request.form("email")&"'",bag,1
else
response.write "hata!!!"
response.end
end if
if ks.eof then
call hatamsg("Böyle bir kullanýcý kayýtlý deðil!","sifrehatirla.asp")
else
call sifregonder(ks("id"),ks("kadi"),ks("sifre"),ks("email"),ks("isim"),ks("soyisim"))
%>
Sayýn <b><%=ks("isim")%> <%=ks("soyisim")%></b>,<br>
Þifreniz e-mail adresinize gönderildi.
<%
end if
%>

<%else%>

<br>


<table border=0 cellpadding=0 cellspacing=0 width=330 style="border:1 solid #000033;">
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
<font class=inptxt style="color:red;font-size:12;border:0;">Lütfen size uygun seçeneði kullanýnýz.<br>Kullanýcý adýnýz ve þifreniz e-mail adresinize postalanacaktýr.</font>
</CAPTION>
<form method="post" name="sifrehatirlaform" action="sifrehatirla.asp">
<input type=hidden name=deg value="kadi">
<input type=hidden name=step value="iki">
<tr>
<td align=right>
<b>Kullanýcý Adým : </b>
</td>
<td align=left>
<input type=text name=kadi size=20 class=inptxt value="<%=request.querystring("kadi")%>">
</td>
<td align=left>
<input type=submit name=kadibut value="Gönder" class=sub>

</td>
</tr>
</form>
<form method="post" name="sifrehatirlaform2" action="sifrehatirla.asp">
<input type=hidden name=deg value="email">
<input type=hidden name=step value="iki">
<tr>
<td align=right>
<b>E-mail Adresim : </b>
</td>
<td align=left>
<input type=text name=email size=20 class=inptxt>
</td>
<td align=left>
<input type=submit name=emailbut value="Gönder" class=sub>

</td>
</tr>
</form>
<tr>
<td align=center colspan=3>
<a href="uyekayit.asp" title="hemen kaydolun">sdal.org sitesine kayýt yaptýrmak için týklayýn.</a>
<br><a href="default.asp" title="Anasayfa">Anasayfaya gitmek için buraya týklayýn.</a>
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
<input type=hidden name=g value="evet">
<input type=hidden name=sayfa value="<%=sayfa%>">
</form>

<%
end if
end if
%>

<!--#include file="ayak.asp"-->