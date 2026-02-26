<SCRIPT LANGUAGE="Javascript">
<!---
if (parent.frames.length)
parent.location.href= self.location; 
// --->
</SCRIPT>

<%
session.timeout = 120

'##################### Çerezleri Alma Kodlarý ##############################################

session_uyegiris = request.cookies("uyegiris")
session_uyeid = request.cookies("uyeid")
session_kadi = request.cookies("kadi")
session_admingiris = request.cookies("admingiris")

'##################### Çerezleri Alma Kodlarý Bitiþi #######################################

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
if session_uyegiris = "evet" then
set rewt=server.createobject("adodb.recordset")
rewt.open "select * from uyeler where id="&session_uyeid,bagg,1,3



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

if session_uyegiris <> "evet" then
if rewt("online") = 0 then
session.abandon()
response.redirect "default.asp"
end if
end if


rewt("sonip") = gelenip
rewt("online") = 1

rewt.update



end if
if sayfaurl <> "cikis.asp" then
call sitedekiler_kontrol(bagg)
end if

'############# Üyenin IP Kayýt kodlarý ##################
if session_uyegiris = "evet" then

if request.cookies("iplog2") <> Request.ServerVariables("REMOTE_ADDR") then

response.cookies("iplog2") = Request.ServerVariables("REMOTE_ADDR")

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
<title>Ankara SDAL Mezunlarý Web Sitesi - <%=sayfaadi%></title>
<LINK href="sdal.ico" rel="SHORTCUT ICON">
<META http-equiv=Content-Type content="text/html; charset=windows-1254">
<!--#include file="stil.asp"-->
<script src="ayax.asp"></script>
<script src="sdalajax.js"></script>
<script type="text/javascript" src="reflection.js"></script>
<!--#include file="hint.inc"-->
</head>
<body bgcolor="#663300" topmargin=0 leftmargin=0<%if session_uyegiris <> "evet" and sifresiz <> "evet" then%> onload=uyegirisform.kadi.focus();<%end if%>>
<table border=0 width=100% height=100% cellpadding=0 cellspacing=0>
<tr>
<td width=100% height=100% bgcolor="#663300" align=center valign=center>

<table border=0 width=100% height=300 cellpadding=0 cellspacing=0>
<tr>
<td width=100% height=50 align=left valign=bottom style="background:#663300;">
<a href="default.asp" title="Anasayfaya gider..."><img src="logo.gif" border=0></a>
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

<%'##################### Üst Menü Baþlangýcý ############################ %>
<% if session_uyegiris = "evet" then %>
<tr>
<td width=100% align=left valign=bottom style="background:white;" valign=middle>
<table border=0 cellpadding=0 cellspacing=0 width=100%>
<tr><td width=58>
<img src="menu.gif" border=0 align=top>
</td>
<td valign=middle>
<%
set km=bagg.execute("select * from sayfalar where menugorun = 1 order by sayfaismi")
if not km.eof then

do while not km.eof
if km("sayfaurl") <> "sifrehatirla.asp" and km("sayfaurl") <> "uyekayit.asp" then
%>

<a href="<%=km("sayfaurl")%>" title="Nereye --> <%=km("sayfaismi")%>" class=menulink style="text-decoration:none;<%if km("sayfaurl") = sayfaurl then%>background:#663300;color:white;padding:3;<%end if%>"><%=km("sayfaismi")%></a> | 

<%
end if
km.movenext
loop
end if
%>
<a href="cikis.asp" title="Güvenli bir þekilde çýkmak için týklayýnýz." class=menulink>Güvenli Çýkýþ</a>
</td></tr></table>
</td>
</tr>
<% end if %>
<%'##################### Üst Menü Bitiþi ############################ %>

<tr>
<td width=100% height=150 align=center valign=center style="background:white;">

<% if session_uyegiris = "evet" then %>
<%'################## Vesikalýk BAÞLANGICI ###################################### %>

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

</td></tr>
<tr><td style="border:1 solid #663300;" onmouseover="this.style.backgroundColor='white';" onmouseout="this.style.backgroundColor='#ffffdd';">
<a href="vesikalikekle.asp" style="color:#660000;text-decoration:none;font-size:10;"><b>Fotoðraf Ekle/Düzenle</b></a>

</td></tr>
</table>



<%'################## Shoutbox ############################ %>
<!--
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
Mesaj : <br><input type=text name=hmmetin style="font-size:10;font-family:tahoma;" maxlength=60><input type=submit value=gönder style="font-size:10;font-family:tahoma;">
<br><font style="font-size:9;color:navy;">* En Fazla 60 Karakter</font>
</form>

<%'################## Shoutbox Bitiþi############################ %>

<%'################## Online üyeler-AJAX ############################ %>

