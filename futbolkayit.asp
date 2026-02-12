<%response.buffer=true%>
<%sayfaadi="Futbol Turnuvas&#305; Kay&#305;t Formu"%>
<%sayfaurl="futbolkayit.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then%>


<table border=0 cellpadding=3 cellspacing=2 width=100%>
<tr>
<td style="border:1 solid #663300;background:white;">

<table border=0 cellpadding=3 cellspacing=1 width=100%>
<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>SDAL Mezunlar Derne&#287;i Futbol Turnuvas&#305;</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>

<font style="color:red;font-family:Tahoma;font-size:20;">
15-16 Aral&#305;kta SDAL spor salonunda düzenlenecek turnuva için siz de tak&#305;m&#305;n&#305;z&#305; kurun!<br><br>
<font style="color:black;font-family:Tahoma;font-size:15;">
Turnuvaya kat&#305;lmak için a&#351;a&#287;&#305;daki form ile kay&#305;t yapt&#305;rman&#305;z gerekmektedir.
<br>Tak&#305;mlar 1 tak&#305;m kaptan&#305; ve 4 oyuncu olmak üzere toplam 5 ki&#351;iden olu&#351;acakt&#305;r. 
<br>Tak&#305;m kaptan&#305;n&#305;n kay&#305;t yapt&#305;rmas&#305; yeterlidir.<br>
Ayr&#305;ca SDAL d&#305;&#351;&#305;ndan bir ki&#351;i tak&#305;ma dahil edilebilir.<br></font>

<font style="color:red;font-family:Tahoma;font-size:15;">
<br><b>Son Ba&#351;vuru Tarihi : 12 Aralýk 2007<br>
Maç Program&#305; Duyuru Tarihi : 13 Aralýk 2007</b><br>

<br>* Sorular&#305;n&#305;z için irtibat telefonlar&#305; anasayfada bulunmaktad&#305;r.
</font>

<br><br>
<font style="color:black;font-family:Tahoma;font-size:15;text-decoration:none;">
<b>Not : </b>Þehir dýþýnda bulunan arkadaþlarýmýz için turnuva tarihi bir hafta ileriye alýnmýþtýr.
</font>

</td>
</tr>

<tr>
<td style="border:1 solid #663300;background:#660000;color:white;" align=left>
<b>Futbol Turnuvas&#305; Kay&#305;t Formu</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;color:#000033;" align=left valign=middle>

<%
if request.form("geldimi") = "evet" then

tisim = request.form("tisim")
tisim=Replace(tisim," ","-")
tisim=Replace(tisim,"'","")
if Len(tisim)=0 then
msg = "Yanlýþ Giriþ!! Tak&#305;m ismini girmen gerekiyor.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

tkid = request.form("tkid")

tktelefon = request.form("tktelefon")
tktelefon=Replace(tktelefon," ","-")
tktelefon=Replace(tktelefon,"'","")
if Len(tktelefon)=0 then
msg = "Yanlýþ Giriþ!! &#304;leti&#351;im sa&#287;layabilmemiz için <br>tak&#305;m kaptan&#305;n&#305;n telefonunu yazmas&#305; gerekiyor.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

boyismi = request.form("boyismi")
boyismi=Replace(boyismi," ","-")
boyismi=Replace(boyismi,"'","")
if Len(boyismi)=0 then
msg = "Yanlýþ Giriþ!! Oyuncular&#305;n isimlerini girmen gerekiyor.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

boymezuniyet = request.form("boymezuniyet")
if boymezuniyet = "bos" then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncunun mezuniyet tarihini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if
if boymezuniyet = "1000" then
boymezuniyet = "Dýþarýdan"
end if

ioyismi = request.form("ioyismi")
ioyismi=Replace(ioyismi," ","-")
ioyismi=Replace(ioyismi,"'","")
if Len(ioyismi)=0 then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncular&#305;n isimlerini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

ioymezuniyet = request.form("ioymezuniyet")
if ioymezuniyet = "bos" then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncunun mezuniyet tarihini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if
if ioymezuniyet = "1000" then
ioymezuniyet = "Dýþarýdan"
end if

uoyismi = request.form("uoyismi")
uoyismi=Replace(uoyismi," ","-")
uoyismi=Replace(uoyismi,"'","")
if Len(uoyismi)=0 then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncular&#305;n isimlerini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

uoymezuniyet = request.form("uoymezuniyet")
if uoymezuniyet = "bos" then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncunun mezuniyet tarihini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if
if uoymezuniyet = "1000" then
uoymezuniyet = "Dýþarýdan"
end if

doyismi = request.form("doyismi")
doyismi=Replace(doyismi," ","-")
doyismi=Replace(doyismi,"'","")
if Len(doyismi)=0 then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncular&#305;n isimlerini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

doymezuniyet = request.form("doymezuniyet")
if doymezuniyet = "bos" then
msg = "Yanl&#305;&#351; Giri&#351;!! Oyuncunun mezuniyet tarihini girmen gerekiyor.<br>&#304;stersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if
if doymezuniyet = "1000" then
doymezuniyet = "Dýþarýdan"
end if

set tks = server.createobject("adodb.recordset")
tks.open "select * from uyeler where id="&tkid,bagg,1
if tks.eof then
response.write "YANLI&#350; G&#304;R&#304;&#350;!ÜYE BULUNAMADI!!"
response.end
end if
tkgisim = tks("isim") & "&nbsp;" & tks("soyisim")
tks.close
set tks=nothing

