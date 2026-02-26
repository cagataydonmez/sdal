<% if session_uyegiris = "evet" then %>
</td></tr></table>
<%'##################### MENÜ VE ORTA ALAN BÝTÝÞÝ ##########################%>
<%end if%>
</td>
</tr>
<tr>
<td width=100% height=5 align=left valign=bottom background="downback.gif">
</td>
</tr>
<tr>
<td width=100% align=left valign=bottom style="background:white;border:1 solid brown;">
<table border=0 cellpadding=0 cellspacing=0 width=100%>
<tr>
<td style="color:#663300;border:1 solid #13104f;border-right:0;" width=100>
<img src=neredeyim.gif border=0 align=top>
</td>
<td style="color:#663300;border:1 solid #13104f;border-left:0;">
<%
if sayfayok=0 then
	ysbc=0
	do while not sayfaid=0
		set ks=bagg.execute("select * from sayfalar where id="&sayfaid)
			if not ks("sayfaurl") = "default.asp" then
				sayfaid = ks("babaid")
				if ysbc=0 then
					if ks("menugorun") = 1 then
						nirde = "<a href=" & ks("sayfaurl") & " style=""color:#663300;text-decoration:none;""><b>" & ks("sayfaismi") & "</b></a>"
					else
						nirde = "<b>" & ks("sayfaismi") & "</b>"
					end if
				else
					if ks("menugorun") = 1 then
					nirde = "<a href=" & ks("sayfaurl") & " style=""color:#663300;text-decoration:none;"">" & ks("sayfaismi") & "</a> >> " & nirde
					else
					nirde = ks("sayfaismi") & " >> " & nirde
					end if
				end if
			else
				sayfaid = 0
				syfa="def"
			end if
			ks.close
			set ks = Nothing
			ysbc=1
	loop
	if not syfa="def" then
		nirde = "<a href=default.asp title=Anasayfa style=""color:#663300;text-decoration:none;"">Anasayfa</a> >> " & nirde
	else
		nirde = "<a href=default.asp title=Anasayfa style=""color:#663300;text-decoration:none;""><b>Anasayfa</b></a>" & nirde
	end if
	
	response.write nirde
end if
%>
</td></tr></table>
</td>
</tr>
<tr>
<td width=100% height=50 align=left valign=bottom style="background:#663300;font-size:10;color:#FFFFCC;font-family:verdana;">
<center>
<hr color=#ffffcc size=1>
<%set kmenu=bagg.execute("select * from sayfalar where menugorun = 1 order by sayfaismi")
if not kmenu.eof then
i=1
do while not kmenu.eof
if (session_uyegiris <> "evet") or (kmenu("sayfaurl") <> "sifrehatirla.asp" and kmenu("sayfaurl") <> "uyekayit.asp") then
%>
<%if i<>1 then%>
 | 
<%end if%>
<a href="<%=kmenu("sayfaurl")%>" style="color:#FFFFCC;"><%=kmenu("sayfaismi")%></a>
<%
end if
kmenu.movenext
i=i+1
loop
end if
if session_uyegiris = "evet" then
set sjk=bagg.execute("select * from uyeler where id="&session_uyeid)
if sjk("admin") = 1 then
%>
 | <a href="admin.asp" style="color:#FFFFCC;">Yönetim</a>
<%
end if
end if
%>
<hr color=#ffffcc size=1>
</center>

<!--
<%'############# Online Uyeler Kontrolü (AJax) ########################### %>
<script language="javascript" type="text/javascript">
dinle2();
function dinle2() {

onlineukon();
t=setTimeout("dinle2()",5000)
}
</script>


<div id="oukkutusu" width=100%><b>Lütfen bekleyiniz..</b></div>

<%'############# Online Uyeler Kontrolü (AJax) Bitiþi ########################### %>
-->

<br><br> <b>&nbsp; <a href="http://www.sdal.org" style="color:#FFFFCC;">sdal.org</a> bir SDAL kuruluþudur.</b>
</td>
</tr>
</table>

</td>
</tr>
</table>
<%'#######################GOOGLE ANALÝTÝK ÝÇÝN KODLAR #################################################%>
<script src="http://www.google-analytics.com/urchin.js" type="text/javascript">
</script>
<script type="text/javascript">
_uacct = "UA-610941-2";
urchinTracker();
</script>
<%'#######################GOOGLE ANALÝTÝK ÝÇÝN KODLAR BÝTÝÞÝ#################################################%>
</body>
</html>