<%response.buffer=true%>
<%sayfaadi="Üyelik Bilgilerini Düzenle"%>
<%sayfaurl="uyeduzenle.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<%
if session_uyegiris = "evet" then

if request.form("geldimi") = "evet" then

isim = trim(request.form("isim"))
soyisim = trim(request.form("soyisim"))
sehir = trim(request.form("sehir"))
meslek = trim(request.form("meslek"))
websitesi = trim(request.form("websitesi"))

universite = trim(request.form("universite"))
dogumgun = trim(request.form("dogumgun"))
dogumay = trim(request.form("dogumay"))
dogumyil = trim(request.form("dogumyil"))
mailkapali = request.form("mailkapali")
imza = request.form("imza")

if len(isim)=0 then
msg = "Ýsmini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

call uzunlukkontrol(isim,20,"isim",sayfaurl)

if len(soyisim)=0 then
msg = "Soyismini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

call uzunlukkontrol(soyisim,20,"soyisim",sayfaurl)

set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler where id="&session_uyeid,bag,1,3

rs("isim") = isim
rs("soyisim") = soyisim
rs("sehir") = sehir
rs("meslek") = meslek
rs("websitesi") = websitesi

rs("universite") = universite
rs("dogumgun") = cint(dogumgun)
rs("dogumay") = cint(dogumay)
rs("dogumyil") = cint(dogumyil)
rs("mailkapali") = cint(mailkapali)
rs("imza") = imza

if request.form("ilkbd") = "0" then
rs("ilkbd") = 1
end if

rs.update
rs.close

if request.form("ilkbd") = "0" then

rdsayfa = request.form("sayfa")
if Len(rdsayfa) = 0 then
rdsayfa = "default.asp"
end if
if right(rdsayfa,4) <> ".asp" then
rdsayfa = "default.asp"
end if

response.redirect rdsayfa
else
session("uyeduzenleok") = "evet"
response.redirect "uyeduzenle.asp"
end if

else
nereye=request.querystring("sayfa")
set ks=bag.execute("select * from uyeler where id="&session_uyeid)
if ks.eof then
response.write "Böyle bir kullanýcý sistemimizde kayýtlý deðildir."
response.end
end if
%>
<%if session("uyeduzenleok") = "evet" then%>
<br>
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
<td width=15 height=10 style="background:#FFFFCC;">

</td>
<td width=300 height=10 bgcolor=#FFFFCC style="font-size:11;" align=left>

<b>Tebrikler!Bilgileriniz baþarýyla deðiþtirildi.</b>

</td>
<td width=15 height=10 style="background:#FFFFCC;">

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
<%session("uyeduzenleok") = ""
end if%>
<br>
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
<td width=15 height=10 style="background:#FFFFCC;">

</td>
<td width=300 height=10 bgcolor=#FFFFCC style="font-size:11;" align=left>

<li><a href="ozeldegistir.asp?n=sifre" title="þifre deðiþtir">Þifrenizi deðiþtirmek için týklayýnýz.</a><br>
<li><a href="ozeldegistir.asp?n=email" title="email deðiþtir">E-mail adresinizi deðiþtirmek için týklayýnýz.</a>

</td>
<td width=15 height=10 style="background:#FFFFCC;">

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

