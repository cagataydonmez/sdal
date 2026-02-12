<%response.buffer=true%>
<%sayfaadi="Yönetim Üye Arama"%>
<%sayfaurl="adminuyeara.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<%
res=request.querystring("res")
if Len(res)=0 then
anahtar = request.form("anahtar")

if Len(anahtar) = 0 then
msg = "Aranacak anahtar kelime girmedin.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where kadi like '%"&anahtar&"%' or isim like '%"&anahtar&"%' or soyisim like '%"&anahtar&"%' order by kadi",bagg,1

else
set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where not resim='yok' order by kadi",bagg,1
end if

if ks.eof then
msg = "Arama sonucunda herhangi bir kayýt bulunamadý.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
else
i=1
%>
<table border=0 cellapdding=1 cellspacing=0>
<%
do while not ks.eof
%>
<tr><td>
<%if ks("resim") = "yok" then%>
<%=i%> - <img src="kucukresim5.asp?r=nophoto.jpg" border=1 width=50>&nbsp;<a href="adminuyegor.asp?uyeid=<%=ks("id")%>"><%=ks("kadi")%> - <%=ks("isim")%>&nbsp;<%=ks("soyisim")%></a>
<%else%>
<%=i%> - <a href=uyedetay.asp?id=<%=ks("id")%> title="Üye Detay"><img src="kucukresim5.asp?r=<%=ks("resim")%>" border=1 width=50></a>&nbsp;<a href="adminuyegor.asp?uyeid=<%=ks("id")%>"><%=ks("kadi")%> - <%=ks("isim")%>&nbsp;<%=ks("soyisim")%></a>
<%end if%>
</td></tr>
<%
i=i+1
ks.movenext
loop
%>
</table>
<%
end if
%>
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