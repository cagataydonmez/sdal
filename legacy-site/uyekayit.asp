<%response.buffer=true%>
<%sayfaadi="Üye Kayýt Giriþi"%>
<%sayfaurl="uyekayit.asp"%>
<%sifresiz = "evet"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<%
if session_uyegiris <> "evet" then

islem=request.querystring("isl")
sayfa = "uyekayit.asp"
if islem="onay" then 'kullanýcý adý kontrolü,mail kontrolü ve onay

if request.form("onaygel") = "evet" then

kadi = trim(request.form("kadi"))
sifre = trim(request.form("sifre"))
sifre2 = trim(request.form("sifre2"))
email = trim(request.form("email"))
isim = trim(request.form("isim"))
soyisim = trim(request.form("soyisim"))
mezuniyetyili = request.form("mezuniyetyili")
gkodu = trim(request.form("gkodu"))

session("kadi_temp") = kadi
session("sifre_temp") = sifre
session("sifre2_temp") = sifre2
session("email_temp") = email
session("isim_temp") = isim
session("soyisim_temp") = soyisim
session("myili_temp") = mezuniyetyili

if cstr(Trim(Session("CAPTCHA"))) <> gkodu then
msg = "<b>Güvenlik Kodu</b> yanlýþ girildi.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

if len(kadi)=0 then
msg = "Kullanýcý adýný girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

call uzunlukkontrol(kadi,15,"kullanýcý adý","uyekayit.asp")

call filtre(kadi,"kullanýcý adý")

call dbkontrol(kadi,"uyeler","kadi","kullanýcý adý","uyekayit.asp")

if len(sifre)=0 then
msg = "Þifreni girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

call uzunlukkontrol(sifre,20,"Þifre","uyekayit.asp")

if sifre<>sifre2 then
msg = "Girdiðin þifreler birbirleriyle uyuþmuyor.(yani ayný deðil)<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

if len(email)=0 then
msg = "Email adresini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

call uzunlukkontrol(email,50,"e-mail adresi","uyekayit.asp")

emailkontrol(email)

if mezuniyetyili = "0" then
msg = "Bir mezuniyet yýlý seçmeniz gerekmektedir. Açýklamalar kayýt formunu altýnda yazmaktadýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

call dbkontrol(email,"uyeler","email","e-mail adresi","uyekayit.asp")

if len(isim)=0 then
msg = "Ýsmini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

call uzunlukkontrol(isim,20,"isim","uyekayit.asp")

if len(soyisim)=0 then
msg = "Soyismini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

call uzunlukkontrol(soyisim,20,"soyisim","uyekayit.asp")

%>
<font style="color:red;font-size:14;"><b>ONAYLIYOR MUSUNUZ?</b></font><br><br>
<b><%=isim%>&nbsp;<%=soyisim%></b>, girdiðin bilgileri onaylýyor musun?<br><br>
<b>Kullanýcý Adý : </b> <%=kadi%><br>
<b>E-Mail Adresi : </b> <%=email%><br>
<b>Mezuniyet Yýlý : </b> <%=mezuniyetyili%><br>
<form method=post action="uyekayit.asp?isl=kayit">
<input type=button value="Hayýr" onclick="history.back(1);" class=sub>&nbsp;<input type=submit value="EVET" class=sub>
<input type=hidden name=kadi value="<%=kadi%>">
<input type=hidden name=sifre value="<%=sifre%>">
<input type=hidden name=email value="<%=email%>">
<input type=hidden name=mezuniyetyili value="<%=mezuniyetyili%>">
<input type=hidden name=isim value="<%=isim%>">
<input type=hidden name=soyisim value="<%=soyisim%>">
<input type=hidden name=kayitgel value="evet">

</form>
<%
else
response.write "Yanlýþ giriþ!!!"
end if

elseif islem="kayit" then ' database'e kayýt ve aktivasyon üretimi ve maile gönderimi
if request.form("kayitgel") = "evet" then
kadi = request.form("kadi")

call dbkontrol(kadi,"uyeler","kadi","kullanýcý adý","onay.asp")

