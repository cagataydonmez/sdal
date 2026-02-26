<%response.buffer=true%>
<%sayfaadi="Mesajlar"%>
<%sayfaurl="mesajlar.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
k = request.querystring("k")
if k<>"0" and k<>"1" then
k="0"
end if
%>
<table border=0 cellpadding=3 cellspacing=0 width=675>
<tr>
<td colspan=2 width=100% style="font-size:15;color:#663300;">
<b>Mesajlar</b>
</td>
</tr>
<tr>
<td width=75 valign=top>
[ <a href="mesajlar.asp?k=0" title="Gelen Mesajlar">Gelen</a> ]<br><br>
[ <a href="mesajlar.asp?k=1" title="Giden Mesajlar">Giden</a> ]
</td>
<td style="border:1 solid #ededed;background:white;" width=100%>

<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td colspan=4 style="border:1 solid #663300;background:navy;color:white;font-size:12;">
<%if k="0" then%>
<b>Gelen</b>
<%end if%>
<%if k="1" then%>
<b>Giden</b>
<%end if%>
</td>
</tr>
<%
set ks=server.createobject("adodb.recordset")
if k="0" then
ks.open "select * from gelenkutusu where kime = '"&cstr(session_uyeid)&"' and aktifgelen=1 order by tarih desc",bagg,1
elseif k="1" then
ks.open "select * from gelenkutusu where kimden = '"&cstr(session_uyeid)&"' and aktifgiden=1 order by tarih desc",bagg,1
end if

if ks.eof then
%>
<tr>
<td colspan=4 style="border:1 solid #663300;">
Kayýt bulunamadý..
</td>
</tr>
<%
else

ks.pagesize = 5
maxsayfa = 6 'Her zaman çift sayý!!

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
<td style="border:1 solid #663300;" width=200>
<%if k="0" then%>
<b>Gönderen</b>
<%else%>
<b>Gönderilen</b>
<%end if%>
</td>
<td style="border:1 solid #663300;" width=100>
<b>Tarih</b>
</td>
<td style="border:1 solid #663300;" width=250>
<b>Konu</b>
</td>
<td style="border:1 solid #663300;">
<b>Ýþlem</b>
</td>
</tr>
<%
do while not ks.eof and i<=ks.pagesize
%>
<tr>
<td style="border:1 solid #663300;">
<%if k="0" then
set kmd=bagg.execute("select * from uyeler where id="&cint(ks("kimden")))
else
set kmd=bagg.execute("select * from uyeler where id="&cint(ks("kime")))
end if
if kmd.eof then
response.write "Üye silinmiþ.."
else
%>
<a href="uyedetay.asp?id=<%=kmd("id")%>" title="<%=kmd("kadi")%> isimli üyenin detaylarý" style="text-decoration:none;">
<%if kmd("resim") = "yok" then%>
<img src="kucukresim6.asp?iheight=40&r=nophoto.jpg" border=1 align=center>
<%else%>
<img src="kucukresim6.asp?iheight=40&r=<%=kmd("resim")%>" height=40 border=1 align=center>
<%end if%>
</a> - <a href="uyedetay.asp?id=<%=kmd("id")%>" title="<%=kmd("kadi")%> isimli üyenin detaylarý"><b><%=kmd("kadi")%></b></a>
<%
end if
%>
</td>
<td style="border:1 solid #663300;">
<%tarih = tarihduz(ks("tarih"))
if Len(tarih)>0 then
dizi=split(tarih," ",-1,1)
end if%>
<%=dizi(0)%>&nbsp;<%=dizi(1)%>&nbsp;<%=dizi(2)%>
</td>
<td style="border:1 solid #663300;">
<a href="mesajgor.asp?mid=<%=ks("id")%>&kk=<%=k%>" title="Mesajý görmek için týklayýn.">
<%if ks("yeni") = 1 then%>
<%if k="0" then%><img src="yenimesaj.gif" border=0><%end if%><b><%=Left(ks("konu"),25)%></b><%if k="0" then%> ( Yeni )<%end if%>
<%else%>
<%if k="0" then%><img src="eskimesaj.gif" border=0><%end if%><%=Left(ks("konu"),25)%>
<%end if%>
</a>
</td>
<td style="border:1 solid #663300;" width=125>
<a href="mesajgonder.asp?kime=<%=kmd("id")%>" title="<%=kmd("kadi")%> isimli üyeye mesaj göndermek istiyorum.">Mesaj Gönder</a> / <a href="mesajsil.asp?mid=<%=ks("id")%>&kk=<%=k%>" title="Silmek için týklayýn..">Sil</a>
</td>
</tr>
<%
ks.movenext
i=i+1
kmd.close
loop
%>
<tr>
<td colspan=4 align=center style="border-left:1 solid #663300;border-right:1 solid #663300;border-bottom:1 solid #663300;">

<%if ks.recordcount > ks.pagesize then%>
<table border=0 cellpadding=2 cellspacing=1><tr>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=1 then gitt=ks.pagecount else gitt=sf-1 end if%>
<b><a href="mesajlar.asp?sf=<%=gitt%>&k=<%=k%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;"><</a></b>
</td>
<%for d=1 to ks.pagecount
if d>(sf-maxsayfa/2) and d<(sf+maxsayfa/2) then
if d = sf then%>
<td style="background:yellow;border:1 solid #000033;" width=15 align=center>
<b><%=sf%></b>
</td>
<%else%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<b><a href="mesajlar.asp?sf=<%=d%>&k=<%=k%>" title="<%=d%>. sayfaya git."><%=d%></a></b>
</td>
<%end if
end if
next%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=ks.pagecount then gitt=1 else gitt=sf+1 end if%>
<b><a href="mesajlar.asp?sf=<%=gitt%>&k=<%=k%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;">></a></b>
</td>
</tr></table>
<%end if%>
<table>
<tr><td colspan="<%=ks.pagecount%>" align=center>
<%if k="0" then%>
Okunmamýþ <b><%=ymv.recordcount%></b> mesaj bulunmaktadýr.
<%end if%>
<br>Toplam <b><%=ks.pagecount%></b> sayfada <b><%=ks.recordcount%></b> mesaj bulunmaktadýr.
</td></tr></table>


</td>
</tr>
<%end if%>
</table>

</td>
</tr>
</table>




<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->