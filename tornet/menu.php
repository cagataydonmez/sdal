<? 
include("baglanti.php");

?>

<table border=0 cellpadding=3 cellspacing=0 width=100%>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="index.php" class=menulink title="Anasayfa">Anasayfa</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=1" class=menulink title="Tornet Nedir?">Tornet Nedir?</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=2" class=menulink title="Tornet þenliðinin amacý...">Tornet Þenliðinin Amacý</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=3" class=menulink title="Tornete Nasýl Binilir?">Tornete Nasýl Binilir?</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=4" class=menulink title="Tornet Nasýl Yapýlýr?">Tornet Nasýl Yapýlýr?</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=5" class=menulink title="Þenlik Fotoðraflarý">Þenlik Fotoðraflarý</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=6" class=menulink title="Þenlik Videolarý">Þenlik Videolarý</a></td></tr>
<?
$ks1 = mysql_query("select * from genel",$bag);
$ks = mysql_fetch_array($ks1);

$ne = $ks['defter'];

if($ne == 'evet') {
?>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="defter.php" class=menulink title="Ziyaretçi Defteri">Ziyaretçi Defteri</a></td></tr>
<?
}
?>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#f6f6e6';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="sayfa.php?sf=7" class=menulink title="Sponsorlar">Sponsorlar</a></td></tr>
<tr><td class=menutd align=left valign=middle onmouseover="this.style.backgroundColor='#ffffff';this.style.border='1 solid #000033';" onmouseout="this.style.backgroundColor='#f6f6f4';this.style.border='1 solid #F6F6F4';"><a href="http://www.robot.metu.edu.tr" style="text-decoration:none;" target="_blank" title="ODTÜ Robot Topluluðu Web sitesi"><b>ODTÜ Robot Topluluðu</b></a></td></tr>
</table>
