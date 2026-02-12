<%response.buffer=true%>
<%sayfaadi="Oyun"%>
<%sayfaurl="oyun.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>


<br><br>
<table border=0 cellpadding=0 cellspacing=0>
<tr>
<td style="border:1 solid #660000;background:#660000;color:white;" align=center width=263>
<a href="oyunyilan.asp" title="Yýlan Oyunu" style="background:#660000;color:white;padding:10;border:1 solid #660000;padding-left:75;padding-right:75;"><b>Yýlan Oyunu</b></a>
</td>
</tr>
<tr>
<td width=263>
<a href="oyunyilan.asp" title="Yýlan Oyunu"><img src=oyun-kucuk.jpg border=1 align=middle></a>
</td>
</tr>
<tr>
<td style="border:1 solid #660000;background:white;color:#660000;" width=263 align=center>
Bildiðimiz basit yýlan oyunu. Klavyedeki yön tuþlarýný kullanarak yýlana yön verin ve elmalarý toplayýn. Elmalarý ne kadar hýzlý toplarsanýz o kadar çok puan kazanýrsýnýz.
</td>
</tr>
</table>

<br><br>
<table border=0 cellpadding=0 cellspacing=0>
<tr>
<td style="border:1 solid #660000;background:#660000;color:white;" align=center width=263>
<a href="oyuntetris.asp" title="Tetris Oyunu" style="background:#660000;color:white;padding:10;border:1 solid #660000;padding-left:75;padding-right:75;"><b>Tetris Oyunu</b></a>
</td>
</tr>
<tr>
<td width=263 style="background:white;" align=center>
<a href="oyuntetris.asp" title="Tetris Oyunu"><img src=tetris-kucuk.jpg border=1 align=middle></a>
</td>
</tr>
<tr>
<td style="border:1 solid #660000;background:white;color:#660000;" width=263 align=center>
Klasik tetris oyunu.
</td>
</tr>
</table>




<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->