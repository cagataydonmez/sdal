<style>
body {font-family:verdana;font-size:10;color:#000033;font-weight:bold;}
td {font-family:verdana;font-size:10;color:#000033;font-weight:bold;}
input {font-family:verdana;font-size:10;color:#000033;border:1 solid #9cd3ce;}
.sub {font-family:verdana;font,size:10;color:#000033;border:1 solid #9cd3ce;background:#f6f6f4;font-weight:bold;}
</style>
<?
if(!$HTTP_POST_VARS) {
?>
<center>
Kurulumu tamamlayabilmek için lütfen aþaðýdaki bilgileri eksiksiz ve doðru bir biçimde doldurunuz...<br><br>
<form method=post action=kur.php>
<table border=0 cellpadding=3 cellspacing=0 width=300>
<tr>
<td width=100 align=right>Host : </td><td width=200 align=left><input type=text name=host size=20></td>
</tr>
<tr>
<td width=100 align=right>User : </td><td width=200 align=left><input type=text name=user size=20></td>
</tr>
<tr>
<td width=100 align=right>Þifre : </td><td width=200 align=left><input type=text name=password size=20></td>
</tr>
<tr>
<td width=100 align=right>Database : </td><td width=200 align=left><input type=text name=db size=20></td>
</tr>
<tr>
<td colspan=2 align=right>
<input type=submit value="Kurmaya Baþla" class=sub>
</td>
</tr>
</form>
</center>
<?
}
else {

$bag=mysql_connect("$host","$user","$password");
if(!$bag) die ("veri tabaný baðlantýsý kurulamadý!!");

mysql_select_db("$db", $bag) or die ("Veritabaný açýlamýyor!!!".mysql_error() );


$kon = mysql_query("select * from kontrol",$bag);

if(!$kon) {



$sql1 = 'CREATE TABLE `anket` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `hit` INT NOT NULL, `cevap` TEXT NOT NULL );';

$sql2 = 'CREATE TABLE `nedir` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `isim` TEXT NOT NULL, `metin` TEXT NOT NULL, `ip` TEXT NOT NULL, `tarih` TEXT NOT NULL );';

$sql3 = 'CREATE TABLE `sayac` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `hit` INT NOT NULL );';

$sql4 = 'CREATE TABLE `kontrol` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kuruldumu` TEXT NOT NULL );';

$sql5 = 'CREATE TABLE `genel` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `anket` TEXT NOT NULL, `sayac` TEXT NOT NULL, `haber` TEXT NOT NULL, `defter` TEXT NOT NULL );';

$sql6 = 'CREATE TABLE `sayfa` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `sayfaadi` TEXT NOT NULL, `metin` TEXT NOT NULL, `hit` INT NOT NULL );';

$yap1 = mysql_query($sql1,$bag);
$yap2 = mysql_query($sql2,$bag);
$yap3 = mysql_query($sql3,$bag);
$yap4 = mysql_query($sql4,$bag);
$yap5 = mysql_query($sql5,$bag);
$yap6 = mysql_query($sql6,$bag);


$sayi = 1;
$rs1 = mysql_query("insert into sayac (hit) values ('$sayi') ",$bag);

$rs2 = mysql_query("insert into kontrol (kuruldumu) values ('evet') ",$bag);

$rs3 = mysql_query("insert into anket (cevap,hit) values ('soru1',$sayi) ",$bag);
$rs4 = mysql_query("insert into anket (cevap,hit) values ('soru2',$sayi) ",$bag);

$tarih=date("d-m-Y H:i:s");
$rs5 = mysql_query("insert into genel (anket,sayac,haber,defter) values ('evet','evet','evet','hayir') ",$bag);

$rs6 = mysql_query("insert into nedir (isim,metin,tarih,ip) values ('ORT','Tornet, ORT insanýnýn adýna her sene þenlik düzenleyip üstüne binerek eðlenmeye çalýþtýðý alettir.','$tarih','yok') ",$bag);

$rs7 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Tornet Nedir?','<center>Yapým aþamasýnda...</center>') ",$bag);
$rs8 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Tornet Þenliðinin Amacý','<center>Yapým aþamasýnda...</center>') ",$bag);
$rs9 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Tornete Nasýl Binilir?','<center>Yapým aþamasýnda...</center>') ",$bag);
$rs10 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Tornet Nasýl Yapýlýr?','<center>Yapým aþamasýnda...</center>') ",$bag);
$rs11 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Þenlik Fotoðraflarý','<center>Yapým aþamasýnda...</center>') ",$bag);
$rs12 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Þenlik Videolarý','<center>Yapým aþamasýnda...</center>') ",$bag);
$rs13 = mysql_query("insert into sayfa (sayfaadi,metin) values ('Sponsorlar','<center>Yapým aþamasýnda...</center>') ",$bag);

?>

<center>Kurulum baþarýyla tamamlandý. Siteye girmek için aþaðýdaki linki týklayýnýz.<br><br><br>
<a href="index.php" title="Anasayfa">Siteye Gir</a></center>


<?
}

else {
?>
<center>Kurulum yapýlmýþ... <br><br><br><a href="index.php">Anasayfa</a></center>
<?
}
}
?>