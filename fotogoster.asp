<%response.buffer=true%>
<%sayfaadi="Fotoðraf Albümü"%>
<%sayfaurl="fotogoster.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
fid = request.querystring("fid")
if Len(fid) = 0 or not isNumeric(fid) then
response.redirect "album.asp"
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from album_foto where id="&fid,bagg,1,3

if ks.eof then
response.redirect "album.asp"
end if
if ks("aktif") = 0 then
response.redirect "album.asp"
end if

set kat = bagg.execute("select * from album_kat where id="&ks("katid"))
if kat.eof then
response.redirect "album.asp"
end if
if kat("aktif") = 0 then
response.redirect "album.asp"
end if

ks("hit") = ks("hit") +1
ks.update
%>

<%
set bl=server.createobject("adodb.recordset")
bl.open "select * from album_foto where aktif=1 and katid='"&ks("katid")&"' order by tarih",bagg,1

onceki=0
sonraki=0
i=1
bitir = 0
do while not bl.eof

if bitir = 0 then
	if i=1 and bl("id") = ks("id") then
		onceki = 0
		if bl.recordcount = i then
			sonraki = 0
		else
			bl.movenext
			sonraki = bl("id")
		end if
		bitir = 1
	else
		if bl("id") = ks("id") then
			if bl.recordcount = i then
				sonraki = 0
			else
				bl.movenext
				sonraki = bl("id") 
			end if
			bitir = 1
		end if

	end if

end if

if bitir = 0 then
onceki = bl("id")
end if

bl.movenext
i=i+1


loop
bl.close
%>
<%'########################### Navigation Baþlangýcý #####################################################################################%>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td style="background:white;border:1 solid #660000;color:#663300;" align=center>

<%
bl.open "select * from album_foto where aktif=1 and katid='"&ks("katid")&"' order by tarih",bagg,1

bl.pagesize = 20

sf = request.querystring("sf")
if Len(sf) = 0 then
sf = 1
end if
if not isNumeric(sf) then
sf = 1
end if
sf = Cdbl(sf)

if sf<1 or sf>bl.pagecount then
sf = 1
end if

bl.absolutepage = sf
%>

<table border=0 cellpadding=2 cellspacing=1>
<tr>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%
set jdf=bagg.execute("select * from album_foto where aktif=1 and katid='"&ks("katid")&"' order by tarih")
i=1
l=(sf)*bl.pagesize + 1
m=(sf-1)*bl.pagesize - 0
do while not jdf.eof
if i=l then
fgidileri = jdf("id")
if sonraki = jdf("id") then
sonrakisf = sf+1
else
sonrakisf = sf
end if
end if

if i=m then
fgidgeri = jdf("id")
if onceki = jdf("id") then
oncekisf = sf-1
else
oncekisf = sf
end if
end if

i=i+1
jdf.movenext
loop
if len(oncekisf) = 0 then
oncekisf = sf
end if
if len(sonrakisf) = 0 then
sonrakisf = sf
end if
%>
<%if not (sf-1)=0 then%>
<a href="fotogoster.asp?fid=<%=fgidgeri%>&sf=<%=sf-1%>" style="color:blue;text-decoration:none;" title="Önceki 20"><b><<</b></a>
<%else%>
<font color=#ededed><b><<</b></font>
<%end if%>
</td>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if not onceki=0 then%>
<a href="fotogoster.asp?fid=<%=onceki%>&sf=<%=oncekisf%>" style="color:blue;text-decoration:none;" title="Bir önceki resime git"><b><</b></a>
<%else%>
<font color=#ededed><b><</b></font>
<%end if%>
</td>

<%
i=1
si=(sf-1)*bl.pagesize+1
do while not bl.eof and i<=bl.pagesize
if cint(fid) = bl("id") then
kacinci = si
%>
<td style="background:yellow;border:1 solid #000033;" width=15 align=center><b><%=si%></b></td>
<%
else
%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center><a href="fotogoster.asp?fid=<%=bl("id")%>&sf=<%=sf%>"><b><%=si%></b></a></td>
<%
end if
bl.movenext
si = si+1
i=i+1
loop

