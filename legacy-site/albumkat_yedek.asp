<%response.buffer=true%>
<%sayfaadi="Fotoðraf Albümü"%>
<%sayfaurl="albumkat.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>


<%
kat = request.querystring("kat")
if Len(kat) = 0 or not isNumeric(kat) then
responce.redirect "album.asp"
end if

set kas = server.createobject("adodb.recordset")
kas.open "select * from album_kat where id="&kat,bagg,1

if kas("aktif") = 0 then
response.redirect "album.asp"
end if
%>
<hr color=#663300 size=1>
<a href="album.asp">Albüm Anasayfa</a>
<hr color=#663300 size=1>
<br><br>
<b>Fotoðraflarý tam boy olarak görmek için üzerlerine týklayýn.</b>
<br><br>

<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from album_foto where aktif=1 and katid='"&cstr(kat)&"' order by tarih",bagg,1 

ks.pagesize = 20

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

<%if ks.recordcount > ks.pagesize then%>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr><td style="border:1 solid #663300;background:white;" align=center>

<table border=0 cellpadding=2 cellspacing=1><tr>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=1 then gitt=ks.pagecount else gitt=sf-1 end if%>
<b><a href="albumkat.asp?kat=<%=kat%>&sf=<%=gitt%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;"><</a></b>
</td>
<%for d=1 to ks.pagecount
if d = sf then%>
<td style="background:yellow;border:1 solid #000033;" width=15 align=center>
<b><%=sf%></b>
</td>
<%else%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<b><a href="albumkat.asp?kat=<%=kat%>&sf=<%=d%>" title="<%=d%>. sayfaya git."><%=d%></a></b>
</td>
<%end if
next%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=ks.pagecount then gitt=1 else gitt=sf+1 end if%>
<b><a href="albumkat.asp?kat=<%=kat%>&sf=<%=gitt%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;">></a></b>
</td>
</tr></table>

</td></tr></table>
<%end if%>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr><td style="border:1 solid #663300;background:white;" align=center>
<%if ks.pagesize*(cint(sf)) > ks.recordcount then
sonres = ks.recordcount
else
sonres = ks.pagesize*(cint(sf))
end if%>
Toplam <b><%=ks.recordcount%></b> resimden <b><%=(ks.pagesize*(cint(sf)-1)+1)%></b> ile <b><%=sonres%></b> arasýnda bulunanlara bakýyorsunuz.
</td></tr></table>

