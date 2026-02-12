<%response.buffer=true%>
<%sayfaadi="Yönetim Üyeler"%>
<%sayfaurl="adminuyeler.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<b>GÖRÜNTÜLENECEK ÜYE SEÇÝMÝ</b>
<hr color=brown size=1>

<table border=0 cellpadding=3 cellspacing=1>
<tr>

<td style="border:1 solid brown;background:#ffffcc;">
Genel Sýralama<br>
<form method=get name=uyesec action="adminuyegor.asp">
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler order by kadi",bagg,1
%>
Üyeler : <select name=uyeid class=inptxt>
<%
i=1
do while not ks.eof
%>
<option value="<%=ks("id")%>"><%=i%> - <%=ks("kadi")%> - (<%=ks("isim")%>&nbsp;<%=ks("soyisim")%>)
<%
i=i+1
ks.movenext
loop

ks.close
set ks=nothing
%>
</select>
<input type=submit value="Göster" class=sub>
</form>
</td>

<td style="border:1 solid brown;background:#ffffcc;">
Aktif Üyeler<br>
<form method=get name=uyesec action="adminuyegor.asp">
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler  where aktiv = 1 and yasak = 0 order by kadi",bagg,1
if ks.eof then
response.write "Aktif Üye Bulunmuyor."
else
%>
Üyeler : <select name=uyeid class=inptxt>
<%
i=1
do while not ks.eof
%>
<option value="<%=ks("id")%>"><%=i%> - <%=ks("kadi")%> - (<%=ks("isim")%>&nbsp;<%=ks("soyisim")%>)
<%
i=i+1
ks.movenext
loop
%>

</select>
<input type=submit value="Göster" class=sub>
</form>
<%
end if
ks.close
set ks=nothing
%>
</td>

<td style="border:1 solid brown;background:#ffffcc;">
Aktivite Bekleyen Üyeler<br>
<form method=get name=uyesec action="adminuyegor.asp">
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where aktiv = 0 and yasak = 0 order by kadi",bagg,1
if ks.eof then
response.write "Aktivite Bekleyen Üye Bulunmuyor."
else
%>
Üyeler : <select name=uyeid class=inptxt>
<%
i=1
do while not ks.eof
%>
<option value="<%=ks("id")%>"><%=i%> - <%=ks("kadi")%> - (<%=ks("isim")%>&nbsp;<%=ks("soyisim")%>)
<%
i=i+1
ks.movenext
loop
%>
</select>
<input type=submit value="Göster" class=sub>
</form>
<%
end if
ks.close
set ks=nothing
%>
</td>

</tr>
<tr>

<td style="border:1 solid brown;background:#ffffcc;">
Yasaklý Üyeler<br>
<form method=get name=uyesec action="adminuyegor.asp">
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where yasak = 1 order by kadi",bagg,1
if ks.eof then
response.write "Yasaklý Üye Bulunmuyor."
else
%>
Üyeler : <select name=uyeid class=inptxt>
<%
i=1
do while not ks.eof
%>
<option value="<%=ks("id")%>"><%=i%> - <%=ks("kadi")%> - (<%=ks("isim")%>&nbsp;<%=ks("soyisim")%>)
<%
i=i+1
ks.movenext
loop
%>
</select>
<input type=submit value="Göster" class=sub>
</form>
<%
end if
ks.close
set ks=nothing
%>
</td>

<td style="border:1 solid brown;background:#ffffcc;">
Son Giriþ Tarihi Sýralamasý<br>
<form method=get name=uyesec action="adminuyegor.asp">
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where aktiv = 1 and yasak = 0 order by sontarih desc",bagg,1
if ks.eof then
response.write "Üye Bulunmuyor."
else
%>
Üyeler : <select name=uyeid class=inptxt>
<%
i=1
do while not ks.eof
%>
<option value="<%=ks("id")%>"><%=i%> - <%=ks("kadi")%> - (<%=ks("isim")%>&nbsp;<%=ks("soyisim")%>)
<%
i=i+1
ks.movenext
loop
%>
</select>
<input type=submit value="Göster" class=sub>
</form>
<%
end if
ks.close
set ks=nothing
%>
</td>

<td style="border:1 solid brown;background:#ffffcc;">
Online Üyeler<br>
<form method=get name=uyesec action="adminuyegor.asp">
<%
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where online = 1 order by kadi",bagg,1
if ks.eof then
response.write "Online Üye Bulunmuyor."
else
%>
Üyeler : <select name=uyeid class=inptxt>
<%
i=1
do while not ks.eof
%>
<option value="<%=ks("id")%>"><%=i%> - <%=ks("kadi")%> - (<%=ks("isim")%>&nbsp;<%=ks("soyisim")%>)
<%
i=i+1
ks.movenext
loop
%>
</select>
<input type=submit value="Göster" class=sub>
</form>
<%
end if
ks.close
set ks=nothing
%>
</td>

</tr></table>
<br>

  <%else%>
<!--#include file="admingiris.asp"-->
<%end if%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->