%>

<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if not sonraki=0 then%>
<a href="fotogoster.asp?fid=<%=sonraki%>&sf=<%=sonrakisf%>" style="color:blue;text-decoration:none;" title="Bir sonraki resime git"><b>></b></a>
<%else%>
<font color=#ededed><b>></b></font>
<%end if%>
</td>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if not (sf+1)>bl.pagecount then%>
<a href="fotogoster.asp?fid=<%=fgidileri%>&sf=<%=sf+1%>" style="color:blue;text-decoration:none;" title="Sonraki 20"><b>>></b></a>
<%else%>
<font color=#ededed><b>>></b></font>
<%end if%>
</td>
</tr></table>
</td></tr></table>
Toplam <b><%=bl.recordcount%></b> resim içinde <b><%=kacinci%>.</b> resime bakýyorsunuz.
<%bl.close%>
<%'########################### Navigation Bitiþi #####################################################################################%>

<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr><td style="background:#660000;border:1 solid #663300;" align=center>
<font style="font-size:13;color:#ffffcc;"><b><%=ks("baslik")%></b></font>
</td>
<td style="background:#ffffcc;border:1 solid #660000;" width=150 align=right>
Ekleyen : 
<%
set fe=bagg.execute("select * from uyeler where id="&ks("ekleyenid"))
if fe.eof then
response.write "<b>Üye silinmiþ</b>"
else
%>
<b><%=fe("kadi")%></b>
<%end if%>
</td>
</tr>
</table>
<hr color=#000033 size=1>
<a href="fotogoster.asp?fid=<%=sonraki%>&sf=<%=sonrakisf%>" style="color:blue;text-decoration:none;" title="Bir sonraki resime git">
<img src="kucukresim3.asp?r=<%=ks("dosyaadi")%>" border=1>
</a>
<hr color=#000033 size=1>
<%=ks("aciklama")%>
<hr color=#000033 size=1>

<%'########################### Navigation Baþlangýcý #####################################################################################%>
<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr>
<td style="background:white;border:1 solid #660000;color:#663300;" align=center>

<%
bl.open "select * from album_foto where aktif=1 and katid='"&ks("katid")&"' order by tarih",bagg,1

bl.pagesize = 20

sf = request.querystring("sf")
if Len(sf) = 0 then
sf = 1
end if
if not isNumeric(sf) then
sf = 1
end if
sf = Cdbl(sf)

if sf<1 or sf>bl.pagecount then
sf = 1
end if

bl.absolutepage = sf
%>

<table border=0 cellpadding=2 cellspacing=1>
<tr>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%
set jdf=bagg.execute("select * from album_foto where aktif=1 and katid='"&ks("katid")&"' order by tarih")
i=1
l=(sf)*bl.pagesize + 1
m=(sf-1)*bl.pagesize - 0
do while not jdf.eof
if i=l then
fgidileri = jdf("id")
if sonraki = jdf("id") then
sonrakisf = sf+1
else
sonrakisf = sf
end if
end if

if i=m then
fgidgeri = jdf("id")
if onceki = jdf("id") then
oncekisf = sf-1
else
oncekisf = sf
end if
end if

i=i+1
jdf.movenext
loop
if len(oncekisf) = 0 then
oncekisf = sf
end if
if len(sonrakisf) = 0 then
sonrakisf = sf
end if
%>
<%if not (sf-1)=0 then%>
<a href="fotogoster.asp?fid=<%=fgidgeri%>&sf=<%=sf-1%>" style="color:blue;text-decoration:none;" title="Önceki 20"><b><<</b></a>
<%else%>
<font color=#ededed><b><<</b></font>
<%end if%>
</td>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if not onceki=0 then%>
<a href="fotogoster.asp?fid=<%=onceki%>&sf=<%=oncekisf%>" style="color:blue;text-decoration:none;" title="Bir önceki resime git"><b><</b></a>
<%else%>
<font color=#ededed><b><</b></font>
<%end if%>
</td>

