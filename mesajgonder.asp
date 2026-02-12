<%response.buffer=true%>
<%sayfaadi="Mesaj Gönder"%>
<%sayfaurl="mesajgonder.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>
<%
if request.form("geldimi") = "evet" then
kime = request.form("kime")
konu = left(request.form("konu"),50)
mesaj = request.form("mesaj")

if Len(konu) = 0 then
konu = "Konusuz"
end if

if Len(mesaj) = 0 then
mesaj = "Sistem Bilgisi : [b]Boþ Mesaj Gönderildi![/b]"
end if

mesaj = metinduzenle(mesaj)

set rs=server.createobject("adodb.recordset")
rs.open "select * from gelenkutusu",bagg,1,3

rs.addnew

rs("kime") = kime
rs("kimden") = session_uyeid
rs("aktifgelen") = 1
rs("konu") = konu
rs("mesaj") = mesaj
rs("yeni") = 1
rs("tarih") = now()
rs("aktifgiden") = 1

rs.update

rs.close

response.write "Mesaj Gönderildi!<br><br><a href=mesajlar.asp>Mesajlar</a><br><br><a href=default.asp>Anasayfa</a>"

else
kime = request.querystring("kime")
set km=server.createobject("adodb.recordset")
km.open "select * from uyeler where id="&cint(kime),bagg,1

if km.eof then
response.write "Veritabanýnda böyle bir kayýt bulunamadý.Üye silinmiþ olabilir."
response.end
end if

ynt = request.querystring("ynt")
if not ynt = "" then
set yant=bagg.execute("select * from gelenkutusu where id="&cint(ynt))
if yant("kime") <> cstr(session_uyeid) then
response.redirect "default.asp"
end if

yntkonu = yant("konu")
yntmesaj = yant("mesaj")

yntt = 1

end if
%>
<form method=post action="mesajgonder.asp" name="mesajgonder">
<table border=1 cellpadding=3 cellspacing=3 bordercolor=#663300 bgcolor=#ffffcc>
<tr><td colspan=2 style="border:0;font-size:13;color:#663300;">
<b>Mesaj Gönder</b>
</td>
</tr>
<tr>
<td align=right valign=bottom style="border:0;">
<b>Alýcý : </b>
</td>
<td align=left style="border:0;">
<%if km("resim") = "yok" then%><img src="kucukresim6.asp?iheight=30&r=nophoto.jpg" border=1><%else%><img src="kucukresim6.asp?iheight=30&r=<%=km("resim")%>" border=1><%end if%> - <%=km("kadi")%>
</td>
</tr>
<tr>
<td align=right style="border:0;">
<b>Konu : </b>
</td>
<td align=left style="border:0;">
<input type=text name=konu size=30 class=inptxt<%if yntt=1 then%> value="Re:<%=yntkonu%>"<%end if%> style="color:black;">
</td>
</tr>
<tr>
<td align=right style="border:0;" valign=top>
<b>Mesaj : </b>
</td>
<td align=left style="border:0;">
<textarea class=inptxt name=mesaj cols=50 rows=10 style="color:black;"></textarea>
</td>
</tr>
<tr>
<td style="border:0;" align=left>
<input type=button value="Geri Dön" onclick="Javascript:history.back();" class=sub>
</td>
<td style="border:0;" align=right>
<input type=submit value="Gönder" class=sub onclick="this.value='Gönderiyor..';this.disabled=true;form.submit();">
</td>
</tr>

</table>
<input type=hidden name=geldimi value="evet">
<input type=hidden name=kime value="<%=kime%>">
</form>
<%end if%>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->