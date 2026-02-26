<%
set he=server.createobject("adodb.recordset")
he.open "select * from uyeler where id="&session_uyeid,bagg,1
%>

<table border=1 cellpadding=0 cellspacing=2 width=100% bgcolor=#ffffdd bordercolor=#663300>
<tr>
<td style="background:#ffffcc;border:1 solid #660000">

<table border=0 cellpadding=3 cellspacing=0 width=100%>
<%if request.querystring("hlc") = "e" then%>
<tr>
<td height=20 valign=center align=left style="border-bottom:1 solid #660000;color:navy;">
<b>Ýstediðiniz üye listeden baþarýyla çýkarýldý.</b>
</td>
</tr>
<%end if%>
<%if request.querystring("hle") = "e" then%>
<tr>
<td height=20 valign=center align=left style="border-bottom:1 solid #660000;color:navy;">
<b>Ýstediðiniz üye listeye baþarýyla eklendi.</b>
</td>
</tr>
<%end if%>

<tr>
<td height=20 valign=center align=left style="background:navy;border-bottom:1 solid #660000;color:white;">
<b>Hýzlý Eriþim Kutusu</b><a href="#" class="hintanchor" style="color:white;" onMouseover="showhint('<img src=arrow-orange.gif border=0>Hýzlý Eriþim Listeniz sýk görüþtüðünüz üyeler için iþlemlerinizi daha hýzlý yapmanýzý saðlayan bir listedir. Üyenin resminin altýnda yapýlabilecek iþlemler yer almaktadýr', this, event, '200px')">[?]</a>
</td>
</tr>
<tr>
<td>
<%
if he("hizliliste") = "0" then
%>
Henüz üye eklenmemiþ.. <a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0>Hýzlý Eriþim Listenize üye eklemek için <b>Üyeler</b> sayfasýný kullanýnýz.', this, event, '150px')">[?]</a>
<%
else

hdizi = split(he("hizliliste"),",",-1,1)
%>
<table border=0 cellpadding=1 cellspacing=10>

<tr>
<%
maxuye = 6
hlhep = 0
if request.querystring("hlhep") = "e" then
hlhep = 1
end if
hlhep = 1
i=1
for each huye in hdizi
if huye <> "0" then
if hlhep = 1 or i <= maxuye then
set hucek=bagg.execute("select * from uyeler where id="&cint(huye))
if not hucek.eof then
%>

<td width=100 height=100 style="border:1 solid #ebebeb;background:white;color:#000033;" align=center valign=top>
<a href="uyedetay.asp?id=<%=hucek("id")%>" title="<%=hucek("kadi")%> isimli üyenin detaylarý"><b>
<%if Len(hucek("kadi")) > 10 then%>
<%=left(hucek("kadi"),10)%>..
<%else%>
<%=hucek("kadi")%>
<%end if%>
</b></a><br><br>
<a href="uyedetay.asp?id=<%=hucek("id")%>" title="<%=hucek("kadi")%> isimli üyenin detaylarý">
<%if hucek("resim") = "yok" then%>
<img src="kucukresim5.asp?r=nophoto.jpg" border=1>
<%else%>
<img src="kucukresim5.asp?r=<%=hucek("resim")%>" border=1>
<%end if%>
</a><br><br>
<small><%=hucek("mezuniyetyili")%> Mezunu</small>
<hr color=#ededed size=1>
<%if hucek("online") = 1 then%>
<center><font style="color:red;"><b>Baðlý!</b></font></center>
<hr color=#ededed size=1>
<%end if%>
<table border=0 cellpadding=0 cellspacing=0 width=100%>
<tr>
<td align=left valign=top>
<font style="font-size:10;">
<li><a href="mesajgonder.asp?kime=<%=hucek("id")%>" title="<%=hucek("kadi")%> isimli üyeye mesaj gönder.">Mesaj Gönder</a>
<li><a href="hizlierisimcikart.asp?uid=<%=hucek("id")%>" title="Bu Üyeyi Hýzlý Eriþim Listesinden Çýkart">Listeden Çýkart</a>
</font>
</td></tr></table>


</td>
<%
end if
hucek.close

if i>=maxuye then
a=cint(i/maxuye)
if (i-a*maxuye) = 0 then
%>
</tr><tr>
<%
end if
end if
end if
i=i+1
end if

next
%>
</tr>
</table>

<%
end if
%>
</td>
</tr>

<tr>
<td align=left>


<form method=post action="uyeara.asp">
Üye Ara : <input type=text name=kelime class=inptxt>&nbsp;<input type=submit value="Ara" class=sub>
<input type=hidden name=tip value="hara">
</form>


</td>
</tr>

</table>

</td>
</tr></table>