<!--#include file="kodlar.asp"-->
<%
if session_uyegiris <> "evet" then

'############# IP KAyýt kodlarý ##################
if request.cookies("iplog") <> Request.ServerVariables("REMOTE_ADDR") then

response.cookies("iplog") = Request.ServerVariables("REMOTE_ADDR")


klasor = "hatalog"
set ipsay=CreateObject("Scripting.FileSystemObject")
yol = ipsay.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)
'response.write yol
If ipsay.FolderExists(yol) = True Then

tarih = date()
dizi = split(tarih,"/",-1,1)
dosya = "sayac" & dizi(0) & dizi(2) & ".txt"

If ipsay.FileExists(ipsay.buildpath(yol,dosya)) = False Then 
ipsay.CreateTextFile ipsay.buildpath(yol,dosya)
Set gc2 = ipsay.OpenTextFile(ipsay.buildpath(yol,dosya),2,0)
gc2.WriteLine("IP SAYAÇ")
gc2.WriteLine("---------------------------------")
gc2.WriteBlankLines(1)
gc2.Close
end if

Set htlog2 = ipsay.OpenTextFile(ipsay.buildpath(yol,dosya),8,0)

htlog2.WriteLine(Request.ServerVariables("REMOTE_ADDR"))
htlog2.WriteBlankLines(1)
htlog2.close
end if

end if

'#####################################################

g=request.form("g")
if g="evet" then

kadi=request.form("kadi")
sifre=request.form("sifre")

'######## sql injection korumasý ###########
kadi=Replace(kadi,"'","''")
sifre=Replace(sifre,"'","''")
'######## sql injection korumasý bitiþi ###########

sayfa=request.form("sayfa")

if len(kadi)=0 then
msg="Kullanýcý adýný yazmazsan siteye giremezsin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

if len(sifre)=0 then
msg="Siteye girmek için þifreni de yazman gerekiyor.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

set ks=server.createobject("adodb.recordset")
ks.open "select * from uyeler where kadi='"&kadi&"'",bag,1

