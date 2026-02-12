<?
include("baglanti.php");


$ks2 = mysql_query("select * from sayac",$bag);
$ks3 = mysql_fetch_array($ks2);
$hit = $ks3['hit'];
if($sayfa=="anasayfa") {
$hit = $hit + 1;

$ks4 = mysql_query("UPDATE sayac SET hit = $hit WHERE id = '1' LIMIT 1",$bag);
}
?>
<?
$ks1 = mysql_query("select * from genel",$bag);
$ks = mysql_fetch_array($ks1);

$ne = $ks['sayac'];

if($ne == 'evet') {
?>
<b><?echo $hit?></b>
<?
}
else {
?>
<b>Kapatýlmýþtýr.</b>
<?
}

?>