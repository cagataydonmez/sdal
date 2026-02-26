<%
Set bag = Server.CreateObject("ADODB.Connection")
asd = server.mappath("datamizacx.mdb")
bag.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & asd

if request.cookies("uyegiris") = "evet" then
yasakkontrol(request.cookies("uyeid"))
end if
%>
<%
'##################### SUB - HATAMSG #######################################################
%>
<%
sub hatamsg(msg,sf)
%>

<%
klasor = "hatalog"
set hlog=CreateObject("Scripting.FileSystemObject")
yol = hlog.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)
'response.write yol
If hlog.FolderExists(yol) = True Then

tarih = date()
dizi = split(tarih,"/",-1,1)
dosya = dizi(0) & dizi(2) & ".txt"

If hlog.FileExists(hlog.buildpath(yol,dosya)) = False Then 
hlog.CreateTextFile hlog.buildpath(yol,dosya)
Set gc = hlog.OpenTextFile(hlog.buildpath(yol,dosya),2,0)
gc.WriteLine("HATA KAYITLARI ##############################")
gc.WriteLine("#############################################")
gc.WriteLine("#############################################")
gc.WriteLine("####  www.sdal.org - Her hakký saklýdýr. ####")
gc.WriteLine("#############################################")
gc.WriteLine("#############################################")
gc.WriteBlankLines(2) 'iki boþ satýr ekler.
gc.WriteLine("Üye - Sayfa - Tarih - Hata Mesajý")
gc.WriteLine("---------------------------------")
gc.WriteBlankLines(1)
gc.Close
end if

Set htlog = hlog.OpenTextFile(hlog.buildpath(yol,dosya),8,0)
if request.cookies("uyeid") = "" then
uyye = "Anonim"
else
uyye = request.cookies("uyeid")
end if
htlog.WriteLine(uyye &" - "& sf &" - "& now() &" - "& msg)
htlog.WriteBlankLines(1)

end if
%>

<center>
<table border=0 cellpadding=0 cellspacing=0 width=430 style="border:1 solid #000033;">
<tr>
<td width=15 height=15 background="kose_su.gif">
</td>
<td style=background:#FFFFCC;" width=300 height=15>

</td>
<td width=15 height=15 background="kose_sau.gif">
</td>
</tr>

<tr>
<td width=15 height=150 style="background:#FFFFCC;">

</td>
<td width=400 height=150 bgcolor=#FFFFCC style="font-size:11;" align="center">

<font class=hatamsg1><b>Ýþlem yapýlýrken bir hatayla karþýlaþýldý!!<br><br>
HATA : </b></font><%=msg%>
<br><br>
<a href="javascript:history.back(1);">Geri Dön</a>
<br><br><br>
<input type=text value="Sf:<%=sf%>" disabled class=hatamsg2>

</td>
<td width=15 height=150 style="background:#FFFFCC;">

</td>
</tr>

<tr>
<td width=15 height=15 background="kose_sa.gif">
</td>
<td style=background:#FFFFCC;" width=300 height=15>

</td>
<td width=15 height=15 background="kose_saa.gif">
</td>
</tr>
</table>
</center>
<!--#include file="ayak.asp"-->
<%
end sub
'##################### SUB - HATAMSG BÝTÝÞÝ#######################################################
%>
<%
'##################### SUB - EMAILKONTROL #######################################################

sub emailkontrol(Mail) 



