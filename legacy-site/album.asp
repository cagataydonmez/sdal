<%response.buffer=true%>
<%sayfaadi="Fotoðraf Albümü"%>
<%sayfaurl="album.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
set ayk=bagg.execute("select * from uyeler where id="&session_uyeid)
if ayk("albumadmin") = 1 then
%>
<br><br>
<a href="albumyonetim.asp">Albüm Yönetim</a>
<br><br>
<%end if%>
<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td>
<font style="color:#663300;font-size:15;"><b>Kategoriler</b></font>
</td>
</tr>
<%
set ks=bagg.execute("select * from album_kat where aktif=1")

if ks.eof then
response.write "Henüz bir kategori açýlmamýþ..."
else

do while not ks.eof
%>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;">
<%
set fsay=server.createobject("adodb.recordset")
fsay.open "select * from album_foto where aktif=1 and katid='"&ks("id")&"'",bagg,1
%>
<a href="albumkat.asp?kat=<%=ks("id")%>" title="<%=ks("aciklama")%>"><%=ks("kategori")%> ( Toplam <b><%=fsay.recordcount%></b> fotoðraf )</a>
<%fsay.close%>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;">
<a href="albumkat.asp?kat=<%=ks("id")%>" title="<%=ks("aciklama")%>" style="text-decoration:none;">
<%
kid = cStr(ks("id"))
set res=bagg.execute("select * from album_foto where aktif=1 and katid='"&kid&"' order by id desc")
if res.eof then
response.write "Henüz bir fotoðraf eklenmemiþ..."
else

i=1
do while not res.eof and i<=5
%>
<img src="kucukresim.asp?iheight=40&r=<%=res("dosyaadi")%>" border=1>
<%
i=i+1
res.movenext
loop
%>
Devamý için týklayýn...
<%end if%>
</a>
</td>
</tr>

<%
ks.movenext
loop
%>
<%end if%>

</table>
<br><br>
<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#ffffcc;">
<a href="albumfotoekle.asp" title="Fotoðraf eklemek için týklayýn." style="color:#663300;"><b>Fotoðraf Eklemek için týklayýn!</b></a>
</td>
</tr>
</table>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->