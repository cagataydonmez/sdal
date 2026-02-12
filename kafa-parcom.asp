<SCRIPT LANGUAGE="Javascript">
<!---
if (parent.frames.length)
parent.location.href= self.location; 
// --->
</SCRIPT>

<%
session.timeout = 120

'##################### Bakým -Giriþ Sayfasý vesaire için kodlar ############################

set bkm=CreateObject("Scripting.FileSystemObject")
dosya = bkm.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),"bkm.txt")
If bkm.FileExists(dosya) = True Then

Set dsy = bkm.OpenTextFile(dosya)

durum = dsy.ReadLine
if durum = "evet" then
	response.redirect dsy.ReadLine
end if

End If
'###########################################################################################
if len(sayfaurl)<>0 then
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")
set sff=server.createobject("adodb.recordset")
sff.open "select * from sayfalar where sayfaurl='"&sayfaurl&"'",bagg,1,3
if sff.eof then
sayfayok=1
else
sayfayok=0
sayfaid = sff("id")
if sff("resim") = "yok" then
sayfaresim="transparan.gif"
else
sayfaresim=sff("resim")
end if
end if
end if

gelenip = Request.ServerVariables("REMOTE_ADDR")


if sayfayok=0 then
sff("sontarih") = now()
sff("hit") = sff("hit") + 1
sff("sonip") = gelenip
end if
%>
<% 
if session("uyegiris") = "evet" then
set rewt=server.createobject("adodb.recordset")
rewt.open "select * from uyeler where id="&session("uyeid"),bagg,1,3

rewt("sonislemtarih") = date()
rewt("sonislemsaat") = time()


if sayfayok=0 then
if not sff("sayfaurl") = "fotogoster.asp" then
'############################### Sayfaya giren üye kayýtlarý ##################################
klasor = "sayfalog"
set ssay=CreateObject("Scripting.FileSystemObject")
yol = ssay.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)

If ssay.FolderExists(yol) = True Then

tarih = now()

dosya = sff("id") & month(tarih) & year(tarih) & ".txt"

If ssay.FileExists(ssay.buildpath(yol,dosya)) = False Then 
ssay.CreateTextFile ssay.buildpath(yol,dosya)
Set ss = ssay.OpenTextFile(ssay.buildpath(yol,dosya),2,0)
ss.WriteLine("Sayfa Üye Kayýtlarý - "&sff("sayfaismi"))
ss.WriteLine("---------------------------------")
ss.WriteBlankLines(1)
ss.Close
end if

Set slog = ssay.OpenTextFile(ssay.buildpath(yol,dosya),8,0)

slog.WriteLine(rewt("kadi"))
slog.WriteLine(Dateadd("h", 10, now()))
slog.WriteBlankLines(1)
slog.close
end if
'############################### Sayfaya giren üye kayýtlarý bitiþi ##################################
end if
sff("sonuye") = rewt("kadi")

sff.update

sff.close
end if

if rewt("online") = 0 then
session.abandon()
response.redirect "default.asp"
end if


rewt("sonip") = gelenip
rewt("online") = 1

rewt.update



end if
if sayfaurl <> "cikis.asp" then
call sitedekiler_kontrol(bagg)
end if

'############# Üyenin IP Kayýt kodlarý ##################
if session("uyegiris") = "evet" then

if session("iplog2") <> Request.ServerVariables("REMOTE_ADDR") then

session("iplog2") = Request.ServerVariables("REMOTE_ADDR")

klasor = "hatalog"
set ipsay2=CreateObject("Scripting.FileSystemObject")
yol = ipsay2.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)

If ipsay2.FolderExists(yol) = True Then

tarih = date()
dizi = split(tarih,"/",-1,1)
dosya = "uyeip" & dizi(0) & dizi(2) & ".txt"

If ipsay2.FileExists(ipsay2.buildpath(yol,dosya)) = False Then 
ipsay2.CreateTextFile ipsay2.buildpath(yol,dosya)
Set gc2 = ipsay2.OpenTextFile(ipsay2.buildpath(yol,dosya),2,0)
gc2.WriteLine("UYE IP Kayýt")
gc2.WriteLine("---------------------------------")
gc2.WriteBlankLines(1)
gc2.Close
end if

Set htlog2 = ipsay2.OpenTextFile(ipsay2.buildpath(yol,dosya),8,0)

htlog2.WriteLine(Request.ServerVariables("REMOTE_ADDR")&" - "&rewt("kadi")&" - "&now())
htlog2.WriteBlankLines(1)
htlog2.close
end if

end if

end if
'#######################################################

%>

<html>
<head>
<title>sdal . org - Ankara SDAL Mezunlarý Web Sitesi - Yapým Aþamasýnda - <%=sayfaadi%></title>
<LINK href="sdal.ico" rel="SHORTCUT ICON">
<META http-equiv=Content-Type content="text/html; charset=windows-1254">
<!--#include file="stil.asp"-->
<script src="ayax.asp"></script>
<!--#include file="hint.inc"-->
</head>
<body bgcolor="#663300" topmargin=0 leftmargin=0<%if session("uyegiris") <> "evet" and sifresiz <> "evet" then%> onload=uyegirisform.kadi.focus();<%end if%>>
<table border=0 width=100% height=100% cellpadding=0 cellspacing=0>
<tr>
<td width=100% height=100% bgcolor="#663300" align=center valign=center>

