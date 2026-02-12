<?
include("baglanti.php");


$ks1 = mysql_query("select * from genel",$bag);
$ks = mysql_fetch_array($ks1);

$ne = $ks['haber'];

if($ne == 'evet') {

$haber = "ODTÜ Robot Topluluðu Bahar Tornet Þenliði Bahar Þenlikleri zamanýnda baþlayacaktýr.<br>Eðlenceye hazýr mýsýnýz??<br>Öyleyse buyrun Workshop'a!!! <br>siz de kendi tornetinizi yapýn...";

}
else {

$haber = "<b>kapatýlmýþtýr.</b>";
}

?>