dim mailkonrtol



     mailkontrol=Mail
     mailkontrol=replace(mailkontrol,"Ý","*")' türkçe karakterleri * yapapýyoruz.Buraya özel karakterleride yazabiliriz.
     mailkontrol=lcase(mailkontrol)
     mailkontrol=replace(mailkontrol,"ý","*")
     mailkontrol=replace(mailkontrol,"ö","*")
     mailkontrol=replace(mailkontrol,"ð","*")
     mailkontrol=replace(mailkontrol,"þ","*")
     mailkontrol=replace(mailkontrol,"ç","*")
     mailkontrol=replace(mailkontrol,"ü","*")


  
     muzunluk=len(mailkontrol)
     ozel=0
     normal=0
     hatali=0
     nokta=0
     mesaj=""
               for a=1 to muzunluk+1 ' Harf harf kontrole baþlýyoruz.
               denetim=mid(mailkontrol,a,1)
                'response.write denetim
                    
                    if a=1 and denetim="@" then ' ilk karakter @ ise hata
                         mesaj="hata"
                    end if
                    
                    if a=muzunluk and denetim="@" then ' son karakter @ ise hata
                         mesaj="hata"
                    end if
                    
                    if a=1 and denetim="." then ' ilk karakter . ise hata
                         mesaj="hata"
                    end if
                    
                    if a=muzunluk and denetim="." then ' son karakter . ise hata
                         mesaj="hata"
                    end if

                    if denetim="@" then ' burada @ karakterini saydýrýyoruz
                         ozel=ozel+1
                    elseif denetim="*" then ' burada * karakterini saydýrýyoruz bunlar türkçe karakterler
                         hatali=hatali+1
                    elseif denetim="." then ' burada . karakterini saydýrýyoruz
                         nokta=nokta+1
                    else
                         normal=normal+1
                    end if
               next


          if ozel=1 and normal>5 and hatali=0 and nokta > 0 and nokta < 4 and mesaj="" then
          
          else 
     response.write "<font class=hatamsg1><b>Ýþlem yapýlýrken bir hatayla karþýlaþýldý!!</b></font><br><br>E-Mail adresi : " &mailkontrol%>
                    <br>
                    <br>
                    <br>
                    <br>
                    <center>
                    E-Mail adresi doðru görünmüyor. Lütfen Geri Dönüp
                    
                              <% if hatali>0 then ' burda hata mesajlarýnýn ne olduðunu yazdýrýyoruz.%>
                                        Türkçe Karakter olup olmadýðýný 
                              
                              <% elseif ozel<>1 then %>
                                         (@) iþaretini 
                              
                              <% elseif normal<5 then %>
                                        kullanýcý ve site adýný 
                              
                              <% elseif nokta<1 then %>
                                         (.) Nokta Kullanýlýp Kullanýlmadýðýný 
                              
                               <% elseif nokta >3 then %>
                                        Kaç adet (.) Nokta Kullanýldýðýný 
                              
                              <%
                              elseif mesaj="hata" then %>
                                        @ ve . iþaretini adresin normal yerinde kullanýlýp kullanýlmadýðýný
                              
                              <% end if %>
                    
                    Kontrol Ediniz<br>
                    <br><a href="javascript:history.back(1);">Geri dön</a></center>

                    <%
                    response.end
          end if
          'emailkontrol=mailkontrol
end sub 
'##################### SUB - EMAILKONTROL BÝTÝÞÝ #######################################################


'##################### SUB - FÝLTRE #######################################################
sub filtre(klm,ne)

set flt=server.createobject("adodb.recordset")
flt.open "select * from filtre",bag,1

dizi = split(klm," ",-1,1)

do while not flt.eof

for each kel in dizi

	if kel=flt("kufur") then
		msg = "Girdiðiniz " & ne & " uygun olmayan bir kelime içeriyor.("& kel &")"
		call hatamsg(msg,"uyekayit.asp")
		response.end
	end if

next

flt.movenext
loop
end sub
'##################### SUB - FÝLTRE BÝTÝÞÝ #######################################################


'##################### SUB - UZUNLUKKONTROL #######################################################
sub uzunlukkontrol(metin,uzunluk,ne,sayfa)

if len(metin) > uzunluk then
msg="Girdiðiniz "&ne& " " &uzunluk& " karakterden uzun olmamalýdýr."
call hatamsg(msg,sayfa)
response.end
end if

end sub
'##################### SUB - UZUNLUKKONTROL BÝTÝÞÝ #######################################################


'##################### SUB - DBKONTROL #######################################################
sub dbkontrol(sey,tablo,seyadi,ne,sayfa)

set ks=server.createobject("adodb.recordset")
ks.open "select * from "&tablo&" where "&seyadi&"='"&sey&"'",bag,1

