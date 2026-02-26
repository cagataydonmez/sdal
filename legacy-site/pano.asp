<%
Set bagm = Server.CreateObject("ADODB.Connection")
bagm.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")

isl = request.querystring("isl")

if isl = "myaz" then

katid = request.querystring("mkatid")

if Len(katid) = 0 then
katid = 0
katadi = "Genel"
else
if not isNumeric(katid) then
katid = 0
katadi = "Genel"
else

katid = cint(katid)
set katkon=bagm.execute("select * from mesaj_kategori where id="&katid)
if katkon.eof then
katid = 0
katadi = "Genel"
else
katadi=katkon("kategoriadi")
end if
end if

end if
%>
<form method=post action="panolar.asp?isl=myaz2" name=mesajform>
<table border=0 cellpadding=3 cellspacing=1 width=400>
<tr>
<td colspan=2 align=left style="border:1 solid #660000;background:#660000;color:white;font-size:13;">
<b>Mesaj Yaz</b>&nbsp;&nbsp;&nbsp;&nbsp;<a href="panolar.asp?mkatid=<%=katid%>" title="Geri Dön" style="color:white;"><b>Geri Dön</b></a>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;background:white;" align=right valign=top width=100>
<b>Mesaj : </b>
</td>
<td style="border:1 solid #663300;background:white;" align=left valign=top>
<textarea class=inptxt name=mesaj cols=50 rows=10></textarea>
<%'<a href="#" class="hintanchor" onMouseover="showhint('<img src=arrow-orange.gif border=0><b><u>Kullanýlabilecek kodlar</u></b><br><b>Kalýn Yazý</b> -> [b]yazý[/b]<br><i>Ýtalik Yazý</i> -> [i]yazý[/i]<br><u>Altý Çizili</u> -> [u]yazý[/u]<br><div align=right>Saða Yasla</div> -> [sagayasla]yazi[/sagayasla]<br><div align=left>Sola Yasla</div> -> [solayasla]yazi[/solayasla]<br><div align=center>Ortala</div> -> [ortala]yazi[/ortala]<br>', this, event, '200px')">[?]</a>
%>
</td>
</tr>
<tr>
<td colspan=2 style="border:1 solid #663300;background:white;" align=center valign=top>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('1');"><IMG src="smiley/1.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('2');"><IMG src="smiley/2.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('3');"><IMG src="smiley/3.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('4');"><IMG src="smiley/4.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('5');"><IMG src="smiley/5.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('6');"><IMG src="smiley/6.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('7');"><IMG src="smiley/7.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('8');"><IMG src="smiley/8.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('9');"><IMG src="smiley/9.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('10');"><IMG src="smiley/10.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('11');"><IMG src="smiley/11.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('12');"><IMG src="smiley/12.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('13');"><IMG src="smiley/13.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('14');"><IMG src="smiley/14.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('15');"><IMG src="smiley/15.gif" align=center border=0></A></TD>
<TD style="BORDER-RIGHT: 0px; BORDER-TOP: 0px; BACKGROUND: white; BORDER-LEFT: 0px; BORDER-BOTTOM: 0px" vAlign=center align=middle><A title="Yazýnýza eklemek için týklayýn!" style="CURSOR: hand" onclick="koy('16');"><IMG src="smiley/16.gif" align=center border=0></A></TD>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=2 style="border:1 solid #663300;background:white;" align=center valign=top>
<input type=submit value="Gönder" class=sub>
</td>
</tr>
</table>
<input type=hidden name=katid value="<%=katid%>">
</form>

<SCRIPT language=javascript>
function koy(ne)
{

a = document.mesajform.mesaj.value;
document.mesajform.mesaj.value = a + ":y" + ne + ":";
document.mesajform.mesaj.focus();

}
</SCRIPT>

<%
elseif isl = "myaz2" then

mesaj = request.form("mesaj")
katid = request.form("katid")

if Len(katid) = 0 then
katid = 0
else
if not isNumeric(katid) then
katid = 0
else

katid = cint(katid)
set katkon=bagm.execute("select * from mesaj_kategori where id="&katid)
if katkon.eof then
katid = 0
end if
end if

end if

if Len(mesaj) = 0 then
msg="Mesaj yazmadýn.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

mesaj = metinduzenle(mesaj)

set rs=server.createobject("adodb.recordset")

rs.open "select * from mesaj",bagm,1,3

rs.addnew

rs("gonderenid") = cint(session_uyeid)
rs("mesaj") = mesaj
rs("kategori") = katid

rs.update

rs.close

response.redirect "panolar.asp?mkatid="&katid

elseif isl="msil" then

if session_admingiris = "evet" then

meid = request.querystring("mid")
set ks=server.createobject("adodb.recordset")
ks.open "delete from mesaj where id="&cint(meid),bagm,1

response.redirect "panolar.asp"

end if

else

mkatid = request.querystring("mkatid")
if Len(mkatid) = 0 then
mkatid = 0
else
if not isNumeric(mkatid) then
mkatid = 0
else

mkatid = cint(mkatid)
set katkon=bagm.execute("select * from mesaj_kategori where id="&mkatid)
if katkon.eof then
mkatid = 0
end if
end if

end if

set ks=server.createobject("adodb.recordset")
ks.open "select * from mesaj where kategori="&mkatid&" order by tarih desc",bagm,1

if not ks.eof then

ks.pagesize = 25

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
end if
i=1