<table border=0 cellpadding=8 cellspacing=0 width="100%">
<tr>
<td colspan=5 style="border:1 solid #663300;background:#ffffcc;">
<a href="album.asp" title="Kategoriler">Kategoriler</a> <font color=blue>>></font> <b><%=kas("kategori")%></b>
</td>
</tr>
<%
kl=(cint(sf)-1)*ks.pagesize+1
maxsf = 20
do while not ks.eof and i<=ks.pagesize
%>
<tr>
<%if not ks.eof then
xx = cint(kl/maxsf)
if kl/maxsf < xx then
xx = xx - 1
end if
fsf = xx + 1%>
<td style="border:1 solid #000000;background:#CCFFE6;" align=center>
<a href="fotogoster.asp?fid=<%=ks("id")%>&sf=<%=fsf%>" title="<%=ks("baslik")%>"><img src="kucukresim.asp?iheight=100&r=<%=ks("dosyaadi")%>" border=1><br><font style="font-size:9;font-weight:bold;color:navy;">Büyüt</font></a>
<%i=i+1
kl=kl+1
ks.movenext%>
</td>
<%end if%>
<%if not ks.eof then
xx = cint(kl/maxsf)
if kl/maxsf < xx then
xx = xx - 1
end if
fsf = xx + 1%>
<td style="border:1 solid #000000;background:white;" align=center>
<a href="fotogoster.asp?fid=<%=ks("id")%>&sf=<%=fsf%>" title="<%=ks("baslik")%>"><img src="kucukresim.asp?iheight=100&r=<%=ks("dosyaadi")%>" border=1><br><font style="font-size:9;font-weight:bold;color:navy;">Büyüt</font></a>
<%i=i+1
kl=kl+1
ks.movenext%>
</td>
<%end if%>
<%if not ks.eof then
xx = cint(kl/maxsf)
if kl/maxsf < xx then
xx = xx - 1
end if
fsf = xx + 1%>
<td style="border:1 solid #000000;background:#CCFFE6;" align=center>
<a href="fotogoster.asp?fid=<%=ks("id")%>&sf=<%=fsf%>" title="<%=ks("baslik")%>"><img src="kucukresim.asp?iheight=100&r=<%=ks("dosyaadi")%>" border=1><br><font style="font-size:9;font-weight:bold;color:navy;">Büyüt</font></a>
<%i=i+1
kl=kl+1
ks.movenext%>
</td>
<%end if%>
<%if not ks.eof then
xx = cint(kl/maxsf)
if kl/maxsf < xx then
xx = xx - 1
end if
fsf = xx + 1%>
<td style="border:1 solid #000000;background:white;" align=center>
<a href="fotogoster.asp?fid=<%=ks("id")%>&sf=<%=fsf%>" title="<%=ks("baslik")%>"><img src="kucukresim.asp?iheight=100&r=<%=ks("dosyaadi")%>" border=1><br><font style="font-size:9;font-weight:bold;color:navy;">Büyüt</font></a>
<%i=i+1
kl=kl+1
ks.movenext%>
</td>
<%end if%>
<!--
<%if not ks.eof then
xx = cint(kl/maxsf)
if kl/maxsf <= xx then
xx = xx - 1
end if
fsf = xx + 1%>
<td style="border:1 solid #000000;background:#FFCCE6;" align=center>
<a href="fotogoster.asp?fid=<%=ks("id")%>&sf=<%=fsf%>" title="<%=ks("baslik")%>"><img src="kucukresim.asp?iheight=100&r=<%=ks("dosyaadi")%>" border=1><br><font style="font-size:9;font-weight:bold;color:navy;">Büyüt</font></a>

</td>
<%end if%>
-->
</tr>

<%
if not ks.eof then
i=i+1
kl=kl+1
ks.movenext
end if
loop
%>
</table>
<br><br>
<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;">
<a href="albumfotoekle.asp?kid=<%=kat%>" title="Fotoðraf eklemek için týklayýn." style="color:#663300;"><b>Fotoðraf Eklemek için týklayýn!</b></a>
</td>
</tr>
</table>

<%if ks.recordcount > ks.pagesize then%>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr><td style="border:1 solid #663300;background:white;" align=center>

<table border=0 cellpadding=2 cellspacing=1><tr>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=1 then gitt=ks.pagecount else gitt=sf-1 end if%>
<b><a href="albumkat.asp?kat=<%=kat%>&sf=<%=gitt%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;"><</a></b>
</td>
<%for d=1 to ks.pagecount
if d = sf then%>
<td style="background:yellow;border:1 solid #000033;" width=15 align=center>
<b><%=sf%></b>
</td>
<%else%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<b><a href="albumkat.asp?kat=<%=kat%>&sf=<%=d%>" title="<%=d%>. sayfaya git."><%=d%></a></b>
</td>
<%end if
next%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=ks.pagecount then gitt=1 else gitt=sf+1 end if%>
<b><a href="albumkat.asp?kat=<%=kat%>&sf=<%=gitt%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;">></a></b>
</td>
</tr></table>

</td></tr></table>
<%end if%>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr><td style="border:1 solid #663300;background:white;" align=center>
<%if ks.pagesize*(cint(sf)) > ks.recordcount then
sonres = ks.recordcount
else
sonres = ks.pagesize*(cint(sf))
end if%>
Toplam <b><%=ks.recordcount%></b> resimden <b><%=(ks.pagesize*(cint(sf)-1)+1)%></b> ile <b><%=sonres%></b> arasýnda bulunanlara bakýyorsunuz.
</td></tr></table>

<hr color=#663300 size=1>
<a href="album.asp">Albüm Anasayfa</a>
<hr color=#663300 size=1>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->