<%response.buffer=true%>
<%sayfaadi="Yönetim Anasayfa"%>
<%sayfaurl="admin.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> |
<hr color=brown size=1>
<table border=0 cellpadding=20 cellspacing=1>
<tr><td width=200 style="border:1 solid #000033;background:white;">

Giriþ yapýldý..<br><br>

<table border=0 cellpadding=5 cellspacing=3>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="adminuyeler.asp">Üyeler</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="adminsayfalar.asp">Sayfalar</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="albumyonetim.asp">Albüm Yönetim</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="adminemailpanel.asp">E-Mail Paneli</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="adminlog.asp">Hata ve IP Kayýtlarý</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="uyedetaylog.asp">Üye Detay Kayýtlarý</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="futbolturnuva.asp">8-9 Aralýk F.Turnuvasý</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<li><a href="admincikis.asp">Yönetici Çýkýþ</a>
</td></tr>

<tr><td style="border:1 solid brown;background:#ffffcc;" width=200>
<form method=post action="adminuyeara.asp" name=adminuyeara>
<b>Üye Ara</b><br>
<input type=text name=anahtar class=inptxt> &nbsp; <input type=submit value="Ara" class=sub>
</form>
</td></tr>
</table

</td></tr></table>
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