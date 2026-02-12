<%
Set bagm = Server.CreateObject("ADODB.Connection")
bagm.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")

%>
<table border=0 cellpadding=3 cellspacing=2 width=100%>
<tr>
<td style="border:1 solid #663300;background:white;">

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Fotoðraf Albümünden...</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>

<table border=0 cellpadding=3 cellspacing=3>
<tr>
<%
set rsa = server.createobject("ADODB.Recordset")
rsa.open "select * from album_foto",bagm,1,3

rkf=10
tot=1
do while tot<=rkf

Randomize
rastgele = Int((Rnd*rsa.RecordCount)+tot)

rsa.Move rastgele,1

tot = tot + 1


%>
<td style="border:1 solid gray;background:#ededed;" align=center valign=middle>
<a href="albumkat.asp?kat=<%=rsa("katid")%>" class="hintanchor" onMouseover="showhint('<img src=kucukresim.asp?iwidth=350&r=<%=rsa("dosyaadi")%> border=1 width=350>', this, event, '350px')"><img src="kucukresim.asp?iheight=50&r=<%=rsa("dosyaadi")%>" border=1 style="border-right:2 solid black;border-bottom:2 solid black;"></a>
</td>
<%
loop
%>
</tr></table>

</td>
</tr>
</table>


<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Mesaj Panolarý</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>

<%

set mycek=bagg.execute("select * from uyeler where id="&cint(session_uyeid))

if mycek.eof then
response.write "yanlýþ giriþ!"
response.end
end if

pmyili = cstr(mycek("mezuniyetyili")) & " Mezunlarý"

set pkat=bagg.execute("select * from mesaj_kategori where kategoriadi='"&pmyili&"'")
%>

<table border=0 cellpadding=5 cellspacing=3 width=100%>

<tr>
<td width=100% style="border:1 solid #lightgray;backgroundcolor:#ededed;">
<b><a style="color:gray;font-family:Tahoma;font-size:15;text-decoration:none;" href="panolar.asp?mkatid=0" title="Bu kategoriyi görmek için týklayýnýz">GENEL Mesaj Panosu</a></b>
</td>
</tr>

<tr>
<td width=100% style="border:1 solid #lightgray;backgroundcolor:#ededed;">
<%if not pkat.eof then%><b><a style="color:gray;font-family:Tahoma;font-size:15;text-decoration:none;" href="panolar.asp?mkatid=<%=pkat("id")%>" title="Bu kategoriyi görmek için týklayýnýz"><%=pkat("kategoriadi")%> Panosu</a></b><%end if%>
</td></tr>

</table>

<tr>
<td width=100% style="border:1 solid #lightgray;backgroundcolor:#ededed;">

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>DUYURULAR</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>



<!--
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td style="background:white;border:1 solid blue;" onmouseover="this.style.border='1 solid #663300';" onmouseout="this.style.border='1 solid blue';">
<a href="futbolkayit.asp" title="Futbul turnuvasýna kayýt kaptýrmak için týklayýnýz...">
<font style="color:red;font-family:Tahoma;font-size:20;text-decoration:none;">
15-16 Aralýkta SDALnin spor salonunda düzenlenecek turnuva için siz de takýmýnýzý kurun!
</font>
<br><br>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Kayýt yaptýrmak için týklayýn!
</font>
<br><br>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Son Baþvuru Tarihi : 12 Aralýk 2007<br>
Maç Programý Duyuru Tarihi : 13 Aralýk 2007<br><br>
</a>
</font>
<br><br>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
<b>Not : </b>Þehir dýþýnda bulunan arkadaþlarýmýz için turnuva tarihi bir hafta ileriye alýnmýþtýr.
</font>

</td></tr></table>



<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Yemek ücretlerini yatýrabileceðiniz hesap numaralarý<br>
AKBANK - 5890044120771746 - Mehmet Kürþat Soydan - Bilkent Þubesi<br>
VAKIFBANK - 00158007284956210 -  Mehmet Kürþat Soydan - Antalya Þubesi<br>
ÝÞBANKASI - 42680112864 - Taner Güzel - Eryaman Þubesi<br>
<br>
Havale yaparken açýklama kýsmýna adýnýzý yazmayý lütfen unutmayýn!!!

</font><br>

<br>
<center><b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Süleyman Demirel Anadolu Lisesi Mezunlar Derneði'nin
</font></b></center><br>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
24 Kasým Cumartesi günü hocalarýmýzýn ve mezunlarýmýzýn katýlýmýyla 
gerçekleþecek olan yemekli 
buluþmamýzda bütün mezunlarýmýzý aramýzda görmekten mutluluk duyarýz.</font><br>


<br><b>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Yer: </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Emiryaman Konaðý (Eryaman giriþinde)</font><br>

<b>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Gün: </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
24 Kasým 2007 ( Öðretmenler günü)</font><br>

<b>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Saat: </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
19:00</font><br>

<b>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Menü: </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Çorba - Ezme - Salata - Tarator - Arasýcak - Testi Kebabý - Tatlý - Ayran - Su</font><br>
 <br>
<center>
<b><u>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Canlý Müzik</font></u></b></center>
<br>


<b><u>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Fiyat 16 ytl</font></u></b>
 <br><br><br>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
YERÝMÝZ SINIRLI SAYIDA OLDUÐUNDAN ÜCRETLER YEMEK TARÝHÝNDEN ÖNCE TOPLANIP 
REZERVASYON KESÝN KATILIMCI SAYISI ÝLE YAPILACAKTIR. DETAYLI BÝLGÝLENDÝRME 
SDAL.ORG VE MAÝL ADRESERÝNÝZ ARACILIÐIYLA YAPILACAKTIR. SORU ve ÖNERÝLERÝNÝZÝ 
AÞAÐIDA ÝLETÝÞÝM BÝLGÝLERÝ VERÝLEN MEZUNLARA YÖNELTEBÝLÝRSÝNÝZ.
</font><br><br>
-->

<b><u>
<font style="color:red;font-family:Tahoma;font-size:15;text-decoration:none;">
Ýrtibat : </font></u></b>
 <br>

<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Ayþe Gül Hacýoðlu </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(1999)  Tel: 05324006537</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Kürþat Soydan </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
 (2000) Tel: 05053222546</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Ferkat Kurultay </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2000)  Tel: 05052552601</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Çaðatay Dönmez </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2000) Tel: 05053379727</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Taner Güzel </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2001) Tel: 05053291126 - 05336374337</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Dursun Balkan </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2001) Tel: 05448259496</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Ali Kaðan Þener </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2002) Tel: 05555749611</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Veysel Osmanoðlu </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2003) Tel: 05353925077</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Sertaç Banko </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2004) Tel: 05554411136</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Mehmet Fatih Kutan </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
(2006) Tel: 05555799087</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Abdullah Akdoðan </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
Tel: 05058596906</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
e_posta: </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
sdalmezunder@gmail.com</font><br>
<b>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
msn: </font></b>

<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
tano1907@hotmail.com</font><br>
<br><br>
<b>

<center>
<font style="color:black;font-family:Tahoma;font-size:18;text-decoration:none;">
S.D.A.L. Mezunlar Derneði 
              Yönetimi
</center></font><br>

</td></tr></table>

</td></tr>

</table>




</td>
</tr>
</table>

</td>
</tr>


</table>