%>
<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td colspan=2 align=left style="border:1 solid #660000;background:#660000;color:white;font-size:13;">
<%
set mycek=bagg.execute("select * from uyeler where id="&cint(session_uyeid))
if mycek.eof then
response.write "yanlýþ giriþ!"
response.end
end if
pmyili = cstr(mycek("mezuniyetyili")) & " Mezunlarý"
set pkat=bagg.execute("select * from mesaj_kategori where kategoriadi='"&pmyili&"'")
%>
<%if mkatid=0 then%>
<b>GENEL Mesaj Panosu</b><%if not pkat.eof then%> | <b><a style="color:white;" href="panolar.asp?mkatid=<%=pkat("id")%>" title="Bu kategoriyi görmek için týklayýnýz"><%=pkat("kategoriadi")%> Panosu</a></b><%end if%>
<%else%>
<%if not pkat.eof then%><b><%=pkat("kategoriadi")%> Mesaj Panosu</b><%end if%> | <b><a style="color:white;" href="panolar.asp?mkatid=0" title="Bu kategoriyi görmek için týklayýnýz">Genel Mesaj Panosu</a></b>
<%end if%>
</td>
</tr>
<tr>
<td colspan=2 align=left style="border:1 solid #660000;background:#663300;color:white;font-size:13;">
<table border=0 cellspacing=2 cellpadding=5>
<tr>
<td style="background:white;border:2 solid black;" onmouseover="this.style.backgroundColor='navy';this.style.color:'white';" onmouseout="this.style.backgroundColor='white';this.style.color:'navy';">
<a href="panolar.asp?isl=myaz&mkatid=<%=mkatid%>" title="Mesaj Yazmak istiyorum" style="color:navy;text-decoration:none;"><b> MESAJ YAZ </b></a>
</td></tr></table>
</td>
</tr>
<%
if ks.eof then
response.write "</table><br><b>Kayýt Bulunamadý</b>"
ks.close
response.end
end if
%>
<%
mys=1

do while not ks.eof and i<=ks.pagesize
set uy=bagg.execute("select * from uyeler where id="&ks("gonderenid"))
if not uy.eof then

fark = DateDiff("s", mycek("oncekisontarih"), ks("tarih"))
%>

<tr>
<td style="border:1 solid #663300;background:white;" align=center valign=top width=50>
<a href="uyedetay.asp?id=<%=uy("id")%>" title="<%=uy("kadi")%> isimli üyenin profilini görüntüle">
<%if uy("resim") = "yok" then%>
<img src="kucukresim2.asp?iwidth=50&r=nophoto.jpg" border=1 width=50>
<%else%>
<img src="kucukresim2.asp?iwidth=50&r=<%=uy("resim")%>" border=1 width=50>
<%end if%>
</a>
</td>
<td style="border:1 solid #663300;background:<%if fark>0 then%>navy<%else%>white<%end if%>;" align=left valign=top height=100%>

<table border=0 cellpadding=3 cellspacing=1 width=100% height=100%>
<tr>
<td align=left valign=top style="border:1 solid #663300;background:#ffffcc;">
<b><%=uy("kadi")%></b> - <%=tarihduz(ks("tarih"))%>
<%if fark>0 then%> - <font style="color:red;"><b>YENÝ MESAJ!</b></font><%end if%> - <%=fark%>
<%if session_admingiris = "evet" then%> - <a href="panolar.asp?isl=msil&mid=<%=ks("id")%>">Sil <%=ks("id")%></a><%end if%>
</td>
</tr>
<tr>
<td align=justify valign=top style="border:1 solid #663300;background:white;" height=100%>
<%=ks("mesaj")%>
</td>
</tr>
</table>

</td>
</tr>
<%
if mys=10 then
%>
<tr>
<td colspan=2 align=left style="border:1 solid #660000;background:#663300;color:white;font-size:13;">
<a href="panolar.asp?isl=myaz&mkatid=<%=mkatid%>" title="Mesaj Yazmak istiyorum" style="color:white;text-decoration:none;"><b> MESAJ YAZ </b></a>
</td>
</tr>
<%
mys=0
end if
end if
mys=mys+1
i=i+1
ks.movenext
loop
%>
</table>

<table width=100% cellpadding=3 cellspacing=1>
<tr>
<%if ks.recordcount > ks.pagesize then%>
<td align=center style="border:1 solid #663300;background:white;" width=100%>
<table border=0 cellpadding=2 cellspacing=1><tr>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=1 then gitt=ks.pagecount else gitt=sf-1 end if%>
<b><a href="panolar.asp?sf=<%=gitt%>&mkatid=<%=mkatid%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;"><</a></b>
</td>
<%
ilksf = sf - 5
if ilksf<0 then
ilksf = 1
end if
sonsf = sf + 5
if sonsf>ks.pagecount then
sonsf = ks.pagecount
end if

for d=ilksf to sonsf
if d = sf then%>
<td style="background:yellow;border:1 solid #000033;" width=15 align=center>
<b><%=sf%></b>
</td>
<%else%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<b><a href="panolar.asp?sf=<%=d%>&mkatid=<%=mkatid%>" title="<%=d%>. sayfaya git."><%=d%></a></b>
</td>
<%end if
next%>
<td style="background:white;border:1 solid #ededed;" width=15 align=center>
<%if sf=ks.pagecount then gitt=1 else gitt=sf+1 end if%>
<b><a href="panolar.asp?sf=<%=gitt%>&mkatid=<%=mkatid%>" title="<%=gitt%>. sayfaya git." style="text-decoration:none;">></a></b>
</td>
</tr></table>
</td>
</tr>
<tr>
<%end if%>
<td align=center style="border:1 solid #663300;background:white;" width=100%>

<br>Toplam <b><%=ks.recordcount%></b> mesaj bulunmaktadýr.
</td></tr></table>

<%end if%>