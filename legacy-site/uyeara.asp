<%response.buffer=true%>
<%sayfaadi="Üye Ara"%>
<%sayfaurl="uyeara.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<% if session_uyegiris = "evet" then%>

<%
tip = request("tip")

if tip<>"" or tip = "sehir" or tip = "myili" or tip = "hara" or tip = "resim" then

if tip="hara" then
kelime = trim(request.form("kelime"))
'######## sql injection korumasý ###########
kelime=Replace(kelime,"'","")
'######## sql injection korumasý bitiþi ###########
if len(kelime) = 0 then
msg = "Aranacak kelime girmedin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where kadi like '%"&kelime&"%' or isim like '%"&kelime&"%' or soyisim like '%"&kelime&"%' or meslek like '%"&kelime&"%' or email like '%"&kelime&"%' and aktiv=1 and yasak=0 order by kadi",bagg,1

%>
<%
elseif tip="myili" then
dara = request.querystring("dara")
'######## sql injection korumasý ###########
dara=Replace(dara," ","-")
dara=Replace(dara,"'","")
'######## sql injection korumasý bitiþi ###########
if Len(dara)=0 then
msg = "Yanlýþ Giriþ!! Mezuniyet yýlý seçilmemiþ.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where mezuniyetyili='"&dara&"' and aktiv=1 and yasak=0 order by kadi",bagg,1


elseif tip="sehir" then
dara = request.querystring("dara")
'######## sql injection korumasý ###########
dara=Replace(dara," ","-")
dara=Replace(dara,"'","")
'######## sql injection korumasý bitiþi ###########
if Len(dara)=0 then
msg = "Yanlýþ Giriþ!! Þehir seçilmemiþ.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where sehir='"&dara&"' and aktiv=1 and yasak=0 order by kadi",bagg,1

elseif tip="resim" then

set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where resim<>'yok' and aktiv=1 and yasak=0 order by kadi",bagg,1


else
response.redirect "uyeara.asp"
end if
%>
<table border=0 cellpadding=3 cellspacing=2 width=100%>
<tr>
<td style="border:1 solid #663300;background:white;">

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<%if tip="hara" then%><b>Hýzlý Arama</b>
<%else%>
<b>Detaylý Arama</b>
<%end if%>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>
<br>
<%if tip = "hara" then%>
Aranan Kelime : <%=kelime%>
<%elseif tip="myili" then%>
<b><%=dara%> yýlý mezunlarý</b>
<%elseif tip="sehir" then%>
Þehir : <b><%=dara%></b>
<%end if%>
 &nbsp;&nbsp;&nbsp;&nbsp;<a href="uyeara.asp" title="Tekrar Arama Yap">Tekrar Arama Yapmak Ýstiyorum</a>
<hr color=#ededed size=1>
<%if ks.eof then%>
<br><br>Üzgünüz! Arama sonucunda herhangi bir kayýt bulunamadý.
<%else%>
<table border=0 cellpadding=3 cellspacing=5>
<tr>
<%
maxuye=6
i=1
do while not ks.eof
if ks("aktiv") = 1 and ks("yasak") = 0 then
%>

<td width=105 height=75 style="border:1 solid #ebebeb;background:white;color:#000033;" align=center>
<a href="uyedetay.asp?id=<%=ks("id")%>" title="<%=ks("kadi")%> isimli üyenin detaylarý"><b><%=ks("kadi")%></b></a><br><br>
<a href="uyedetay.asp?id=<%=ks("id")%>" title="<%=ks("kadi")%> isimli üyenin detaylarý">
<%if ks("resim") = "yok" then%>
<img src="kucukresim5.asp?r=nophoto.jpg" border=1>
<%else%>
<img src="kucukresim5.asp?r=<%=ks("resim")%>" border=1>
<%end if%>
</a><br><br>
<small><%=ks("mezuniyetyili")%> Mezunu</small>
<hr color=#ededed size=1>
<%if ks("online") = 1 then%>
<center><font style="color:red;"><b>Baðlý!</b></font></center>
<hr color=#ededed size=1>
<%end if%>

<small>
<b><a href="mesajgonder.asp?kime=<%=ks("id")%>" title="<%=ks("kadi")%> isimli üyeye mesaj gönder.">Mesaj Gönder</a></b>
<b><a href="hizlierisimekle.asp?uid=<%=ks("id")%>" title="Bu Üyeyi Hýzlý Eriþim Listesine Ekle">Listeye Ekle</a></b>
</small>