if not ks.eof then
if sayfa="onay.asp" then
msg = "Kayýt iþleminizi zaten tamamladýnýz! Lütfen yenile butonunu veya geri butonunu kullanmayýnýz..."
else
msg="Girdiðiniz "&ne&" (<b>"& sey &"</b>) veritabanýmýzda zaten kayýtlýdýr.<br>Baþka bir "&ne&" girmeniz gerekmektedir."
end if

call hatamsg(msg,sayfa)
response.end
end if

end sub
'##################### SUB - DBKONTROL BÝTÝÞÝ #######################################################


'##################### FUNCTION - AKTIVURET #######################################################
function aktivuret()

dizi = array("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","r","s","t","u","v","y","z","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","R","S","T","U","V","Y","Z")

uzun=20

akt="SdAl"

for i=1 to uzun

randomize

no=cint((rnd*45+1))-1

akt = akt & dizi(no)

next

aktivuret=akt

end function
'##################### FUNCTION - AKTIVURET BÝTÝÞÝ #######################################################


'##################### SUB - MAIL #######################################################
sub mail(from,fromname,kime,subject,format,cbase,cloc,body)

set msg = Server.Createobject("JMail.Message")

msg.Logging = true
msg.silent = true

msg.from = from
msg.fromname = fromname

msg.AddRecipient kime

msg.subject = subject

'msg.Body = body
msg.HTMLbody = body

msg.AddHeader "Originating-IP", Request.ServerVariables("REMOTE_ADDR")

msg.Send("mail.sdal.org")


end sub

'##################### SUB - EMAIL BÝTÝÞÝ #######################################################


'##################### SUB - AKTIVASYONGONDER #######################################################
sub aktivasyongonder(uid,kadi,sifre,email,isim,soyisim,aktivasyon)

body = ""
body = body & "<body bgcolor=""#663300"" topmargin=0 leftmargin=0>"
body = body & "<table border=0 width=100% height=100% cellpadding=0 cellspacing=0>"
body = body & "<tr><td width=100% height=100% bgcolor=""#663300"" align=center valign=center>"

body = body & "<table border=0 width=100% height=300 cellpadding=0 cellspacing=0>"
body = body & "<tr><td width=100% height=50 align=left valign=bottom style=""background:#663300;"">"
body = body & "<a href=""http://www.sdal.org/"" title=""Anasayfaya gider..."" target=""_blank""><img src=""http://www.sdal.org/logo.gif"" border=0></a>"

body = body & "</td></tr><tr><td width=100% height=8 align=left valign=bottom background=""http://www.sdal.org/upback.gif"">"
body = body & "</td></tr><tr><td width=100% height=150 align=center valign=center style=""background:#FFCC99;"">"

body = body & "Sayýn <b>" &isim& " " &soyisim& ",</b><br><a href=http://www.sdal.org/aktivet.asp?id="&uid&"&akt="&aktivasyon&" target=""_blank"">Üyelik iþleminizin tamamlanabilmesi için lütfen burayý týklayýnýz!!</a><br><br>"
body = body & "Kullanýcý adýnýz : " & kadi & "<br>Þifreniz : " & sifre
body = body & "<br><br><a href=http://www.sdal.org/aktivet.asp?id="&uid&"&akt="&aktivasyon&" target=""_blank"">Uyelik isleminizin tamamlanabilmesi icin lutfen burayi tiklayiniz!!</a><br><br>"
body = body & "Eðer link görünmüyorsa þu adrese kopyala-yapýþtýr metoduyla giriniz.<br>Aktivasyon adresi : http://www.sdal.org/aktivet.asp?id="&uid&"&akt="&aktivasyon&"<br><br>"

body = body & "</td></tr><tr><td width=100% height=5 align=left valign=bottom background=""http://www.sdal.org/downback.gif"">"
body = body & "</td></tr><tr><td width=100% height=50 align=left valign=bottom style=""background:#663300;font-size:10;color:#FFFFCC;font-family:verdana;"">"
 body = body & "<b>&nbsp; <a href=""http://www.sdal.org/"" style=""color:#FFFFCC;"" target=""_blank"">sdal.org</a> bir sdal kuruluþudur.</b></td></tr></table>"

body = body & "</td></tr></table>"


