<%response.buffer=true%>
<%sayfaadi="Mesaj Gör"%>
<%sayfaurl="mesajgor.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%
mesid = request.querystring("mid")
kk = request.querystring("kk")

set rs=server.createobject("adodb.recordset")
rs.open "select * from gelenkutusu where id="&cint(mesid),bagg,1,3

if rs.eof then
response.redirect "default.asp"
end if

if rs("kime") <> cstr(session_uyeid) and rs("kimden") <> cstr(session_uyeid) then
response.redirect "default.asp"
end if

if rs("kime") = cstr(session_uyeid) then
k=0
set ks=bagg.execute("select * from uyeler where id="&cint(rs("kimden")))
rs("yeni") = 0
rs.update
else
k=1
set ks=bagg.execute("select * from uyeler where id="&cint(rs("kime")))
end if
%>

<table border=0 cellpadding=10 cellspacing=0 width=600>
<tr>
<td width=100% style="font-size:15;color:#663300;">
<table border=0 cellpadding=0 cellspacing=0 width=100%>
<tr>
<td align=left style="font-size:15;color:#663300;"><b>Mesajı Görüntüle</b></td>
<td align=right><a href="mesajlar.asp?k=<%=kk%>" title="Mesajlar sayfasına geri dön">Mesajlar sayfasına geri dön >></a>
</tr>
</table>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;background:white;" width=100%>

<table border=0 cellpadding=5 cellspacing=1 width=100%>
<tr>
<td width=50 style="border:1 solid black;">
<%if ks("resim") = "yok" then%>
<img src="kucukresim6.asp?iwidth=50&r=nophoto.jpg" border=1 class="reflect rheight70 ropacity40">
<%else%>
<img src="kucukresim6.asp?iwidth=50&r=<%=ks("resim")%>" border=1 class="reflect rheight70 ropacity40">
<%end if%>
</td>
<td width=100% align=left valign=center>
<ul>
<%if k=0 then%>
<b>Gönderen : </b><%=ks("kadi")%>
<br><br>
<b>Alıcı : </b><%=session_kadi%>
<%else%>
<b>Gönderen : </b><%=session_kadi%>
<br><br>
<b>Alıcı : </b><%=ks("kadi")%>
<%end if%>
<br><br>
<b>Tarih : </b><%=tarihduz(rs("tarih"))%>
</ul>
</td>
</tr>
</table>
<hr color=#663300 size=1>
<b><%=rs("konu")%></b>
<hr color=#663300 size=1>
<%=rs("mesaj")%>

</td>
</tr>
<%if kk="0" then%>
<tr>
<td align=right>
<a href="mesajgonder.asp?kime=<%=ks("id")%>&ynt=<%=rs("id")%>" title="Mesajı YAnıtla">Yanıtla</a> - <a href="mesajsil.asp?mid=<%=rs("id")%>&kk=<%=kk%>" title="Silmek için tıkayın">Sil</a>
</td>
</tr>
<%end if%>
</table>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->