<!--#include file="kodlar.asp"-->
<%
if session_uyegiris <> "evet" then

'############# IP KAyyt kodlary ##################
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

'######## sql injection korumasy ###########
kadi=Replace(kadi,"'","''")
sifre=Replace(sifre,"'","''")
'######## sql injection korumasy biti?i ###########

sayfa=request.form("sayfa")

if len(kadi)=0 then
msg="Kullanycy adyny yazmazsan siteye giremezsin.<br>Ystersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

if len(sifre)=0 then
msg="Siteye girmek için ?ifreni de yazman gerekiyor.<br>Ystersen tekrar dene!"
call hatamsg(msg,sayfa)
response.end
end if

set ks=server.createobject("adodb.recordset")
ks.open "select * from uyeler where kadi='"&kadi&"'",bag,1

if ks.eof then
call hatamsg("Sdal.org sitesinde böyle bir kullanycy henüz kayytly de?il.<br><br><a href=uyekayit.asp?kadi="&kadi&">Kayyt yaptyrmak için tykla!!!</a>",sayfa)
response.end
elseif ks("yasak") = 1 then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & "</b>, siteye giri?iniz yasaklanmy?!<br>Lütfen site yöneticisiyle irtibata geçiniz.",sayfa)
response.end
elseif ks("aktiv") = 0 then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & "</b>, onay i?leminizi henüz tamamlamamy?synyz.<br>Lütfen mail adresinize gönderdi?imiz maildeki linke tyklayynyz.<br>Tekrar mail almak için <a href=""aktgnd.asp?id="&ks("id")&""">tyklayynyz</a>",sayfa)
response.end
end if

'####### Çerez kontrolü ######
response.cookies("kon") = "a"
if request.cookies("kon") <> "a" then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & "</b>, <br>tarayycynyz çerezleri desteklemiyor.<br> Siteye girebilmeniz için çerezleri açmanyz gerekmektedir.",sayfa)
response.end
end if
'####### Çerz kon. biti? #####

set ks2=server.createobject("adodb.recordset")
ks2.open "select * from uyeler where kadi='"&kadi&"' and sifre='"&sifre&"'",bag,1,3

if ks2.eof then
call hatamsg("Merhaba <b>" & ks("isim") & " " & ks("soyisim") & ", </b>girdi?in ?ifre yanly?!<br>E?er ?ifreni hatyrlamyyorsan, <a href=sifrehatirla.asp?kadi="&kadi&">buraya tykla!</a>",sayfa)
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
response.write "<center><font style=""font-family:verdana;font-size:14;color:red;""><b>yanly? giri?!!<br><br><a href=""default.asp"">anasayfaya gitmek için tykla...</a></b></font></center>"
%>
<!--#include file="ayak.asp"-->
<%
response.end
end if
%>
<br>



<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td align=right>


<table border=0 cellpadding=0 cellspacing=0>
<tr>
<td width=15 height=15 background="kose_su.gif">
&nbsp;
</td>
<td style=background:#FFFFCC;" width=100% height=15>
&nbsp;
</td>
<td width=15 height=15 background="kose_sau.gif">
&nbsp;
</td>
</tr>

<tr>
<td width=15 height=215 style="background:#FFFFCC;">
&nbsp;
</td>
<td height=215 bgcolor=#FFFFCC style="font-size:11;" width=100%>

<table border=0 cellpadding=5 cellspacing=1 width=100%>
<tr>
<td width=100% style="background:#ffffcc;border:0 solid #663300;" align=center>

<table border=0 cellpadding=0 cellspacing=0>
<tr>
<td style="border:0;color:blue;font-family:comic sans ms;font-size:15;font-weight:bold;" align=justify>
Siteye giri? yapmadan önce unutmayynyz ki;
<br><br>
1 - Sitede siyaset tarty?mayalym, siyasi propaganda yapmayalym,
<br>
2 - Kyrycy sözler kullanmayalym, ki?ilere, ki?ilik haklaryna, veya gruplara hakaret etmeyelim,
<br>
3 - Mezuniyet yylymyzy, ismimizi ve soyismimizi do?ru girelim. (Aksi takdirde üyeli?imiz silinir)
<br>
4 - Sitemizin amacy ayny okulu belli bir dönem payla?my? olan insanlaryn ileti?iminin sa?lanmasydyr, bu amaca aykyry hareket etmeyelim,
<br><br>
Bu kurallara uyalym, uymayanlary uyaralym..
</td>
</tr>
</table>

</td>
</tr>
</table>


</td>
<td width=15 height=215 style="background:#FFFFCC;">
&nbsp;
</td>
</tr>

<tr>
<td width=15 height=15 background="kose_sa.gif">
&nbsp;
</td>
<td style=background:#FFFFCC;" height=15 width=100%>
&nbsp;
</td>
<td width=15 height=15 background="kose_saa.gif">
&nbsp;
</td>
</tr>
</table>


</td>
<td align=right width=330>


<form method="post" name="uyegirisform" action="<%=sayfa%>">
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
<font class=inptxt style="color:red;font-size:12;border:0;">Lütfen kullanycy adynyzy ve ?ifrenizi giriniz.</font>
</CAPTION>
<tr>
<td align=right>
<img src="kadi.gif" border=0><br>
</td>
<td align=left>

<input type=text name=kadi size=20 class=inptxt>
</td></tr>
<tr>
<td align=right>
<img src="sifre.gif" border=0>
</td>
<td align=left>
<input type=password name=sifre size=20 class=inptxt>
</td></tr>
<tr>
<td align=right colspan=2>
<input type=submit name=sbit class=sub value="Giri?">
</td>
</tr>
<tr>
<td align=center colspan=2>
<a href="uyekayit.asp" title="hemen kaydolun">sdal.org sitesine üye olmak buraya için tyklayyn.</a>
<br><a href="sifrehatirla.asp" title="?ifremi Unuttum :(">?ifrenizi veya kullanycy adynyzy unuttuysanyz buraya tyklayyn.</a>
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

<%'#################################################%>

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
<td width=15 height=50 style="background:#FFFFCC;">

</td>
<td width=300 height=50 bgcolor=#FFFFCC style="font-size:11;">
<center><font style="font-family:comic sans ms;font-size:18;color:blue;"><b><a href="uyekayit.asp">Üye olmak için buraya tyklayyn.</a></b></font></center>
</td>
<td width=15 height=50 style="background:#FFFFCC;">

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



</td>
</tr>





</table>
<%'###########################################################%>

<br>
<%end if%>
<%else%>
<!--#include file="kafa.asp"-->
<%
response.write "<center><font style=""font-family:verdana;font-size:12;color:red;""><b>Yanly? giri?!!<br>Üyelik giri?i yapylmy?...<br><br><a href=""default.asp"">Anasayfaya gitmek için tykla...</a></b></font></center>"
%>
<!--#include file="ayak.asp"-->
<%end if%>