<table border=0 width=100% height=300 cellpadding=0 cellspacing=0>
<tr>
<td width=100% height=50 align=left valign=bottom style="background:#663300;">
<a href="default.asp" title="Anasayfaya gider..."><img src="logo.gif" border=0></a> <font style="color:#ffcc99;font-size:20;font-family:arial;">-<b> Yapým Aþamasýnda</font></b>
<%if not sayfaadi="Anasayfa" then%>
<%if sayfayok then%>
<font style="color:#ffcc99;font-size:15;font-family:arial;">- Bu sayfa menülerde kayýtlý deðildir.</font>
<%else%>
<img src="<%=sayfaresim%>" border=0>
<%end if%>
<%end if%>
<!--##<font style="color:#ffcc99;font-size:18;font-family:arial;"><b> - <%=sayfaadi%></b></font>-->
</td>
</tr>
<tr>
<td width=100% height=8 align=left valign=bottom background="upback.gif">
</td>
</tr>
<tr>
<td width=100% height=150 align=center valign=center style="background:#FFCC99;">

<% if session("uyegiris") = "evet" then %>
<%'################## MENÜ BAÞLANGICI ###################################### %>

<table border=0 cellpadding=3 cellspacing=0 width=100% height=100%>
<tr>
<td style="border:1 solid #000033;background:#ffffdd;" width=150 valign=top>

<table border=0 cellpadding=3 cellspacing=2 width=100%>


<tr><td style="border:1 solid #663300;">
<% if rewt("resim") <> "yok" then %>

<img src="kucukresim2.asp?iwidth=138&r=<%=rewt("resim")%>" border=0 width=138>

<%'############### Image Düzenlemeleri ####################%>

<%' if session("threshold") = "evet" then
'<br>
'<a href="threshold.asp">Normale Çevir</a>
'else
'<br>
'<a href="threshold.asp">Threshold yap</a>
'end if

' if session("grayscale") = "evet" then 
'<br>
'<a href="grayscale.asp">Normale Çevir</a>
'else
'<br>
'<a href="grayscale.asp">Grayscale yap</a>
'end if%>

<%'############### Image Düzenlemeleri Bitiþi ####################%>


<% else %>
<img src="vesikalik/nophoto.jpg" border=0 width=138>
<% end if %>

<br>
<a href="vesikalikekle.asp">Fotoðraf Ekle/Düzenle</a>
</td></tr>

<tr><td style="border:0;background:#660000;color:white;">
<b>MENÜ</b>
</td></tr>

<%
set km=bagg.execute("select * from sayfalar where menugorun = 1 order by sayfaismi")
if not km.eof then

do while not km.eof
if km("sayfaurl") <> "sifrehatirla.asp" and km("sayfaurl") <> "uyekayit.asp" then
%>
<tr><td style="border:0;">
<img src="arrow-orange.gif" border=0><a href="<%=km("sayfaurl")%>" title="Nereye --> <%=km("sayfaismi")%>" class=menulink><%=km("sayfaismi")%></a><br>
</td></tr>
<%
end if
km.movenext
loop
end if
%>
<tr><td style="border:0;">
<hr color=#662233 size=1>
<img src="arrow-orange.gif" border=0><a href="cikis.asp" title="Güvenli bir þekilde çýkmak için týklayýnýz." class=menulink>Güvenli Çýkýþ</a><br>
<hr color=#662233 size=1>
<%
set ymv=server.createobject("adodb.recordset")
ymv.open "select * from gelenkutusu where yeni=1 and kime='"&cstr(session("uyeid"))&"' and aktifgelen = 1",bagg,1
if not ymv.recordcount = 0 then
%>
<li style="color:#663300;"><b><a href="mesajlar.asp" title="Mesajlarý okumak için týklayýn." style="color:#663300;"><%=ymv.recordcount%></b> yeni mesajýnýz var!</a>
<%end if%>

<%'################## Shoutbox ############################ %>
<script language=javascript>
dinle();
function hmgonder(kim) {
if(kim.value != "") {
bekleyin="<center><b>Lütfen bekleyiniz..<br><br><img src=yukleniyor.gif border=0></b></center>";
document.getElementById("hmkutusu").innerHTML=bekleyin;

hmesajisle(kim.value);
kim.value = "";
}
}
var t;
function dinle() {
hmesajisle("ilkgiris2222tttt");
t=setTimeout("dinle()",5000)
}

</script>

<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>ANLIK ÝLETÝ</b>
</td>
</tr>
</table>
<div id="hmkutusu"><center><b>Lütfen bekleyiniz..<br><br><img src=yukleniyor.gif border=0></b></center></div>

<form name=hmform action="javascript:;" onsubmit="hmgonder(this.hmmetin);">
Mesaj : <br><input type=text name=hmmetin style="font-size:10;font-family:tahoma;"><input type=submit value=gönder style="font-size:10;font-family:tahoma;">
</form>

<%'################## Shoutbox Bitiþi############################ %>

</td></tr>
</table>

</td>
<td style="border:1 solid #000033;" align=center valign=top>
<%if not ymv.recordcount = 0 then%>
<table border=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="border:2 solid #660000;background:#ffffcc;" align=left valign=center>
<img src="arrow-orange.gif" border=0><a href="mesajlar.asp" title="Mesajlarý okumak için týklayýn." style="color:blue;"><b><%=ymv.recordcount%></b> yeni mesajýnýz var!</a>
</td></tr></table>
<%end if%>
<%end if%>