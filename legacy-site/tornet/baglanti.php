<?

$bag=mysql_connect("vader","sdal","2222tttt");
if(!$bag) die ("veri tabaný baðlantýsý kurulamadý!!");

mysql_select_db("mydata", $bag) or die ("Veritabaný açýlamýyor!!!".mysql_error() );

$kon = mysql_query("select * from kontrol",$bag);

if(!$kon) {

?>
<font style="font-family:verdana;font-size:10;color:#000033;font-weight:bold;">
<center>Kurulum yapýlmamýþ, lütfen kurmak için aþaðýdaki linki týklayýnýz...
<br><br><br>
<a href="kur.php" title="kur">Kur</a>
</center></font>
<?
die();
}
?>