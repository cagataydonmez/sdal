<%response.buffer=true%>
<%sayfaadi="Yönetim Futbol Turnuvasý"%>
<%sayfaurl="futbolturnuva.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<b>8-9 Aralýk Futbol Turnuvasýna Katýlacaklar Listesi</b>
<br><br>
<%
Set tkbag = Server.CreateObject("ADODB.Connection")
tkbag.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("turnuvadata.mdb")

if request.querystring("isl") = "s" then
tid = request.querystring("tid")

set dtk=tkbag.execute("delete from takimlar where id="&tid)
response.redirect "futbolturnuva.asp?sbsr=ok"

else

set tks = server.createobject("adodb.recordset")
tks.open "select * from takimlar",tkbag,1
%>
<br>
<%if request.querystring("sbsr") = "ok" then%>
<b>Kayýt baþarýyla silindi!!!</b><br><br>
<%end if%>
<table border=0 width=100% cellpadding=3 cellspacing=0>
<tr>
<td style="border:1 solid black;"><b>#</b></td>
<td style="border:1 solid black;"><b>Takým Ýsmi</b></td>
<td style="border:1 solid black;"><b>Takým Kaptaný</b></td>
<td style="border:1 solid black;"><b>Kayýt Tarihi</b></td>
<td style="border:1 solid black;"><b>Oyuncular</b></td>
</tr>
<%
if tks.eof then
%>
<tr>
<td colspan=5 style="border:1 solid black;">
<b>Henüz kayýt eklenmemiþ...</b>
</td>
</tr>
<%
else

i=1
do while not tks.eof
set tkks=bagg.execute("select * from uyeler where id="&tks("tkid"))
%>
<tr>
<td valign=top style="border:1 solid black;"><%=i%><br><a href="futbolturnuva.asp?isl=s&tid=<%=tks("id")%>">Sil</a></td>
<td valign=top style="border:1 solid black;"><%=tks("tisim")%></td>
<td valign=top style="border:1 solid black;">
<img src="kucukresim2.asp?iwidth=50&r=<%=tks("tkid")%>.jpg" align=top>
<a href="uyedetay.asp?id=<%=tks("tkid")%>"><%=tkks("isim")%>&nbsp;<%=tkks("soyisim")%>&nbsp;( <%=tkks("mezuniyetyili")%> )</a>&nbsp; Tel : <%=tks("tktelefon")%></td>
<td valign=top style="border:1 solid black;"><%=tks("tarih")%></td>
<td valign=top style="border:1 solid black;">
<b>1. </b><%=tks("boyismi")%> ( <%=tks("boymezuniyet")%> )<br>
<b>2. </b><%=tks("ioyismi")%> ( <%=tks("ioymezuniyet")%> )<br>
<b>3. </b><%=tks("uoyismi")%> ( <%=tks("uoymezuniyet")%> )<br>
<b>4. </b><%=tks("doyismi")%> ( <%=tks("doymezuniyet")%> )<br>
</td>
</tr>
<%
i=i+1
tks.movenext
loop

tkks.close
set tkks=nothing

end if

tks.close
set tkd=nothing
%>
</table>
<%
tkbag.close
set tkbag=nothing
end if%>

  <%else%>
<!--#include file="admingiris.asp"-->
<%end if%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->