<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>Kimler Sitede?</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;">
<div id="onuyekutusu"><center><b>Lütfen bekleyiniz,<br>yükleniyor...<br></b></center></div>
</td>
</tr>
</table>
<script language=javascript>
onuyedinle();

function onuyedinle() {
onlineukon2();
setTimeout("onuyedinle()",5001)
}

</script>
<%'################## Online üyeler bitiþi-AJAX############################ %>
-->

<%'################## Online üyeler-not ajax ############################ %>

<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>Kimler Sitede?</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;">
<%
set sitler=server.createobject("adodb.recordset")
sitler.open "select * from uyeler where online = 1 order by kadi",bagg,1,3

if sitler.eof then
response.write " Þu an sitede online üye bulunmamaktadýr."
else

tarih1 = now()
do while not sitler.eof

tarih2 = sitler("sonislemtarih") & " " & sitler("sonislemsaat")
if isDate(tarih2) = True then
tfark = DateDiff("n",tarih2,tarih1)
end if

if tfark > 5 then
sitler("online") = 0
end if

%>
<img src=arrow-orange.gif border=0><a href="uyedetay.asp?id=<%=sitler("id")%>" class="hintanchor" onMouseover="showhint('<%if sitler("resim") = "yok" then%><img src=kucukresim6.asp?iheight=40&r=nophoto.jpg border=1 width=50 align=middle><%else%><img src=kucukresim6.asp?iheight=40&r=<%=sitler("resim")%> border=1 width=50 align=middle><%end if%>&nbsp;<font color=red><b><%=sitler("mezuniyetyili")%></b></font> mezunu!<br><b><%=sitler("isim")%>&nbsp;<%=sitler("soyisim")%></b> isimli Üyenin detaylarýný görmek için týklayýnýz.<br><b><%=tfark%> dakika</b>', this, event, '220px')" style="color:#663300;"><%=sitler("kadi")%></a><br>
<%

sitler.movenext
i=i+1
loop
sitler.close
set sitler=nothing
end if%>
</td>
</tr>
</table>
<%'################## Online üyeler bitiþi-not ajax############################ %>

<%'################## En yeni xx üye ############################ %>
<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>En Yeni Üyelerimiz</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;">
<%call enyeniuyeler(5,bagg)%>
</td>
</tr>
</table>

<%'####################### SUB - en yeni xx üye çekme #############################################
sub enyeniuyeler(kacuye,bag)

set ks=server.createobject("adodb.recordset")
ks.open "select * from uyeler where aktiv=1 and yasak=0 order by id desc",bag,1
i=1
do while not ks.eof and i<=kacuye%>

<img src=arrow-orange.gif border=0><a href="uyedetay.asp?id=<%=ks("id")%>" class="hintanchor" onMouseover="showhint('<%if ks("resim") = "yok" then%><img src=kucukresim6.asp?iheight=40&r=nophoto.jpg border=1 width=50 align=middle><%else%><img src=kucukresim6.asp?iheight=40&r=<%=ks("resim")%> border=1 width=50 align=middle><%end if%>&nbsp;<font color=red><b><%=ks("mezuniyetyili")%></b></font> mezunu!<br><b><%=ks("isim")%>&nbsp;<%=ks("soyisim")%></b> isimli üyenin detaylarýný görmek için týklayýnýz.', this, event, '220px')" style="color:#663300;"><%=ks("kadi")%></a><br>

<%ks.movenext
i=i+1
loop

end sub
'####################### SUB - en yeni xx üye çekme bitiþi #############################################
%>
<%'################## En yeni xx üye bitiþi############################ %>

<%'################## En yeni xx fotoðraf ############################### %>
<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>En Yeni Fotoðraflar</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=center>
<%
set sxft=server.createobject("adodb.recordset")
sxft.open "select * from album_foto where aktif=1 order by id desc",bagg,1

kacfoto=10

i=1

do while not sxft.eof and i<=kacfoto

set ahj=server.createobject("adodb.recordset")
ahj.open "select * from album_foto where katid='"&sxft("katid")&"' and aktif=1",bagg,1
fsira = 1
fkn=0
do while not ahj.eof
if fkn=0 then
fsira = fsira + 1
end if
if ahj("id") = sxft("id") then
fkn=1
end if
ahj.movenext
loop
 
ahj.close
set ahj=nothing

