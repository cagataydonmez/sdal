<%response.buffer=true%>
<%sayfaadi="Yönetim Üye Gör"%>
<%sayfaurl="adminuyegor.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<a href="adminuyeler.asp">| Yönetim Üyeler |</a>
<hr color=brown size=1>
<%
uyeid = request.querystring("uyeid")
if Len(uyeid) = 0 then
response.redirect "admin.asp"
end if

set ks = server.createobject("adodb.recordset")
ks.open "select * from uyeler where id="&uyeid,bagg,1
if ks.eof then
response.write "böyle bir üye bulunmamaktadýr..."
else
%>
<b>Üye Bilgileri : <i><%=ks("kadi")%> ( <%=ks("id")%> )</i></b>
<hr color=brown size=1>
<%
tarih1 = now()

tarih2 = ks("sonislemtarih") & " " & ks("sonislemsaat")
if isDate(tarih2) = True then
response.write DateDiff("n",tarih2,tarih1)
end if
%>
<form method=post action="adminuyeduzenle.asp" name="adminuyeduzenle">
<table border=0 cellpadding=3 cellspacing=1>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Üye ID : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("id")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin benzersiz id numarasý,kayýt sýrasýnda otomatik atanýr.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Kullanýcý Adý : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("kadi")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin kendi belirlediði kullanýcý adý.
</td>
</tr>

<% if session_uyeid = "1" then%>
<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Þifre : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=sifre value="<%=ks("sifre")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin þifresi,senden baþkasý göremez.
</td>
</tr>
<%end if%>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Ýsim : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=isim value="<%=ks("isim")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin ismi.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Soyisim : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=soyisim value="<%=ks("soyisim")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin soyismi.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Aktivasyon Kodu : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=aktivasyon value="<%=ks("aktivasyon")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Mail adresine gönderilen aktivasyon kodu.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>E-mail : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=email value="<%=ks("email")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin e-mail adresi. (doðruluðu aktivasyon sayesinde kanýtlanýr.)
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Aktivite : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=aktiv value="<%=ks("aktiv")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin aktivasyonu tamamlayýp tamamlamadýðýný gösterir. ( 1:aktif, 0:aktif deðil )
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Yasaklý : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=yasak value="<%=ks("yasak")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin yasaklanýp yasaklanmadýðýný gösterir.( 1:Yasaklý , 0:normal )
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Ýlk Giriþ : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=ilkbd value="<%=ks("ilkbd")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Sisteme ilk giriþ yapýldýðýnda bilgiler güncellenmemiþse deðer <b>0</b> dir.yoksa 1.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Web Sitesi : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=websitesi value="<%=ks("websitesi")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin websitesi.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Ýmza : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><textarea name=imza class=inptxt cols=40 rows=5><%=ks("imza")%></textarea></td>
<td style="border:1 solid brown;" valign=top><font style="color:red;"><b>?</b></font>
Üyenin Ýmzasý
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Meslek : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=meslek value="<%=ks("meslek")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin mesleði.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Þehir : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top>
<select name=sehir class=inptxt>
<%
for i=0 to 80%>
<option value="<%=iller(i)%>"<%if ks("sehir") = iller(i) then%> selected<%end if%>><%=iller(i)%>
<%next%>
</select>
</td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin bulunduðu þehir.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Mail Kapalýlýðý : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=mailkapali value="<%=ks("mailkapali")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Mail görünürlüðü.1:diðer üyeler göremez, 0 :diðer üyeler görebilir.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Hit : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=hit value="<%=ks("hit")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin siteye giriþ sayýsý.
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Mezuniyet Yýlý : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=mezuniyetyili value="<%=ks("mezuniyetyili")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin Mezuniyet Yýlý <i>Örn:2000</i>
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Üniversite : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=universite value="<%=ks("universite")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin okuduðu veya mezun olduðu üniversite
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Doðum Günü : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=2 class=inptxt name=dogumgun value="<%=ks("dogumgun")%>">.<input type=text size=2 class=inptxt name=dogumay value="<%=ks("dogumay")%>">.<input type=text size=4 class=inptxt name=dogumyil value="<%=ks("dogumyil")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin doðum günü
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Son Ýþlem Tarihi : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("sonislemtarih")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin sitede yaptýðý son iþlemin tarihi
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Son iþlem saati : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("sonislemsaat")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin sitede yaptýðý son iþlemin saati
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Online : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("online")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin baðlý olup olmama durumu (1 : baðlý )
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Kayýt Tarih : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("ilktarih")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin kaydolduðu tarih
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Son Giriþ Tarihi : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("sontarih")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin siteye girdiði son tarih
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Admin mi? : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=admin value="<%=ks("admin")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin yönetici olup olmama durumu (1:yönetici)
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Son IP : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><%=ks("sonip")%></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin baðlandýðý son ip numarasý
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;" align=right valign=top><b>Resim : </b></td>
<td style="border-bottom:1 solid brown;" alignt=left valign=top><input type=text size=40 class=inptxt name=resim value="<%=ks("resim")%>"></td>
<td style="border:1 solid brown;"><font style="color:red;"><b>?</b></font>
Üyenin vesikalýk resmi :) <a href="vesikalik/<%=ks("resim")%>" target="_blank">Resmi görmek için týkla</a> (resimler <i>vesikalik</i> klasörü altýnda olacak)
</td>
</tr>

<tr>
<td style="border-right:1 solid brown;">
&nbsp;
</td>
<td colspan=3 align=center style="border-right:1 solid brown;border-bottom:1 solid brown;">
<input type=submit class=sub value="Düzenle">
</td>
</tr>

</table>
<input type=hidden name=uyeid value="<%=ks("id")%>">
</form>
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