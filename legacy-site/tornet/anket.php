<?
include("baglanti.php");


$ks1 = mysql_query("select * from genel",$bag);
$ks = mysql_fetch_array($ks1);

$ne = $ks['anket'];

if($ne == 'evet') {
?>
<form method=post action=anket2.php>
Tornet Þenliðine katýlmak ister misiniz?
<hr color=#9cd3ce size=1>
<input type=radio name=id value=1>Evet,isterim.<br>
<input type=radio name=id value=2>Hayýr,istemem.<br>
<p align=center><input type=submit value="Gönder" class=sub></p>
</form>
<hr color=#9cd3ce size=1>
<center><a href=anketsonuc.php title="Anket sonuçlarýný görmek için týklayýn.." style="font-family:verdana;font-size:10;text-decoration:underline;font-weight:bold;color:blue;">Anket sonuçlarý</a></center>
<?
}
else {
?>
<b>Kapatýlmýþtýr.</b>
<?
}

?>