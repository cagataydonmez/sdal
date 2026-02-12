<%response.buffer=true%>
<%sayfaadi="Oyun - Tetris"%>
<%sayfaurl="oyuntetris.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>
<center>
<table border=0 cellpadding=0 cellspacing=0>
<tr>
<td style="border:0;font-size:18;background:#660000;color:white;" colspan=2 align=center>
<b>TETRÝS OYUNU</b>
</td>
</tr>
<td align=left valign=top width=300>
<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://fpdownload.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0" width="300" height="400" id="sdaltetris" align="middle">
<param name="allowScriptAccess" value="sameDomain" />
<param name="movie" value="sdaltetris.swf" /><param name="quality" value="high" /><param name="bgcolor" value="#ffffff" /><embed src="sdaltetris.swf" quality="high" bgcolor="#ffffff" width="300" height="400" name="sdaltetris" align="middle" allowScriptAccess="sameDomain" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer" />
</object>

</td>
<td valign=top>
<IFRAME name="oyuntetrispuan" marginWidth=0 marginHeight=0 src="oyuntetrisislem.asp" frameBorder=0 width=300 scrolling=no height=400>
</iframe>
</td>
</tr>
</table>
</center>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->