call mail("sdal@sdal.org","SDAL Üye Kayýt Motoru",email,"SDAL.ORG - Üyelik Baþvurusu","html","http://www.sdal.org","sdal/",body)

response.write "E-Mail baþarýyla gönderildi.<br>"

end sub
'##################### SUB - AKTIVASYONGONDER BÝTÝÞÝ#######################################################


'##################### SUB - SIFREGONDER #######################################################
sub sifregonder(uid,kadi,sifre,email,isim,soyisim)

body = ""
body = body & "<body bgcolor=""#663300"" topmargin=0 leftmargin=0>"
body = body & "<table border=0 width=100% height=100% cellpadding=0 cellspacing=0>"
body = body & "<tr><td width=100% height=100% bgcolor=""#663300"" align=center valign=center>"

body = body & "<table border=0 width=100% height=300 cellpadding=0 cellspacing=0>"
body = body & "<tr><td width=100% height=50 align=left valign=bottom style=""background:#663300;"">"
body = body & "<a href=""http://www.sdal.org/"" title=""Anasayfaya gider..."" target=""_blank""><img src=""http://www.sdal.org/logo.gif"" border=0></a>"

body = body & "</td></tr><tr><td width=100% height=8 align=left valign=bottom background=""http://www.sdal.org/upback.gif"">"
body = body & "</td></tr><tr><td width=100% height=150 align=center valign=center style=""background:#FFCC99;"">"

body = body & "Sayýn <b>" &isim& " " &soyisim& ",</b><br><br>Bize þifre hatýrlama amacýyla baþvurdunuz.<br>Aþþaðýda kullanýcý adýnýzý ve þifrenizi görebilirsiniz.<br><br>"
body = body & "Kullanýcý adýnýz : " & kadi & "<br>Þifreniz : " & sifre
body = body & "<br><br><a href=""http://www.sdal.org/"" target=""_blank"">Siteye girmek için burayi tiklayiniz!!</a><br><br>"

body = body & "</td></tr><tr><td width=100% height=5 align=left valign=bottom background=""http://www.sdal.org/downback.gif"">"
body = body & "</td></tr><tr><td width=100% height=50 align=left valign=bottom style=""background:#663300;font-size:10;color:#FFFFCC;font-family:verdana;"">"
 body = body & "<b>&nbsp; <a href=""http://www.sdal.org/"" style=""color:#FFFFCC;"" target=""_blank"">sdal.org</a> bir sdal kuruluþudur.</b></td></tr></table>"

body = body & "</td></tr></table>"

call mail("sdal@sdal.org","SDAL Üye Kayýt Motoru",email,"SDAL.ORG - ÞÝFRE HATIRLAMA!!","html","http://www.sdal.org/","sdal/",body)

end sub
'##################### SUB - SIFREGONDER BÝTÝÞÝ#######################################################


'##################### SUB - YASAKKONTROL #######################################################
sub yasakkontrol(id)
id=cint(id)
set ks=bag.execute("select * from uyeler where id="&id)
if ks.eof then
response.write "Böyle bir kullanýcý kayýtlý deðil!!"
response.end
end if
if ks("yasak") = 1 then
response.write "Siteye giriþiniz yasaklanmýþ!"
response.end
end if

end sub
'##################### SUB - YASAKKONTROL BÝTÝÞÝ #######################################################

'####################### SUB - SÝTEDEKÝLER KONTROLÜ ####################################################
sub sitedekiler_kontrol(bag)

sure = 20 'dakika - kullanýcýnýn iþlem yapmadan ne kadar süre boyunca online olacaðýný belirler

set sd=server.createobject("adodb.recordset")
sd.open "select * from uyeler where online = 1",bag,1,3

do while not sd.eof
if len(sd("sonislemtarih")) = 0 or len(sd("sonislemsaat")) = 0 then
'Biþey yapma
else
tarih = date()
saat = time()

tarih1 = now()

tarih2 = sd("sonislemtarih") & " " & sd("sonislemsaat")

fark = DateDiff("n",tarih2,tarih1)

burda = 0

if fark < sure then
burda = 1
end if

if burda = 0 then
sd("online") = 0
sd.update
end if

end if

sd.movenext
loop