sifre = request.form("sifre")
email = request.form("email")
mezuniyetyili = request.form("mezuniyetyili")
isim = request.form("isim")
soyisim = request.form("soyisim")

aktivasyon = aktivuret()

set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler",bag,1,3

rs.addnew

rs("kadi") = kadi
rs("sifre") = sifre
rs("email") = email
rs("isim") = isim
rs("soyisim") = soyisim
rs("aktivasyon") = aktivasyon
rs("ilktarih") = now()
rs("resim") = "yok"
rs("mezuniyetyili") = mezuniyetyili

rs.update

call aktivasyongonder(rs("id"),kadi,sifre,email,isim,soyisim,aktivasyon)

kimden = "1" 'SDAL Hoþgeldin mesajcýsý üye ID numarasý

set mg=server.createobject("adodb.recordset")
mg.open "select * from gelenkutusu",bag,1,3

mg.addnew

mg("kime") = cstr(rs("id"))
mg("kimden") = kimden
mg("aktifgelen") = 1
mg("aktifgiden") = 1
mg("yeni") = 1
mg("konu") = "Hoþgeldiniz!"
mg("mesaj") = "Sdal.org - Süleyman Demirel Anadolu Lisesi Mezunlarý Web Sitesine hoþgeldiniz!<br><br>Bu <b>mesaj paneli</b> sayesinde diðer üyeler ile haberleþebilirsiniz.<br><br>Hoþça vakit geçirmeniz dileðiyle...<br><b><i>sdal.org</b></i>"
mg("tarih") = now()

mg.update

mg.close

rs.close

session("kadi_temp") = ""
session("email_temp") = ""
session("isim_temp") = ""
session("soyisim_temp") = ""
session("myili_temp") = ""
session("sifre_temp") = ""
session("sifre2_temp") = ""

session("kayityapildi") = "evet"

%>
Kaydýnýz baþarýyla tamamlandý!<br>
Kayýt iþleminizin onaylanmasý için lütfen mail adresinize gönderdiðimiz linke týklayýnýz!<br><br>
DÝKKAT! Eðer Yahoo,Hotmail,Mynet gibi bir sunucudan mail adresi sahibiyseniz <b>junk</b>,<b>spam</b>,<b>bulk</b> gibi klasörleri mutlaka kontrol ediniz. 
<%
else
response.write "Yanlýþ giriþ!!!"
end if
else 'form sayfasý
if session("kayityapildi") <> "evet" then
kadi = request.querystring("kadi")
%>