Set tkbag = Server.CreateObject("ADODB.Connection")
tkbag.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("turnuvadata.mdb")

set trs=server.createobject("adodb.recordset")
trs.open "select * from takimlar",tkbag,1,3

trs.addnew

trs("tisim") = tisim
trs("tkid") = tkid
trs("tktelefon") = tktelefon
trs("boyismi") = boyismi
trs("boymezuniyet") = boymezuniyet
trs("ioyismi") = ioyismi
trs("ioymezuniyet") = ioymezuniyet
trs("uoyismi") = uoyismi
trs("uoymezuniyet") = uoymezuniyet
trs("doyismi") = doyismi
trs("doymezuniyet") = doymezuniyet
trs("tarih") = now()

trs.update
trs.close
set trs=nothing
tkbag.close
set tkbag=nothing
%>
<font style="color:red;font-size:20;">
Kay&#305;t i&#351;leminiz ba&#351;ar&#305;yla tamamland&#305;!
</font>
<br><br>

<b>Tak&#305;m &#304;smi : </b><%=tisim%><br>
<b>Tak&#305;m Kaptan&#305; : </b><%=tkgisim%><br>
<b>T.K. Telefonu : </b><%=tktelefon%><br>
<b>1.Oyuncu : </b><%=boyismi%> ( <%if boymezuniyet="1000" then%>D&#305;&#351;ar&#305;dan<%else%><%response.write boymezuniyet%><%end if%> )<br>
<b>2.Oyuncu : </b><%=ioyismi%> ( <%if ioymezuniyet="1000" then%>D&#305;&#351;ar&#305;dan<%else%><%response.write ioymezuniyet%><%end if%> )<br>
<b>3.Oyuncu : </b><%=uoyismi%> ( <%if uoymezuniyet="1000" then%>D&#305;&#351;ar&#305;dan<%else%><%response.write uoymezuniyet%><%end if%> )<br>
<b>4.Oyuncu : </b><%=doyismi%> ( <%if doymezuniyet="1000" then%>D&#305;&#351;ar&#305;dan<%else%><%response.write doymezuniyet%><%end if%> )<br>

<%
else
%>
<font style="color:red;">
<br>
&nbsp;&nbsp;** Lütfen bütün alanlar&#305; eksiksiz doldurunuz.
</font>

<form method=post action=futbolkayit.asp?isl=kyt>
<table border=0 cellpadding=3 cellspcing=2>
<tr>
<td colspan=2 align=left style="border-bottom:1 solid #000033;">
<b>Tak&#305;m Bilgileri</b>
</td>
</tr>

<tr>
<td align=right>
Tak&#305;m &#304;smi : 
</td>
<td align=left>
<input type=text size=20 name="tisim">
</td>
</tr>

<tr>
<td colspan=2 align=left style="border-bottom:1 solid #000033;">
<b>Tak&#305;m Kaptan&#305;</b>
</td>
</tr>
<tr>
<td align=right>
T.Kaptan&#305; &#304;smi : 
</td>
<td align=left>
<b><%=session_kadi%></b>
<input type=hidden name=tkid value="<%=session_uyeid%>">
</td>
</tr>
<tr>
<td align=right>
T.Kaptan&#305; Telefonu : 
</td>
<td align=left>
<input type=text size=20 name="tktelefon">
</td>
</tr>

<tr>
<td colspan=2 align=left style="border-bottom:1 solid #000033;">
<b>Di&#287;er Oyuncular</b>
</td>
</tr>

<tr>
<td align=right>
1.Oyuncu &#304;smi : 
</td>
<td align=left>
<input type=text size=20 name="boyismi">
&nbsp;&nbsp;
<select name=boymezuniyet>
<option value="bos">Seçiniz
<% for i=1999 to 2011 %>
<option value=<%=i%>><%=i%> Mezunu
<% next %>
<option value="1000">D&#305;&#351;ar&#305;dan
</select>
</td>
</tr>

<tr>
<td align=right>
2.Oyuncu &#304;smi : 
</td>
<td align=left>
<input type=text size=20 name="ioyismi">
&nbsp;&nbsp;
<select name=ioymezuniyet>
<option value="bos">Seçiniz
<% for i=1999 to 2011 %>
<option value=<%=i%>><%=i%> Mezunu
<% next %>
<option value="1000">D&#305;&#351;ar&#305;dan
</select>
</td>
</tr>

<tr>
<td align=right>
3.Oyuncu &#304;smi : 
</td>
<td align=left>
<input type=text size=20 name="uoyismi">
&nbsp;&nbsp;
<select name=uoymezuniyet>
<option value="bos">Seçiniz
<% for i=1999 to 2011 %>
<option value=<%=i%>><%=i%> Mezunu
<% next %>
<option value="1000">D&#305;&#351;ar&#305;dan
</select>
</td>
</tr>

<tr>
<td align=right>
4.Oyuncu &#304;smi : 
</td>
<td align=left>
<input type=text size=20 name="doyismi">
&nbsp;&nbsp;
<select name=doymezuniyet>
<option value="bos">Seçiniz
<% for i=1999 to 2011 %>
<option value=<%=i%>><%=i%> Mezunu
<% next %>
<option value="1000">D&#305;&#351;ar&#305;dan
</select>
</td>
</tr>

<tr>
<td colspan=2 align=center>
<input type=hidden name="geldimi" value="evet">
<input type=submit value="Kaydet!" class=sub>
</td>
</tr>

</table>

</form>

<%end if%>

</td>
</tr>
</table>

</td></tr>
</table>


<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->