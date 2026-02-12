<%
Set bagg = Server.CreateObject("ADODB.Connection")
bagg.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")
%>

<%
set sitler=server.createobject("adodb.recordset")
sitler.open "select * from uyeler where online = 1 order by kadi",bagg,1,3

if sitler.eof then
response.write " Şu an sitede online üye bulunmamaktadır."
else

tarih1 = now()
do while not sitler.eof

tarih2 = sitler("sonislemtarih") & " " & sitler("sonislemsaat")
if isDate(tarih2) = True then
tfark = DateDiff("n",tarih2,tarih1)
end if

if tfark > 20 then
sitler("online") = 0
end if

%>
<img src=arrow-orange.gif border=0><a href="uyedetay.asp?id=<%=sitler("id")%>" class="hintanchor" onMouseover="showhint('<%if sitler("resim") = "yok" then%><img src=kucukresim6.asp?iheight=40&r=nophoto.jpg border=1 width=50 align=middle><%else%><img src=kucukresim6.asp?iheight=40&r=<%=sitler("resim")%> border=1 width=50 align=middle><%end if%>&nbsp;<font color=red><b><%=sitler("mezuniyetyili")%></b></font> mezunu!<br><b><%=sitler("isim")%>&nbsp;<%=sitler("soyisim")%></b> isimli Üyenin detaylarını görmek için tıklayınız.<br><b><%=tfark%> dakika</b>', this, event, '220px')" style="color:#663300;"><%=sitler("kadi")%></a><br>
<%

sitler.movenext
i=i+1
loop
end if%>