<br>
<form method="post" name="uyekayitform" action="uyekayit.asp?isl=onay">
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
<font class=inptxt style="color:red;font-size:12;border:0;">Bütün alanlarý eksiksiz doldurunuz.</font>
<hr color=#663300 size=1>
<font class=inptxt style="color:red;font-size:11;border:0;">Eðer daha önce kayýt yaptýrdýysanýz,lütfen tekrar kaydolmaya çalýþmayýnýz.<br>Þifrenizi <a href="sifrehatirla.asp">þifremi unuttum</a> linkiyle hatýrlayabilirsiniz.</font>
</CAPTION>
<tr>
<td align=center colspan=2>
<hr color=#663300 size=1>
</td>
</tr>
<tr>
<td align=right>
<b>Kullanýcý Adý : </b>
</td>
<%if kadi="" then
kadi = session("kadi_temp")
end if%>
<td align=left>
<input type=text name=kadi size=20 class=inptxt value="<%=kadi%>"> <font style="color:red;"><sup>1</sup></font>
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Siteye giriþ yaparken kullanacaðýnýz size özel kullanýcý adý.', this, event, '150px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b>Þifre : </b>
</td>
<td align=left>
<input type=password name=sifre size=20 class=inptxt value="<%=session("sifre_temp")%>">
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Siteye giriþ yaparken kullanacaðýnýz þifreniz.', this, event, '150px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b>Þifre Tekrar : </b>
</td>
<td align=left>
<input type=password name=sifre2 size=20 class=inptxt value="<%=session("sifre2_temp")%>">
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Þifrenizi tekrar yazýnýz. Yanlýþ yazmaya karþý önlem amaçlýdýr.', this, event, '200px')">[?]</a>
</td></tr>
<tr>
<td align=center colspan=2>
<hr color=#663300 size=1>
</td>
</tr>
<tr>
<td align=right>
<b>E-Mail : </b>
</td>
<td align=left>
<input type=text name=email size=20 class=inptxt value="<%=session("email_temp")%>"> <font style="color:red;"><sup>2</sup></font>
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Aktif olarak kullandýðýnýz e-mail adresinizi giriniz.<br> Adresinize aktivasyon linki gönderilecektir.', this, event, '220px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b><small>SDAL Mezuniyet Yýlý : </small></b>
</td>
<td align=left>
<select name=mezuniyetyili class=inptxt>
<option value="0">Seçiniz
<% for i=1999 to cint(right(date(),4))+4%>
<%if Len(session("myili_temp")) <> 0 then
myilikon = cint(session("myili_temp"))
end if%>
<option value="<%=i%>"<%if myilikon=i then%> selected<%end if%>><%=i%>
<%next%></select> <font style="color:red;"><sup>3</sup></font>
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Mezun olduðunuz veya olacaðýnýz yýlý seçiniz. Eðer SDALdan mezun olmadan önce ayrýldýysanýz, ayrýlmasaydýnýz hangi yýl mezun olacaktýysanýz o yýlý seçiniz.', this, event, '220px')">[?]</a>
</td></tr>
<tr>
<td align=center colspan=2>
<hr color=#663300 size=1>
</td>
</tr>
<tr>
<td align=right>
<b>Ýsim : </b>
</td>
<td align=left>
<input type=text name=isim size=20 class=inptxt value="<%=session("isim_temp")%>">
</td></tr>
<tr>
<td align=right>
<b>Soyisim : </b>
</td>
<td align=left>
<input type=text name=soyisim size=20 class=inptxt value="<%=session("soyisim_temp")%>">
</td></tr>
<tr>
<td align=center colspan=2>
<hr color=#663300 size=1>
</td>
</tr>
<tr>
<td align=right>

</td>
<td align=left>
<img src="aspcaptcha.asp" border=0><a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Resimde gördüðünüz güvenlik kodu sayýlarýný hemen altýndaki kutuya yazýnýz. Bu uygulama güvenlik amaçlýdýr.', this, event, '220px')">[?]</a>
</td></tr>
<tr>
<td align=right>
<b>Güvenlik Kodu : </b>
</td>
<td align=left>
<input type=text name=gkodu size=20 class=inptxt>
</td></tr>
<tr>
<td align=center colspan=2>
<hr color=#663300 size=1>
</td>
</tr>
<tr>
<td align=right colspan=2>
<input type=submit name=sbit class=sub value="Kaydet" onClick="this.value='Kaydediyor,lütfen bekleyiniz...';this.disabled=true;form.submit();">
</td>
</tr>
<tr>
<td align=center colspan=2>
<hr color=#663300 size=1>
</td>
</tr>
<tr>
<td align=left colspan=2 style="color:red;">
<sup>1</sup> Kullanýcý adýnýz 15 karakterden fazla olmamalýdýr.

<hr color="#663300" size=1>
<sup>2</sup> Sitemize kayýt olmak için e-mail adresinizi doðru girmeniz gerekmektedir.<br>
Çünkü e-mail adresinize bir aktivasyon kodu gönderilecek ve bu aktivasyon kodu sayesinde kaydýnýz onaylanacaktýr.
<hr color="#663300" size=1>
<sup>3</sup> Lütfen mezuniyet yýlýnýzý doðru giriniz.Kayýt iþlemi tamamlandýktan sonra mezuniyet yýlý deðiþtirilemez.<br>
Mezun olduðunuz veya olacaðýnýz yýlý seçiniz. Eðer SDALdan mezun olmadan önce ayrýldýysanýz, ayrýlmasaydýnýz hangi yýl mezun olacaktýysanýz o yýlý seçiniz.
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
<input type=hidden name=onaygel value="evet">
</form>
<br>
<%end if%>
<%end if%>
<%
else
response.write "Zaten üyelik giriþi yapmýþsýnýz..<br><br><a href=default.asp>Anasayfa</a>"
end if%>
<!--#include file="ayak.asp"-->