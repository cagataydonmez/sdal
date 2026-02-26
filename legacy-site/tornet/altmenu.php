<a href=sayfa.php?sf=1 class=menulink2>Tornet Nedir?</a> | <a href=sayfa.php?sf=2 class=menulink2>Tornet Þenliðinin Amacý</a> | <a href=sayfa.php?sf=3 class=menulink2>Tornete Nasýl Binilir?</a> | <a href=sayfa.php?sf=4 class=menulink2>Tornet Nasýl Yapýlýr?</a> | <a href=sayfa.php?sf=5 class=menulink2>Þenlik Fotoðraflarý</a> | <a href=sayfa.php?sf=6 class=menulink2>Þenlik Videolarý</a> | 
<?
$ks1 = mysql_query("select * from genel",$bag);
$ks = mysql_fetch_array($ks1);

$ne = $ks['defter'];

if($ne == 'evet') {
?>
<a href=defter.php class=menulink2>Ziyaretçi Defteri</a> |
<? } ?>
<a href=sayfa.php?sf=7 class=menulink2>Sponsorlar</a> | <a href=http://www.robot.metu.edu.tr class=menulink2>ODTÜ Robot Topluluðu</a>