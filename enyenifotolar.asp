<%response.buffer=true%>
<%sayfaadi="En Yeni Foto&#287;raflar"%>
<%sayfaurl="enyenifotolar.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>

<%'################## En yeni xx fotoðraf ############################### %>
<hr color=#662233 size=1>
<table bordeR=0 cellpadding=2 cellspacing=0 width=100%>
<tr>
<td style="background:#660000;color:white;">
<b>En Yeni Foto&#287;raflar</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=center>
<%
set sxft=server.createobject("adodb.recordset")
sxft.open "select * from album_foto where aktif=1 order by id desc",bagg,1

kacfoto=100

i=1

do while not sxft.eof and i<=kacfoto

set ahj=server.createobject("adodb.recordset")
ahj.open "select * from album_foto where katid='"&sxft("katid")&"' and aktif=1",bagg,1
fsira = 1
fkn=0
do while not ahj.eof
if fkn=0 then
fsira = fsira + 1
end if
if ahj("id") = sxft("id") then
fkn=1
end if
ahj.movenext
loop
 
ahj.close
set ahj=nothing

fotsf = fsira/20
if fotsf > cint(fotsf) then
fotsf = cint(fotsf) + 1
else
fotsf = cint(fotsf)
end if
if fotsf=0 then
fotsf=1
end if
%>
<%
set sxft2=server.createobject("adodb.recordset")
sxft2.open "select * from album_kat where id="&cint(sxft("katid")),bagg,1
%>
<a href="fotogoster.asp?fid=<%=sxft("id")%>&sf=<%=fotsf%>" class="hintanchor" onMouseover="showhint('<b><%=sxft2("kategori")%></b><br><img src=kucukresim.asp?iwidth=250&r=<%=sxft("dosyaadi")%> border=1 width=250>', this, event, '250px')"><img src="kucukresim.asp?iwidth=100&r=<%=sxft("dosyaadi")%>" border=1>
</a>
<b><%=sxft("tarih")%> - <%=sxft("hit")%></b>

<%
sxft2.close
set sxft2=nothing
sxft.movenext

set ahj=server.createobject("adodb.recordset")
ahj.open "select * from album_foto where katid='"&sxft("katid")&"' and aktif=1",bagg,1
fsira = 1
do while not ahj.eof and ahj("id") < sxft("id")
fsira = fsira + 1
ahj.movenext
loop

ahj.close
set ahj=nothing

fotsf = fsira/20
if fotsf > cint(fotsf) then
fotsf = cint(fotsf) + 1
else
fotsf = cint(fotsf)
end if
if fotsf=0 then
fotsf=1
end if
set sxft2=server.createobject("adodb.recordset")
sxft2.open "select * from album_kat where id="&cint(sxft("katid")),bagg,1
%>

<a href="fotogoster.asp?fid=<%=sxft("id")%>&sf=<%=fotsf%>" class="hintanchor" onMouseover="showhint('<b><%=sxft2("kategori")%></b><br><img src=kucukresim.asp?iwidth=250&r=<%=sxft("dosyaadi")%> border=1 width=250>', this, event, '250px')"><img src="kucukresim.asp?iwidth=100&r=<%=sxft("dosyaadi")%>" border=1>
</a>
<b><%=sxft("tarih")%> - <%=sxft("hit")%></b>

<hr color=#ededed size=1>
<%
sxft2.close
set sxft2=nothing
i=i+1
sxft.movenext
loop
sxft.close
set sxft=nothing
%>
<hr color=#662233 size=1>
<a href="albumfotoekle.asp" title="Fotoðraf Albümüne yeni fotoðraf/fotoðraflar yüklemek için týklayýnýz.">Yeni Fotoðraf Ekle</a>
</td>
</tr>
</table>

<%'################## En yeni xx fotoðraf bitiþi ############################### %>



<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->