<form method="post" name="uyeduzenleform" action="uyeduzenle.asp">
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
<%if ks("ilkbd") = 0 then%>
Önemli! Lütfen Okuyunuz!!
<%else%>
Lütfen bilgilerinizi eksiksiz giriniz.
<%end if%>
</font>
<%if ks("ilkbd") = 0 then%>
<br><font class=inptxt style="color:#000033;font-size:10;border:0;">
Sdal.org'a hoþgeldiniz!!
Siteye ilk defa girdiðiniz için bu <i>üyelik bilgilerini düzenleme</i> sayfasýyla karþýlaþtýnýz.
Lütfen aþaðýdaki bilgileri doldurunuz.
Daha sonra giriþ yaptýðýnýzda bu sayfayla karþýlaþmayacaksýnýz.</font>
<%end if%>
</CAPTION>
<tr>
<td align=right>
<b>Ýsim : </b>
</td>
<td align=left>
<input type=text name=isim size=20 class=inptxt value="<%=ks("isim")%>">
</td></tr>
<tr>
<td align=right>
<b>Soyisim : </b>
</td>
<td align=left>
<input type=text name=soyisim size=20 class=inptxt value="<%=ks("soyisim")%>">
</td></tr>
<tr>
<td align=right>
<b>Þehir : </b>
</td>
<td align=left>
<select name=sehir class=inptxt>
<%
for i=0 to 80%>
<option value="<%=iller(i)%>"<%if ks("sehir") = iller(i) then%> selected<%end if%>><%=iller(i)%>
<%next%>
<option value="Yurt Dýþý"<%if ks("sehir") = "Yurt Dýþý" then%> selected<%end if%>>Yurt Dýþý
</select>
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Þu an oturduðunuz þehir.', this, event, '150px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b>Þu anki iþi : </b>
</td>
<td align=left>
<input type=text name=meslek size=20 class=inptxt value="<%=ks("meslek")%>"><a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Þu an çalýþtýðýnýz kurumu ve kurumdaki pozisyonunuzu yazýnýz.<br>Eðer þu an çalýþmýyorsanýz veya okuyorsanýz <i><b>çalýþmýyor</b></i> veya <i><b>okuyor</b></i> gibi küçük açýklayýcý kelimeler yazabilirsiniz', this, event, '200px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b>Web Sitesi : </b>
</td>
<td align=left>
<input type=text name=websitesi size=20 class=inptxt value="<%=ks("websitesi")%>"><a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Varsa web sitenizin adresini yazýnýz.', this, event, '150px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b><small>SDAL Mezuniyet Yýlý : </small></b>
</td>
<td align=left style="border-left:1 solid #663300;border-bottom:1 solid #663300;">
<b>
<font style=color:blue;><%=ks("mezuniyetyili")%></font>
</b> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Mezuniyet yýlýný deðiþtirmek için site yöneticisine baþvurmanýz gerekmektedir.', this, event, '150px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b><small>Ýlk Üniversite : </small></b>
</td>
<td align=left>
<input type=text name=universite size=20 class=inptxt value="<%=ks("universite")%>">
</td></tr>
<tr>
<td align=right>
<b>Doðumgünü : </b>
</td>
<td align=left>
<select name=dogumgun class=inptxt>
<%for i=1 to 31%>
<option value="<%=i%>"<%if ks("dogumgun")=i then%> selected<%end if%>><%=i%>
<%next%>
</select>.
<select name=dogumay class=inptxt>
<%for i=1 to 12%>
<option value="<%=i%>"<%if ks("dogumay")=i then%> selected<%end if%>><%=i%>
<%next%>
</select>.
<select name=dogumyil class=inptxt>
<%for i=1975 to 1999%>
<option value="<%=i%>"<%if ks("dogumyil")=i then%> selected<%end if%>><%=i%>
<%next%>
</select>
</td></tr>
<tr>
<td align=right>
<b><small>Mailim görünsün mü? : </small></b>
</td>
<td align=left>
<select name=mailkapali class=inptxt>
<option value=0<%if ks("mailkapali") = 0 then%> selected<%end if%>>Evet
<option value=1<%if ks("mailkapali") = 1 then%> selected<%end if%>>Hayýr
</select>
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>E-Mail adresinizin diðer üyeler tarafýndan görülmesini istemiyorsanýz,<i><b>hayýr</b></i> seçeneðini seçiniz.', this, event, '200px')">[?]</a>
</td></tr>
<tr>
<td align=right valign=top>
<b>Açýklama : </b>
</td>
<td align=left>
<textarea name=imza cols=23 rows=5 class=inptxt><%=ks("imza")%></textarea><a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Kendinizle ilgili belirtmek istediðiniz ek açýklamalar için bu alaný kullanýn.', this, event, '200px')">[?]</a>
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
<input type=hidden name=sayfa value="<%=nereye%>">
<input type=hidden name=geldimi value="evet">
<input type=hidden name=ilkbd value="<%=ks("ilkbd")%>">

</form>
<br>
<%
end if
else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->