</td>
<%if i>=maxuye then
a=cint(i/maxuye)
if (i-a*maxuye) = 0 then
%>
</tr><tr>
<%end if%>
<%end if%>
<%
i=i+1
end if
ks.movenext
loop
%>
</table>
<hr color=#ededed size=1>
<center>Toplam <b><i><%=i-1%></i></b> kay&#305;t bulundu.</center>
<hr color=#ededed size=1>
<%end if%>
</td>
</tr>
</table>

</td>
</tr>
</table>
<%
else
%>
<table border=0 cellpadding=3 cellspacing=2 width=100%>
<tr>
<td style="border:1 solid #663300;background:white;">

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Hýzlý Arama</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>
<form method=post action="uyeara.asp" name="haraform">
<br>
Aranacak Kelime : <input type=text name=kelime size=30 class=inptxt>&nbsp;&nbsp;<input type=submit value="Ara" class=sub>
<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Girdiðiniz kelime <i>kullanýcý adý</i>, <i>isim</i>, <i>soyisim</i> ve <i>meslek</i> alanlarýnda aranýr.', this, event, '150px')">[?]</a>
<input type=hidden name=tip value="hara">
</form>
</td>
</tr>
</table>

</td>
</tr>

<tr>
<td style="border:1 solid #663300;background:white;">

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Detaylý Arama</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left>
<b>Mezuniyet Yýlý</b>
<hr color=#ededed size=1>
<ul><% set muy=server.createobject("adodb.recordset")
topuye=0
for i=1999 to cint(right(date(),4))+4
muy.open "select * from uyeler where mezuniyetyili='"&cstr(i)&"' and aktiv=1 and yasak=0",bagg,1
%>
<li><a href="uyeara.asp?tip=myili&dara=<%=i%>" title="<%=i%> yýlý mezunlarýný bul. Toplam <%=muy.recordcount%>"><%=i%> Mezunlarý ( <%=muy.recordcount%> )</a><br>
<%
topuye = topuye + muy.recordcount
muy.close
next%></ul>
Toplam <b><%=topuye%></b> aktif üye.
<hr color=#ededed size=1>
<b>Þehir</b>
<hr color=#ededed size=1>
<form method=get action="uyeara.asp">
<select name=dara class=inptxt>
<%
for i=0 to 80%>
<option value="<%=iller(i)%>"<%if i=5 then%> selected<%end if%>><%=iller(i)%>
<%next%>
<input type=hidden name=tip value="sehir">
<input type=submit value="Bul" class=sub>
</select>
</form>
</td>
</tr>
</table>

</td>
</tr>
</table>

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>En Yeni Üyelerimiz</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;background:white;" align=center>

<table border=0 cellpadding=3 cellspacing=5>
<tr>
<%
maxxuye=5
set eys=server.createobject("adodb.recordset")
eys.open "select * from uyeler where aktiv=1 and yasak=0 order by id desc",bag,1
i=1
do while not eys.eof and i<=10%>


<td width=105 height=75 style="border:1 solid #ebebeb;background:white;color:#000033;" align=center>
<a href="uyedetay.asp?id=<%=eys("id")%>" title="<%=eys("kadi")%> isimli üyenin detaylarý"><b><%=eys("kadi")%></b></a><br><br>
<a href="uyedetay.asp?id=<%=eys("id")%>" title="<%=eys("kadi")%> isimli üyenin detaylarý">
<%if eys("resim") = "yok" then%>
<img src="kucukresim5.asp?r=nophoto.jpg" border=1>
<%else%>
<img src="kucukresim5.asp?r=<%=eys("resim")%>" border=1>
<%end if%>
</a><br><br>
<small><%=eys("mezuniyetyili")%> Mezunu</small>
<hr color=#ededed size=1>
<%if eys("online") = 1 then%>
<center><font style="color:red;"><b>Baðlý!</b></font></center>
<hr color=#ededed size=1>
<%end if%>

<small>
<b><a href="mesajgonder.asp?kime=<%=eys("id")%>" title="<%=eys("kadi")%> isimli üyeye mesaj gönder.">Mesaj Gönder</a></b>
<b><a href="hizlierisimekle.asp?uid=<%=eys("id")%>" title="Bu Üyeyi Hýzlý Eriþim Listesine Ekle">Listeye Ekle</a></b>
</small>


</td>

<%if i>=maxxuye then
a=cint(i/maxxuye)
if (i-a*maxxuye) = 0 then
%>
</tr><tr>
<%end if%>
<%end if%>

<%eys.movenext
i=i+1
loop
%>
</tr>
</table>

</td>
</tr>
</table>
<hr color=#ededed size=1>

<%end if%>



<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->