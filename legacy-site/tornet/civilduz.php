<?
session_start();
if(!(session_is_registered("admin"))) {
session_unset();
session_destroy();

header("location:adminlogin.php");
}
?>
<?
include("baglanti.php");

$ks = mysql_query("UPDATE genel SET anket = '$anket' WHERE id = '1' LIMIT 1",$bag);
$ks1 = mysql_query("UPDATE genel SET haber = '$haber' WHERE id = '1' LIMIT 1",$bag);
$ks2 = mysql_query("UPDATE genel SET sayac = '$sayac' WHERE id = '1' LIMIT 1",$bag);
$ks3 = mysql_query("UPDATE genel SET defter = '$defter' WHERE id = '1' LIMIT 1",$bag);

?>
<font style="font-family:verdana;font-size:10;color:#000033;font-weight:bold;">
<center>
Bilgiler güncellendi. 
<br><br>
<a href="civilmicik.php">geri dönüþ</a>
</center></font>