<%
i=1
si=(sf-1)*bl.pagesize+1
do while not bl.eof and i<=bl.pagesize
if cint(fid) = bl("id") then
kacinci = si
%>
<td style="background:yellow;border:1 solid #000033;" width=15 align=center><b><%=si%></b></td>
<%
else
%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center><a href="fotogoster.asp?fid=<%=bl("id")%>&sf=<%=sf%>"><b><%=si%></b></a></td>
<%
end if
bl.movenext
si = si+1
i=i+1
loop

%>

<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if not sonraki=0 then%>
<a href="fotogoster.asp?fid=<%=sonraki%>&sf=<%=sonrakisf%>" style="color:blue;text-decoration:none;" title="Bir sonraki resime git"><b>></b></a>
<%else%>
<font color=#ededed><b>></b></font>
<%end if%>
</td>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if not (sf+1)>bl.pagecount then%>
<a href="fotogoster.asp?fid=<%=fgidileri%>&sf=<%=sf+1%>" style="color:blue;text-decoration:none;" title="Sonraki 20"><b>>></b></a>
<%else%>
<font color=#ededed><b>>></b></font>
<%end if%>
</td>
</tr></table>
</td></tr></table>
Toplam <b><%=bl.recordcount%></b> resim içinde <b><%=kacinci%>.</b> resime bakýyorsunuz.
<%bl.close%>
<%'########################### Navigation Bitiþi #####################################################################################%>


<br><br>
<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;">
<a href="albumfotoekle.asp?kid=<%=kat("id")%>" title="Fotoðraf eklemek için týklayýn." style="color:#663300;"><b>Fotoðraf Eklemek için týklayýn!</b></a>
</td>
</tr>
</table>

<hr color=#000033 size=1>
<a href="albumkat.asp?kat=<%=kat("id")%>&sf=<%=sf%>" title="<%=kat("kategori")%> isimli sayfaya geri dön.."><%=kat("kategori")%> kategorisine geri dönmek için týklayýn..</a>
<br><br>
<a href="album.asp">Fotoðraf Albümü Anasayfasýna dönmek için týklayýn.</a>
<hr color=#000033 size=1>
<%
set yr = server.createobject("adodb.recordset")
yr.open "select * from album_fotoyorum where fotoid='"&ks("id")&"' order by tarih",bagg,1
%>
<%
if not yr.eof then
%>
<b><u>YORUMLAR</u></b>
<br><br>

<table border=0 cellpadding=3 cellspacing=0 bgcolor=#ffffcc width=300>
<%
ful = request.querystring("ful")

i=1
do while not yr.eof and i<=5
%>
<tr><td style="border:1 solid #663300;">
<b><%=yr("uyeadi")%></b> - <%=yr("yorum")%><br><br>
</td></tr>
<%
if ful <> "e" then
i=i+1
end if
yr.movenext
loop
%>
<tr><td style="border:1 solid #663300;">
<a href="fotogoster.asp?fid=<%=ks("id")%>&ful=e" title="Yapýlan bütün yorumlarý görmek için buraya týklayýn">Bu fotoðraf için yapýlan bütün yorumlar (Toplam:<%=yr.recordcount%>)</a>
</td></tr>
</table>
<%else%>
Henüz yorum eklenmemiþ.
<%end if%>

<form method=post action="albumyorumekle.asp">
<table border=0 cellpadding=3 cellspacing=1 width=100>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;" align=center>
<font style="color:#663300;"><b>Yorum Ekle</b></font>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;" align=center>
<textarea class=inptxt cols=30 rows=10 name=yorum></textarea>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;" align=center>
<input type=submit value="Kaydet" class=sub>
</td>
</tr>
</table><br>
<input type=hidden name=fid value="<%=ks("id")%>">
<input type=hidden name=sf value="<%=request.querystring("sf")%>">
</form>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->