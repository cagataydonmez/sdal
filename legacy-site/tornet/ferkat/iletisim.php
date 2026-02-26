<?
########################
####		         #######
#       ÖNEMLÝ DÜZENLEME
####		         #######
########################

$veritabani = "aktif"; #Gönderilen iletinin veritabanýna kaydedip kaydedilmemesiyle ilgili bilgi
                              #Eðer aktifleþtirirseniz iletiler veritabanýna kaydedilecek ve istendiði zaman 
		  #web'den yönetici bölümü vasýtasýyla görülebilecek..
		  #Aktif yapmak için yazmanýz gereken : aktif
		  #Ýnaktif yapmak için yazmanýz gereken : inaktif

$site_anasayfa = "http://cagataydonmez.awardspace.com/ferkat/index.php"; #sitenizin anasayfasý..

$eposta = "aktif"; #Gönderilen ileti belirtilen e-mail adresine gönderilir..
$epostayaz = "cagatay.donmez@gmail.com"; #E-posta adresini buraya yazýn..

	#################
	# ÖNEMLÝ :  veritabani veya eposta 'dan en az birini aktif yapmalýsýnýz!!!!
	#                eðer ikisini de inaktif yaparsanýz,kullanýcý formu gönderdiði zaman
	#                bir uyarý mesajýyla karþýlaþýr ve forma yazdýklarý iþleme tabi tutulmaz.
	#################

#####################

####################
#
#Sayfadaki yazýlarýn düzenlenmesi
#
####################

$anabaslik = "Ferkat için hazýrlanmýþ form";
  $abfont = "verdana";  #font tipi
  $absize = "13"; #puntosu
  $abcolor = "#000033"; #renklerin ingilizce isimlerini de yazabilirsiniz.(Örn:blue)
  $abweight = "bold"; #bold veya regular
  $abdeco = "none"; #altýnýn çizili olmasý olayý. (çizili için:underline --- çizgisiz için:none)
  $abback = "#bdbdbd"; #Baþlýðýn bulunduðu tablonun arkaplan rengi

$basliky = "Ýletiþim Formu";

$isimy = "Ýsim & Soyisim";
$emaily = "Email";
$iletiy = "Ýletiniz";
$gondery = "Gönder";

$isimgir = "Lütfen isminizi giriniz..";
$emailgir = "Lütfen e-mailinizi giriniz..";
$iletigir = "Lütfen iletinizi giriniz..";

$temizley = "Dikkat!!Týklarsanýz form temizlenecek!";
$gonderiyory = "Gönderiyor...";

$geridony = "Geri Dönüþ";

$durdur = "Ýþlem yönetici tarafýndan durdurulmuþ.Sistem geçici olarak servis dýþýdýr.";

$tebrik_veri = "Tebrikler! Ýletiniz ilgili kiþiye veritabaný yoluyla gönderilmiþtir..";
$tebrik_mail = "Tebrikler! Ýletiniz ilgili kiþiye email yoluyla gönderilmiþtir..";
$basarisiz_mail = "Üzgünüz,mail gönderirken bir hatayla karþýlaþýldý,mailiniz GÖNDERÝLEMEDÝ!!<br>Lütfen tekrar deneyiniz...";

##############################################
########################################################
###################################################################
############################################################################
###########   Buradan sonrasýna DOKANMA!!!!!!!    #########################################
############################################################################
###################################################################
########################################################
##############################################

$dosyaadi = "iletisim.php";

$tarih=date("d-m-Y H:i:s");
$ip = "yok";

$fokus = "onfocus=this.style.background='white';";
$bulur = "onblur=this.style.background='#fdfdfd';";

if($veritabani=="aktif") {
$bag=mysql_connect("localhost","sdal","2222tttt");
if(!$bag) die ("veri tabaný baðlantýsý kurulamadý!!");

mysql_select_db("catodata", $bag) or die ("Veritabaný açýlamýyor!!!".mysql_error() );
}


#
##########################