end sub

'####################### SUB - SÝTEDEKÝLER KONTROLÜ BÝTÝÞÝ #############################################

'####################### SUB - Textleri resim Yapma #############################################

Sub imagetext(msgcode)

Set errorimage = Server.CreateObject("W3Image.Image")
errorimage.CreateEmptySurface 1,1

Set fontobj = errorimage.CreateFont("Tahoma",12,0,"bold",0,errorimage.CreateColor("#663300"),False,False,True)
errorimage.SetFont fontobj

width = errorimage.GetTextWidth(msgcode)
height = errorimage.GetTextHeight(msgcode)

errorimage.CreateEmptySurface width,height

set brushobj = errorimage.CreateSolidBrush(errorimage.CreateColor("#ffffcc"))
errorimage.SetBrush brushobj

errorimage.FloodFill 0,0,&HFFFFCC

errorimage.SetFont fontobj

errorimage.DrawText msgcode,0,0

errorimage.StreamImage Response, "JPG", 24

End Sub

'####################### SUB - Textleri resim Yapma BÝTÝÞÝ #############################################

'####################### FUNCTION - HTML KODU KAPATMA FONKSÝYONU #############################################

function htmlkapat(metin)

metin = Replace(metin,"<","&lt;")
metin = Replace(metin,">","&gt;")

htmlkapat = metin

end function

'####################### FUNCTION - HTML KODU KAPATMA FONKSÝYONU BÝTÝÞÝ #############################################

'####################### FUNCTION - METÝN DÜZENLEME FONKSÝYONU #############################################

function metinduzenle(metin)

metin = Replace(metin,"<","&lt;")
metin = Replace(metin,">","&gt;")
metin = replace(metin,chr(13),"<br>")

smiley_array=Array(":)",":@",":))","8)",":'(",":$",":D",":*",":)))",":#","*-)",":(",":o",":P","(:/",";)")
smiley_array2=Array(":y1:",":y2:",":y3:",":y4:",":y5:",":y6:",":y7:",":y8:",":y9:",":y10:",":y11:",":y12:",":y13:",":y14:",":y15:",":y16:")

for i=0 to 15
if i<>0 and i<>2 then
metin = Replace(metin,smiley_array(i),"<img src=smiley/"&i+1&".gif border=0 width=19 height=19>")
end if
metin = Replace(metin,smiley_array2(i),"<img src=smiley/"&i+1&".gif border=0 width=19 height=19>")
next
metin = Replace(metin,smiley_array(2),"<img src=smiley/3.gif border=0 width=19 height=19>")
metin = Replace(metin,smiley_array(0),"<img src=smiley/1.gif border=0 width=19 height=19>")

