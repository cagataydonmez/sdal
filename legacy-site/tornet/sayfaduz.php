<?
session_start();
if(!(session_is_registered("admin"))) {
session_unset();
session_destroy();

header("location:adminlogin.php");
}
include("baglanti.php");
?>
<title>Sayfa Düzenle</title>
<style>
textarea {font-family:verdana;font-size:10;color:#000033;border:1 solid #9cd3ce;}
body {font-family:verdana;font-size:10;color:#000033;}
input {font-family:verdana;font-size:10;color:#000033;border:1 solid #9cd3ce;font-weight:bold;background:white;}
</style>
<? if (!$HTTP_POST_VARS) {

$ks1 = mysql_query("select * from sayfa where id = '$sf'",$bag);
$ks = mysql_fetch_array($ks1);
?>
<b>Sayfa : <font style=color:blue;><?echo $ks['sayfaadi']?></font></b><br>
<form method=post action=sayfaduz.php>
<textarea name=metin cols=70 rows=18><?echo $ks['metin']?></textarea><br>
<input type=submit value="Kaydet" name="kaydet" onclick="form.kaydet.disabled=true;form.submit();">
<input type=hidden name=id value="<?echo $sf?>">
</form>
<?
}
else {

if(empty($metin)) {
$metin = "<center>Yapým aþamasýnda...</center>";
}
$ks = mysql_query("UPDATE sayfa SET metin = '$metin' WHERE id = '$id' LIMIT 1",$bag);
?>
<script language="JavaScript">
<!--
window.open('civilmicik.php?#sayfalar','civil', '');  
self.close();
//-->
</script>
<?
}
?>