?>
<style>
body {font-family:verdana;font-size:11;color:#000033;}
td {font-family:verdana;font-size:11;color:#000033;}
input {font-family:verdana;font-size:11;color:blue;border:1 solid #000033;background:#fdfdfd;}
textarea {font-family:verdana;font-size:11;color:blue;border:1 solid #000033;background:#fdfdfd;}
.sub {font-family:verdana;font-size:11;color:#000033;border:1 solid #000033;font-weight:bold;background:#cbcbcb;cursor:hand;width=75;}
.bas {font-family:verdana;font-size:11;color:red;font-weight:bold;}
a {font-family:verdana;font-size:11;color:gray;font-weight:bold;text-decoration:none;}
a:hover {color:#cbcbcb;}
.anabaslik {font-family:<?echo $abfont?>;font-size:<?echo $absize?>;color:<?echo $abcolor?>;font-weight:<?echo $abweight?>;text-decoration:<?echo $abdeco?>;}
</style>
<?
if ($geldimi == "geldi") {

if(empty($isim)) {
die("<hr color=ededed size=1><center>$isimgir&nbsp;&nbsp;&nbsp;&nbsp;<a href=javascript:history.back(1); title='$geridony'>$geridony</a><hr color=ededed size=1></center>");
}
if(empty($email)) {
die("<hr color=ededed size=1><center>$emailgir&nbsp;&nbsp;&nbsp;&nbsp;<a href=javascript:history.back(1); title='$geridony'>$geridony</a><hr color=ededed size=1></center>");
}
if(empty($metin)) {
die("<hr color=ededed size=1><center>$iletigir&nbsp;&nbsp;&nbsp;&nbsp;<a href=javascript:history.back(1); title='$geridony'>$geridony</a><hr color=ededed size=1></center>");
}

if($veritabani == "aktif") {

# veritabanýna kayýt olayý...
$ks = mysql_query("insert into gorusler (isim,email,metin,tarih,ip) values ('$isim','$email','$metin','$tarih','$ip') ",$bag);
print("<center> <hr color=ededed size=1><center>$tebrik_veri </center><br><br>");

}

if($eposta == "aktif") {

# emaile gönderme olayý..
$mheader= "From: " ."$isim <$email>\n";
$mheader.= "X-Sender: " ."$email\n";
$sonuc = mail($epostayaz,$basliky,$metin,$mheader);

	if($sonuc) {
	echo "<hr color=ededed size=1><center>$tebrik_mail";
	}
	else {
	echo "<hr color=ededed size=1><center>$basarisiz_mail";
	}

}

if($veritabani == "inaktif" && $eposta == "inaktif") {
die ("$durdur");
}
?>
</center><hr color=ededed size=1>
<center><a href="<?echo $site_anasayfa?>">Anasayfa</a></center>

<?
}
else {
?>
<body onload="document.iletisimform.isim.focus();">
<center>
<form action="<?echo $dosyaadi?>" method=post name=iletisimform>
<table width=500 border=0 cellpadding=3 cellspacing=2 style="border=1 solid #000033;background:<?echo $abback?>;">
<tr>
<td align=center valign=middle class=anabaslik>
<?echo $anabaslik?>
</td>
</tr>
</table>

<table border=0 cellpadding=3 cellspacing=2 width=500 style="border=1 solid #000033;background:#fdfdfd;">
<tr>
<td width=100% valign=top align=left colspan=2 style="border:1 solid #000033;background:#dfdfdf;">
<table border=0 cellpadding=0 cellspacing=0 width=100%>
<tr><td align=left><font class=bas><li><?echo $basliky?></font> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type=text name=gizli2 size=47 style="border:0;background:#dfdfdf;color:#000033;" onmouseover="document.iletisimform.gizli2.blur();" onmouseout="document.iletisimform.gizli2.blur();"></td>
<td align=right><a onmouseover="document.iletisimform.gizli2.value='<?echo $temizley?>';document.iletisimform.gizli2.blur();" onmouseout="document.iletisimform.gizli2.value='';document.iletisimform.gizli2.blur();" onclick="document.iletisimform.reset();" style="cursor:hand;">[x]</a></td></tr></table>
</td>
</tr>
<tr>
<td width=175 valign=top align=right>
<b><?echo $isimy?> : </b>
</td>
<td width=325 valign=top align=left>
<input type=text name=isim onfocus="document.iletisimform.gizli1.value='<?echo $isimgir?>';" onblur="document.iletisimform.gizli1.value='';" size=20 maxlength=100 <?echo $fokus?> <?echo $bulur?>>
<input type=text name=gizli1 style="border:0;font-size:10;" size=30 disabled>
</td>
</tr>
<tr>
<td valign=top align=right>
<b><?echo $emaily?> : </b>
</td>
<td valign=top align=left>
<input type=text<input type=text onfocus="document.iletisimform.gizli1.value='<?echo $emailgir?>';" onblur="document.iletisimform.gizli1.value='';" name=email size=20 maxlength=100 <?echo $fokus?> <?echo $bulur?>>
</td>
</tr>
<tr>
<td valign=top align=right>
<b><?echo $iletiy?> : </b>
</td>
<td valign=top align=left>
<textarea name=metin onfocus="document.iletisimform.gizli1.value='<?echo $iletigir?>';" onblur="document.iletisimform.gizli1.value='';" rows=10 cols=50 <?echo $fokus?> <?echo $bulur?>></textarea>
</td>
</tr>
<tr>
<td valign=top align=right colspan=2>
<input type=submit class=sub name=iletisimsub value="<?echo $gondery?>" onmouseover="this.style.background='white';this.value='<?echo $gondery?>?';" onmouseout="this.style.background='#cbcbcb';this.value='<?echo $gondery?>';" onclick="document.iletisimform.gizli1.value='<?echo $gonderiyory?>';">
</td>
</tr>
</table>
<input type=hidden name=geldimi value="geldi">
</form>
</center>
<?
}
?>