if ks.eof then
call hatamsg("Sdal.org sitesinde böyle bir kullanýcý henüz kayýtlý deðil.<br><br><a href=uyekayit.asp?kadi="&kadi&">Kayýt yaptýrmak için týkla!!!</a>",sayfa)
response.end
elseif ks("yasak") = 1 then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & "</b>, siteye giriþiniz yasaklanmýþ!<br>Lütfen site yöneticisiyle irtibata geçiniz.",sayfa)
response.end
elseif ks("aktiv") = 0 then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & "</b>, onay iþleminizi henüz tamamlamamýþsýnýz.<br>Lütfen mail adresinize gönderdiðimiz maildeki linke týklayýnýz.<br>Tekrar mail almak için <a href=""aktgnd.asp?id="&ks("id")&""">týklayýnýz</a>",sayfa)
response.end
end if

'####### Çerez kontrolü ######
response.cookies("kon") = "a"
if request.cookies("kon") <> "a" then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & "</b>, <br>tarayýcýnýz çerezleri desteklemiyor.<br> Siteye girebilmeniz için çerezleri açmanýz gerekmektedir.",sayfa)
response.end
end if
'####### Çerz kon. bitiþ #####

set ks2=server.createobject("adodb.recordset")
ks2.open "select * from uyeler where kadi='"&kadi&"' and sifre='"&sifre&"'",bag,1,3

if ks2.eof then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & ", </b>girdiðin þifre yanlýþ!<br>Eðer þifreni hatýrlamýyorsan, <a href=sifrehatirla.asp?kadi="&kadi&">buraya týkla!</a>",sayfa)
response.end
end if

response.cookies("uyegiris") = "evet"
response.cookies("uyeid") = ks2("id")
response.cookies("kadi") = ks2("kadi")

session_uyegiris = request.cookies("uyegiris")
session_uyeid = request.cookies("uyeid")
session_kadi = request.cookies("kadi")

ks2("online") = 1
ks2("hit") = ks2("hit") + 1
ks2("sontarih") = now()

if ks2("sonislemtarih") <> Null and ks2("sonislemsaat") <> Null then
ks2("oncekisontarih") = cdate(ks2("sonislemtarih") & " " & ks2("sonislemsaat"))
else
ks2("oncekisontarih") = now()
end if

ks2.update

if ks("ilkbd") = 0 then
response.redirect "uyeduzenle.asp?sayfa="&sayfa
else
response.redirect sayfa
end if

else

sayfa=request.servervariables("url")
if right(sayfa,12) = "uyegiris.asp" then
%>
<!--#include file="kafa.asp"-->
<%
response.write "<center><font style=""font-family:verdana;font-size:14;color:red;""><b>yanlýþ giriþ!!<br><br><a href=""default.asp"">anasayfaya gitmek için týkla...</a></b></font></center>"
%>
<!--#include file="ayak.asp"-->
<%
response.end
end if
%>
<br>

<table border=0 cellpadding=0 cellspacing=0 width=100%>
<tr>
<td valign=top>

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Üye Giri&#351;i</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>

<form method="post" name="uyegirisform" action="<%=sayfa%>">

<table border=0 cellpadding=2 cellspacing=2>
<CAPTION ALIGN=top>
<font class=inptxt style="color:red;font-size:12;border:0;">Lütfen kullanýcý adýnýzý ve þifrenizi giriniz.</font>
</CAPTION>
<tr>
<td align=right>
<b>Kullan&#305;c&#305; Ad&#305; : </b>
</td>
<td align=left>

<input type=text name=kadi size=20 class=inptxt>
</td></tr>
<tr>
<td align=right>
<b>&#350;ifre : </b>
</td>
<td align=left>
<input type=password name=sifre size=20 class=inptxt>
</td></tr>
<tr>
<td align=right colspan=2>
<input type=submit name=sbit class=sub value="Giriþ">
</td>
</tr>
<tr>
<td align=center colspan=2>

<br><a href="sifrehatirla.asp" title="Þifremi Unuttum :(">þifrenizi veya kullanýcý adýnýzý unuttuysanýz buraya týklayýn.</a>
</td>
</tr>
</table>

<input type=hidden name=g value="evet">
<input type=hidden name=sayfa value="<%=sayfa%>">
</form>

</td>
</tr>
</table>

</td>
<td>

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Siteye Giri&#351; Yapmadan Önce Unutmay&#305;n&#305;z ki;</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;font-size:15;" align=left valign=middle>
1 - Sitede siyaset tart&#305;&#351;mayal&#305;m, siyasi propaganda yapmayal&#305;m,
<br>
2 - K&#305;r&#305;c&#305; sözler kullanmayal&#305;m, ki&#351;ilere, ki&#351;ilik haklar&#305;na, veya gruplara hakaret etmeyelim,
<br>
3 - Mezuniyet y&#305;l&#305;m&#305;z&#305;, ismimizi ve soyismimizi do&#287;ru girelim. (Aksi takdirde üyeli&#287;imiz silinir)
<br>
4 - Sitemizin amac&#305; ayn&#305; okulu belli bir dönem payla&#351;m&#305;&#351; olan insanlar&#305;n ileti&#351;iminin sa&#287;lanmas&#305;d&#305;r, bu amaca ayk&#305;r&#305; hareket etmeyelim,
<br><br>
Bu kurallara uyal&#305;m, uymayanlar&#305; uyaral&#305;m..
</td>
</tr>
</table>

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>ÜYE OLMAK &#304;ST&#304;YORUM</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>

<center><font style="font-family:comic sans ms;font-size:18;color:blue;"><b><a href="uyekayit.asp">Üye olmak için buraya týklayýn.</a></b></font></center>

</td>
</tr>
</table>


</td>
</tr>
</table>

<%'###########################################################%>

<br>
<%end if%>
<%else%>
<!--#include file="kafa.asp"-->
<%
response.write "<center><font style=""font-family:verdana;font-size:12;color:red;""><b>Yanlýþ giriþ!!<br>Üyelik giriþi yapýlmýþ...<br><br><a href=""default.asp"">Anasayfaya gitmek için týkla...</a></b></font></center>"
%>
<!--#include file="ayak.asp"-->
<%end if%>