<%response.buffer=true%>
<%sayfaadi="Oyun - Yýlan"%>
<%sayfaurl="oyunyilan.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>
<table border=0 cellpadding=0 cellspacing=0 width=100% height=100%>
<tr>
<td style="border:0;font-size:18;background:#660000;color:white;" colspan=2 align=center>
<b>YILAN OYUNU</b>
</td>
</tr>
<td align=left valign=top width=676>
<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://fpdownload.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0" width="676" height="500" id="sdalyilan" align="middle">
<param name="allowScriptAccess" value="sameDomain" />
<param name="movie" value="sdalyilan.swf" /><param name="loop" value="false" /><param name="quality" value="high" /><param name="devicefont" value="true" /><param name="bgcolor" value="#ffffff" /><embed src="sdalyilan.swf" loop="false" quality="high" devicefont="true" bgcolor="#ffffff" width="676" height="500" name="sdalyilan" align="middle" allowScriptAccess="sameDomain" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer" />
</object>

</td>
<td valign=top>
<IFRAME name="oyunyilanpuan" marginWidth=0 marginHeight=0 src="oyunyilanislem.asp" frameBorder=0 width=200 scrolling=no height=500>
</iframe>
</td>
</tr>
</table>

<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->