dizi = split(metin," ",-1,1)
i=0
for each kelimem in dizi
	dizi2 = split(kelimem,"<br>",-1,1)	 
	k=0
	for each kelime in dizi2
	
		if instr(1,kelime,"http://",1) > 0 then
			dizi2(k) = "<a href=""" & kelime & """ class=link target=""_blank"">" & kelime & "</a>"
		elseif instr(1,kelime,"www.",1) > 0 then
			dizi2(k) = "<a href=""http://" & kelime & """ class=link target=""_blank"">" & kelime & "</a>"
		elseif instr(1,kelime,".com",1) > 0 or instr(1,kelime,".net",1) > 0 or instr(1,kelime,".org",1) > 0 or instr(1,kelime,".edu",1) > 0 or instr(1,kelime,".tr",1) > 0 then
			dizi2(k) = "<a href=""http://www." & kelime & """ class=link target=""_blank"">" & kelime & "</a>"
		end if
		
		
		
	
	k=k+1
	next	
	
	kelimem = join(dizi2,"<br>")
	dizi(i) = kelimem
	
i=i+1
next

metin = join(dizi," ")

metin = Replace(metin,chr(9),"   ")
metin = Replace(metin,"  ","&nbsp;&nbsp;")

mesaj = metin
mesaj = replace(mesaj,"[b]","<b>")
mesaj = replace(mesaj,"[/b]","</b>")

mesaj = replace(mesaj,"[i]","<i>")
mesaj = replace(mesaj,"[/i]","</i>")

mesaj = replace(mesaj,"[u]","<u>")
mesaj = replace(mesaj,"[/u]","</u>")

mesaj = replace(mesaj,"[ul]","<ul>")
mesaj = replace(mesaj,"[/ul]","</ul>")

mesaj = replace(mesaj,"[sagayasla]","<div align=right>")
mesaj = replace(mesaj,"[/sagayasla]","</div>")

mesaj = replace(mesaj,"[solayasla]","<div align=left>")
mesaj = replace(mesaj,"[/solayasla]","</div>")

mesaj = replace(mesaj,"[ortala]","<center>")
mesaj = replace(mesaj,"[/ortala]","</center>")

mesaj = replace(mesaj,"[listele]","<li>")

mesaj = replace(mesaj,"[mavi]","<font style=color:blue;>")
mesaj = replace(mesaj,"[/mavi]","</font>")

mesaj = replace(mesaj,"[sari]","<font style=color:yellow;>")
mesaj = replace(mesaj,"[/sari]","</font>")

mesaj = replace(mesaj,"[yesil]","<font style=color:green;>")
mesaj = replace(mesaj,"[/yesil]","</font>")

mesaj = replace(mesaj,"[lacivert]","<font style=color:darkblue;>")
mesaj = replace(mesaj,"[/lacivert]","</font>")

mesaj = replace(mesaj,"[kayfe]","<font style=color:brown;>")
mesaj = replace(mesaj,"[/kayfe]","</font>")

mesaj = replace(mesaj,"[pembe]","<font style=color:pink;>")
mesaj = replace(mesaj,"[/pembe]","</font>")

mesaj = replace(mesaj,"[kirmizi]","<font style=color:red;>")
mesaj = replace(mesaj,"[/kirmizi]","</font>")

mesaj = replace(mesaj,"[portakal]","<font style=color:orange;>")
mesaj = replace(mesaj,"[/portakal]","</font>")

metin = mesaj


metinduzenle = metin

end function
'####################### FUNCTION - METÝN DÜZENLEME FONKSÝYONU BÝTÝÞÝ #############################################

'####################### TARÝH DÜZELTÝCÝ #############################################
function tarihduz(tarih)

if isDate(tarih) then

aylar=Array("Ocak","Þubat","Mart","Nisan","Mayýs","Haziran","Temmuz","Aðustos","Eylül","Ekim","Kasým","Aralýk")
gunler=Array("Pazar","Pazartesi","Salý","Çarþamba","Perþembe","Cuma","Cumartesi")

if len(tarih) > 12 then

tarih = Dateadd("h", 10, tarih)

end if

trh = Day(tarih) & " " & aylar(Month(tarih)-1) & " " & Year(tarih) & " " & gunler(Weekday(tarih)-1)

if len(tarih) > 12 then
saat = Hour(tarih)
if Len(saat) = 1 then
saat = "0" & cstr(saat)
end if
dakika = Minute(tarih)
if Len(dakika) = 1 then
dakika = "0" & cstr(dakika)
end if

st = saat & ":" & dakika

tarihduz = trh & " Saat " & st
else
tarihduz = trh
end if


else
tarihduz = ""
end if

end function
'####################### TARÝH DÜZELTÝCÝ BÝTÝÞÝ #############################################
'####################### FUNCTION - son xx üye çekme #############################################
function soncek(dsy,sonkac)

klasor = "sayfalog"
sonkayit = "<u>Son" & sonkac & "Üye</u>"
Set FSO = CreateObject("Scripting.FileSystemObject")
yol = FSO.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)

yol = FSO.BuildPath(yol,dsy)
If FSO.FileExists(yol) = True Then

start=4

set say = FSO.OpenTextFile(yol)
sayi = 0
Do While Not say.AtEndOfStream
asd = say.ReadLine
if say.Line > start then
sayi = sayi + 1
end if
Loop

sonkac=sonkac*3

start = sayi - sonkac
if start<0 then
start = 0
end if
start = start + 4

Set Dosya = FSO.OpenTextFile(yol)
i=0
k=0
Do While Not Dosya.AtEndOfStream

Satir = Dosya.ReadLine
if Dosya.Line > start then
if i=0 then
sonkayit = sonkayit & "<br>" & Satir
i=1
elseif i=1 then
sonkayit = sonkayit & " - " & Satir
k=k+1
i=2
else
i=0
end if

end if

Loop
Dosya.close

end if

soncek = sonkayit

end function
'####################### FUNCTION - son xx üye çekme bitiþi #############################################

'####################### sql injection engelleme #############################################
Function FilterBadWords(strWords)
strBadWords = Array("SELECT", "DROP", "--", "INSERT", "DELETE", "xp_", "UNION", "UPDATE", "'", "’", "<%", "<SCRIPT>", "<META", "<", ">","script","^","vbcrlf","SCRIPT","Script","script","object","OBJECT","Object","object","applet","APPLET","Applet","applet","embed","EMBED","Embed","embed","event","EVENT","Event","event","document","DOCUMENT","Document","document","cookie","COOKIE","Cookie","cookie","form","FORM","Form","form","on","ON","On","on","or","OR","Or","or","document.cookie","javascript:","vbscript:")

strBadWordsReplace = Array("&#83ELECT", "&#68ROP", "&#45-", "&#73NSERT", "&#68ELETE", "&#120P&#95", "&#85NION", "&#85PDATE", "&#39", "&#39", "", "", "", "[", "]","&#115cript","-","<br>","&#083CRIPT","&#083cript","&#083cript","&#111bject","&#079BJECT","&#079bject","&#079bject","&#097pplet","&#065PPLET","&#065pplet","&#065pplet","&#101mbed","&#069MBED","&#069mbed","&#069mbed","&#101vent","&#069VENT","&#069vent","&#069vent","&#100ocument","&#068OCUMENT","&#068ocument","&#068ocument","&#099ookie","&#067OOKIE","&#067ookie","&#067ookie","&#102orm","&#070ORM","&#070orm","&#070orm","&#111n","&#079N","&#079n","&#111n","&#111r","&#079R","&#079r","&#111r","&#068ocument.cookie","javascript ","vbscript ")
For iSQL = 0 to uBound(strBadWords)
strWords = Replace(strWords, strBadWords(iSQL), strBadWordsReplace(iSQL),1,-1,1)
Next
FilterBadWords = strWords
End Function
'####################### sql injection engelleme #############################################

iller=Array("01-Adana","02-Adýyaman","03-Afyon","04-Aðrý","05-Amasya","06-Ankara","07-Antalya","08-Artvin","09-Aydýn","10-Balýkesir","11-Bilecik","12-Bingöl","13-Bitlis","14-Bolu","15-Burdur","16-Bursa","17-Çanakkale","18-Çankýrý","19-Çorum","20-Denizli","21-Diyarbakýr","22-Edirne","23-Elazýð","24-Erzincan","25-Erzurum","26-Eskiþehir","27-Gaziantep","28-Giresun","29-Gümüþhane","30-Hakkari","31-Hatay","32-Isparta","33-Ýçel","34-Ýstanbul","35-Ýzmir","36-Kars","37-Kastamonu","38-Kayseri","39-Kýrklareli","40-Kýrþehir","41-Kocaeli","42-Konya","43-Kütahya","44-Malatya","45-Manisa","46-K.Maraþ","47-Mardin","48-Muðla","49-Muþ","50-Nevþehir","51-Niðde","52-Ordu","53-Rize","54-Sakarya","55-Samsun","56-Siirt","57-Sinop","58-Sivas","59-Tekirdað","60-Tokat","61-Trabzon","62-Tunceli","63-Þanlýurfa","64-Uþak","65-Van","66-Yozgat","67-Zonguldak","68-Aksaray","69-Bayburt","70-Karaman","71-Kýrýkkale","72-Batman","73-Þýrnak","74-Bartýn","75-Ardahan","76-Iðdýr","77-Yalova","78-Karabük","79-Kilis","80-Osmaniye","81-Düzce")
aylar=Array("Ocak","Þubat","Mart","Nisan","Mayýs","Haziran","Temmuz","Aðustos","Eylül","Ekim","Kasým","Aralýk")
%>