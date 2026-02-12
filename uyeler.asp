<%response.buffer=true%>
<%sayfaadi="Üyeler"%>
<%sayfaurl="uyeler.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<% if session_uyegiris = "evet" then%>

<table border=0 width=100%>
<tr>
<td align=left style="font-size:15;color:#663300;border-bottom:1 solid #663300;">
<b>Üyeler</b>
</td></tr></table>


<form method=post action="uyeara.asp">
Üye Ara : <input type=text name=kelime class=inptxt>&nbsp;<input type=submit value="Ara" class=sub>
<input type=hidden name=tip value="hara">
</form>

<table border=0 cellapdding=3 cellspacing=0 width=100%>
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where aktiv = 1 and yasak = 0 order by isim",bagg,1

ks.pagesize = 10

sf = request.querystring("sf")
if Len(sf) = 0 then
sf = 1
end if
if not isNumeric(sf) then
sf = 1
end if
sf = Cdbl(sf)

if sf<1 or sf>ks.pagecount then
sf = 1
end if

ks.absolutepage = sf

i=1
%>

<tr>
<td colspan=2 style="border:1 solid #663300;" align=center>
Sayfalar : <%
for d=1 to ks.pagecount
set klh = server.createobject("adodb.recordset")
klh.open "select * from uyeler where aktiv = 1 and yasak = 0 order by isim",bagg,1
for f=1 to d*ks.pagesize
if f=((d-1)*ks.pagesize+1) then
ilkuye = left(klh("isim"),2)
elseif f=d*ks.pagesize then
sonuye = left(klh("isim"),2)
end if
if f<klh.recordcount then
klh.movenext
end if
next
if d = sf then%>
<b><%=ilkuye%> - <%=sonuye%></b>
<%else%>
<b>[<a href="uyeler.asp?sf=<%=d%>" title="<%=d%>. sayfaya git."><%=ilkuye%> - <%=sonuye%></a>]</b>
<%end if
klh.close
next%>
</td>
</tr>

<%
do while not ks.eof and i<=ks.pagesize
%>
<tr>

<td style="border:1 solid #663300;" width=75 valign=top>
<a href="uyedetay.asp?id=<%=ks("id")%>" title="Üye detaylarýný görmek için týklayýn." style="text-decoration:none;">
<%if ks("resim") = "yok" then%>
<img src="vesikalik/nophoto.jpg" border=1 width=75>
<%else%>
<img src="kucukresim2.asp?iwidth=75&r=<%=ks("resim")%>" border=1 width=75>
<%end if%>
</a>
<%if ks("online") = 1 then%>
<center><font style="color:red;"><b>Baðlý!</b></font></center>
<%end if%>
</td>

<td style="border:1 solid #663300;" valign=top>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td colspan=2 width=100% valign=top align=left style="border-bottom:1 solid #663300;background:#ffffcc;">
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td width=50% align=left valign=center>
Kullanýcý Adý : <a href="uyedetay.asp?id=<%=ks("id")%>" title="Üye detaylarýný görmek için týklayýn." style="text-decoration:none;"><img src="uyelerkadiresimyap.asp?kadi=<%=ks("kadi")%>" border=0></a>
</td>
<td width=50% align=right valign=center>
<%
if len(ks("sontarih"))<>0 then
sontar = tarihduz(ks("sontarih"))
%>
Siteye son girdiði tarih : <b><%=sontar%></b>
<%else%>
Siteye son girdiði tarih belirsiz..
<%end if%>
</td>
</tr>
<tr>
<td width=100% align=center valign=center style="border-top:1 solid #663300;" colspan=2>
<a href="uyedetay.asp?id=<%=ks("id")%>" title="Üye detaylarýný görmek için týklayýn.">Üye Detaylarýný Göster</a> - <a href="hizlierisimekle.asp?uid=<%=ks("id")%>" title="Bu üyeyi hýzlý eriþim listeme ekle">Hýzlý Eriþim Listesine Ekle</a> - <a href="mesajgonder.asp?kime=<%=ks("id")%>" title="<%=ks("kadi")%> isimli üyeye mesaj gönder.">Mesaj Gönder</a>

</td></tr></table>
</td>
</tr>
<tr>
<td width=50% valign=top>
<li>Ýsim Soyisim : <b><%=ks("isim")%>&nbsp;<%=ks("soyisim")%></b><br><br>
<li>E-Mail : <%if ks("mailkapali")=1 then%><i>Üyemiz e-mail adresinin görünmesini istemiyor.</i><%else%><b><%=ks("email")%></b><%end if%><br><br>
<li>Mezuniyet Yýlý : <%if ks("mezuniyetyili") = "0" then%><i>Henüz bir mezuniyet yýlý girilmemiþ.</i><%else%><b><%=ks("mezuniyetyili")%></b><%end if%><br><br>
<li>Doðum günü : <%if ks("dogumgun") = 0 or ks("dogumay") = 0 or ks("dogumyil") = 0 then%><i>Henüz bir doðum günü girilmemiþ.</i><%else%><b><%=ks("dogumgun")%>&nbsp;<%=aylar(ks("dogumay")-1)%>&nbsp;<%=ks("dogumyil")%></b><%end if%>
</td>
<td width=50% valign=top>
<li>Bulunduðu Þehir : <b><%=ks("sehir")%></b><br><br>
<li>Üniversite : <b><%=ks("universite")%></b><br><br>
<li>Ýþ : <b><%=ks("meslek")%></b><br><br>
<li>Web Sitesi : <b><a href="<%if not left(ks("websitesi"),7) = "http://" then%>http://<%end if%><%=ks("websitesi")%>" target="_blank"><%=ks("websitesi")%></a></b>
</td>
</tr>
<tr>
<td colspan=2 style="border-top:1 solid #663300;" align=center>
<font style="font-size:10;color:#663300;"><%=ks("imza")%></font>
</td>
</tr>
</table>
</td>

</tr>

<tr>
<td colspan=2 style="border:1 solid #663300;background:#660000;" height=7>
</td>
</tr>
<%
i = i + 1
ks.movenext
loop
%>
<tr>
<td colspan=2 style="border:1 solid #663300;" align=center>
Sayfalar : <%
for d=1 to ks.pagecount
set klh = server.createobject("adodb.recordset")
klh.open "select * from uyeler where aktiv = 1 and yasak = 0 order by kadi",bagg,1
for f=1 to d*ks.pagesize
if f=((d-1)*ks.pagesize+1) then
ilkuye = left(klh("kadi"),2)
elseif f=d*ks.pagesize then
sonuye = left(klh("kadi"),2)
end if
if f<klh.recordcount then
klh.movenext
end if
next
if d = sf then%>
<b><%=ilkuye%> - <%=sonuye%></b>
<%else%>
<b>[<a href="uyeler.asp?sf=<%=d%>" title="<%=d%>. sayfaya git."><%=ilkuye%> - <%=sonuye%></a>]</b>
<%end if
klh.close
next%>

<br>Toplam <b><%=ks.recordcount%></b> üyemiz bulunmaktadýr.
</td>
</tr>
</table>


<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->