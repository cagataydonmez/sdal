<%response.buffer=true%>
<%sayfaadi="Yönetim Sayfalar"%>
<%sayfaurl="adminsayfalar.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
| <a href="adminsayfaekle.asp">Yeni Sayfa Ekle</a> |
<hr color=brown size=1>
<table border=0 cellpadding=3 cellspacing=1>
<tr>
<td style="border:1 solid #000033;font-weight:bold;">
ID
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Sayfa Ýsmi
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Sayfa Url
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Hit
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Son Tarih
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Son Üye
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Baba ID
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Menüde Görün?
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Yönlendir?
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Sayfa Metni
</td>
<td style="border:1 solid #000033;font-weight:bold;">
M.Ozellik?
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Resim
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Son IP
</td>
<td style="border:1 solid #000033;font-weight:bold;">
Ýþlem
</td>
</tr>
<%
set sf = server.createobject("adodb.recordset")
sf.open "select * from sayfalar order by sayfaismi",bagg,1

do while not sf.eof
%>
<tr onmouseover="this.style.backgroundColor='#ffffcc';" onmouseout="this.style.backgroundColor='white';">
<td style="border:1 solid #000033;">
<%
dsyadi = sf("id") & month(now()) & year(now()) & ".txt"
%>
<a href="adminsayfalog.asp?dg=e&da=<%=dsyadi%>" title="Sayfa Giriþ Kayýtlarý (en son ay)"><%=sf("id")%></a>
</td>
<td style="border:1 solid #000033;">
<a href="<%=sf("sayfaurl")%>" target="_blank"><%=sf("sayfaismi")%></a>
</td>
<td style="border:1 solid #000033;">
<%=sf("sayfaurl")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("hit")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("sontarih")%>
</td>
<td style="border:1 solid #000033;">
<a href="#" class="hintanchor" onMouseover="showhint('<%=soncek(dsyadi,20)%>', this, event, '250px')"><%=sf("sonuye")%></a>
</td>
<td style="border:1 solid #000033;">
<%=sf("babaid")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("menugorun")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("yonlendir")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("sayfametin")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("mozellik")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("resim")%>
</td>
<td style="border:1 solid #000033;">
<%=sf("sonip")%>
</td>
<td style="border:1 solid #000033;">
<a href="adminsayfasil.asp?sfid=<%=sf("id")%>">Sil</a> / <a href="adminsayfaduz.asp?sfid=<%=sf("id")%>">Düzenle</a>
</td>
</tr>
<%
sf.movenext
loop
%>
</table>
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