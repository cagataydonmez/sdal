<body topmargin=0 leftmargin=0>
<%
Set bag = Server.CreateObject("ADODB.Connection")
bag.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("oyunlar.mdb")

topkac=25

if request.querystring("naap") = "2222tttt" then

set ss = server.createobject("adodb.recordset")
ss.open "delete * from oyun_tetris",bag,1,3

response.write "Hepsi silindi!"

end if

isl = request.form("islem")


if isl="puanekle" then

kadi = request.cookies("kadi")
if Len(kadi) = 0 then
kadi = "Misafir"
end if

puan = cdbl(request.form("puan"))
seviye = cdbl(request.form("seviye"))
satir = cdbl(request.form("satir"))

set rs=server.createobject("adodb.recordset")
rs.open "select * from oyun_tetris where isim='"&kadi&"'",bag,1,3

if rs.eof then

rs.close
rs.open "select * from oyun_tetris",bag,1,3

rs.addnew
rs("isim") = kadi

end if

if puan > rs("puan") then
rs("puan") = puan
rs("seviye") = seviye
rs("satir") = satir
rs("tarih") = now()
end if



rs.update

rs.close
set rs=nothing


set ks=server.createobject("adodb.recordset")
ks.open "select * from oyun_tetris order by puan desc",bag,1
%>
<table border=0 width=100% cellpadding=1 cellspacing=0>
<tr>
<td colspan=4 style="font-family:arial;font-size:11;background:#660000;color:white;border:1 solid #660000;border-top:1 solid white;">
<b>En Yüksek Puanlar</b>
</td>
</tr>

<tr>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
İsim
</td>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
Puan
</td>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
Seviye
</td>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
Satır
</td>
</tr>

<%
i=1
r=0
do while not ks.eof and i <= topkac
%>
<tr>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;<%if r=0 then%>background:#ededed;<%end if%>"><b><%=i%>. </b><%=left(ks("isim"),15)%></td>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;<%if r=0 then%>background:#ededed;<%end if%>" align=left><%=ks("puan")%></td>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;<%if r=0 then%>background:#ededed;<%end if%>" align=left><%=ks("seviye")%></td>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;<%if r=0 then%>background:#ededed;<%end if%>" align=left><%=ks("satir")%></td>
</tr>
<%
if r=0 then
r=1
else
r=0
end if

ks.movenext
i=i+1
loop
%>
</table>

<%
ks.close
set ks=nothing
%>


<%
else

set ks=server.createobject("adodb.recordset")
ks.open "select * from oyun_tetris order by puan desc",bag,1
%>
<table border=0 width=100% cellpadding=1 cellspacing=0>
<tr>
<td colspan=4 style="font-family:arial;font-size:11;background:#660000;color:white;border:1 solid #660000;border-top:1 solid white;">
<b>En Yüksek Puanlar</b>
</td>
</tr>

<tr>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
İsim
</td>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
Puan
</td>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
Seviye
</td>
<td style="font-family:arial;font-size:10;background:#660000;color:white;border:1 solid #660000;font-weight:bold;">
Satır
</td>
</tr>

<%
i=1
r=0
do while not ks.eof and i <= topkac
%>
<tr>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;<%if r=0 then%>background:#ededed;<%end if%>"><b><%=i%>. </b><%=left(ks("isim"),15)%></td>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;<%if r=0 then%>background:#ededed;<%end if%>" align=left><%=ks("puan")%></td>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;<%if r=0 then%>background:#ededed;<%end if%>" align=left><%=ks("seviye")%></td>
<td width=50% style="font-family:arial;font-size:10;color:#660000;border:1 solid #660000;border-left:0;<%if r=0 then%>background:#ededed;<%end if%>" align=left><%=ks("satir")%></td>
</tr>
<%
if r=0 then
r=1
else
r=0
end if

ks.movenext
i=i+1
loop
%>
</table>

<%
ks.close
set ks=nothing

end if
%>