fotsf = fsira/20
if fotsf > cint(fotsf) then
fotsf = cint(fotsf) + 1
else
fotsf = cint(fotsf)
end if
if fotsf=0 then
fotsf=1
end if
%>
<%
set sxft2=server.createobject("adodb.recordset")
sxft2.open "select * from album_kat where id="&cint(sxft("katid")),bagg,1
%>
<a href="fotogoster.asp?fid=<%=sxft("id")%>&sf=<%=fotsf%>" class="hintanchor" onMouseover="showhint('<b><%=sxft2("kategori")%></b><br><img src=kucukresim.asp?iwidth=250&r=<%=sxft("dosyaadi")%> border=1 width=250>', this, event, '250px')"><img src="kucukresim.asp?iwidth=50&r=<%=sxft("dosyaadi")%>" border=1></a>
<%
sxft2.close
set sxft2=nothing
sxft.movenext

set ahj=server.createobject("adodb.recordset")
ahj.open "select * from album_foto where katid='"&sxft("katid")&"' and aktif=1",bagg,1
fsira = 1
do while not ahj.eof and ahj("id") < sxft("id")
fsira = fsira + 1
ahj.movenext
loop

ahj.close
set ahj=nothing

fotsf = fsira/20
if fotsf > cint(fotsf) then
fotsf = cint(fotsf) + 1
else
fotsf = cint(fotsf)
end if
if fotsf=0 then
fotsf=1
end if
set sxft2=server.createobject("adodb.recordset")
sxft2.open "select * from album_kat where id="&cint(sxft("katid")),bagg,1
%>

<a href="fotogoster.asp?fid=<%=sxft("id")%>&sf=<%=fotsf%>" class="hintanchor" onMouseover="showhint('<b><%=sxft2("kategori")%></b><br><img src=kucukresim.asp?iwidth=250&r=<%=sxft("dosyaadi")%> border=1 width=250>', this, event, '250px')"><img src="kucukresim.asp?iwidth=50&r=<%=sxft("dosyaadi")%>" border=1></a>
<br>
<%
sxft2.close
set sxft2=nothing
i=i+1
sxft.movenext
loop
sxft.close
set sxft=nothing
%>
<hr color=#662233 size=1>
<a href="albumfotoekle.asp" title="Fotoðraf Albümüne yeni fotoðraf/fotoðraflar yüklemek için týklayýnýz.">Yeni Fotoðraf Ekle</a>
</td>
</tr>
</table>

<%'################## En yeni xx fotoðraf bitiþi ############################### %>

<%'################## En yüksek xx score -Yýlan ############################### %>
<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>En Yüksek Puan-Yýlan</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=left>
<%
set eysy=server.createobject("adodb.recordset")
eysy.open "select * from oyun_yilan order by skor desc",bagg,1

kackisi_eysy = 5

i=1
do while not eysy.eof and i<=kackisi_eysy
%>

<b><%=i%>. </b><a href=# style="color:#663300;" class="hintanchor" onMouseover="showhint('Puan : <b><%=eysy("skor")%></b><br>Tarih : <b><%=tarihduz(eysy("tarih"))%></b>', this, event, '300px')"><%=eysy("isim")%></a><br>

<%
i=i+1
eysy.movenext
loop

eysy.close
set eysy=nothing
%>
</td></tr></table>

<%'################## En yüksek xx score -Yýlan Bitiþi ############################### %>

<%'################## En yüksek xx score -Tetris ############################### %>
<%
Set tetr = Server.CreateObject("ADODB.Connection")
tetr.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("oyunlar.mdb")
%>
<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>En Yüksek Puan-Tetris</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=left>
<%
set tetris=server.createobject("adodb.recordset")
tetris.open "select * from oyun_tetris order by puan desc",tetr,1

kackisi_tet = 5

i=1
do while not tetris.eof and i<=kackisi_tet
%>

<b><%=i%>. </b><a href=# style="color:#663300;" class="hintanchor" onMouseover="showhint('Puan : <b><%=tetris("puan")%></b><br>Tarih : <b><%=tarihduz(tetris("tarih"))%></b>', this, event, '300px')"><%=tetris("isim")%></a><br>

<%
i=i+1
tetris.movenext
loop

tetris.close
set tetris=nothing

tetr.close
set tetr=nothing
%>
</td></tr></table>

<%'################## En yüksek xx score -Tetris Bitiþi ############################### %>


</td>

<%
set ymv=server.createobject("adodb.recordset")
ymv.open "select * from gelenkutusu where yeni=1 and kime='"&cstr(session_uyeid)&"' and aktifgelen = 1",bagg,1
%>
<td style="border:1 solid #000033;" align=center valign=top>
<%if not ymv.recordcount = 0 then%>
<table border=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="border:2 solid #660000;background:#ffffcc;" align=left valign=center>
<img src="arrow-orange.gif" border=0><a href="mesajlar.asp" title="Mesajlarý okumak için týklayýn." style="color:blue;"><b><%=ymv.recordcount%></b> yeni mesajýnýz var!</a>
</td></tr></table>
<%end if%>
<%end if%>