<?
include("haber.php");
?>
<?
$sf = intval($sf);
include("baglanti.php");

$ks1 = mysql_query("select * from sayfa where id = '$sf'",$bag);
$ks = mysql_fetch_array($ks1);

$sayfa = $ks['sayfaadi'];
$metin = $ks['metin'];
$hit = $ks['hit'] + 1;
$hitekle = mysql_query("UPDATE sayfa SET hit = $hit WHERE id = '$sf' LIMIT 1 ",$bag);
?>
<html>
<head>
<title>ORT Tornet Şenliği - 2003 - <?echo $sayfa?></title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-9" />
<style>
body {font-family:verdana;font-size:10;color:#000033;background:#C8EBE9;}
.anatd0 {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#ffffff;}
.anatdust {font-family:verdana;font-size:10;color:#000033;border:0;background:#ffffff;padding:0;}
.anatdsol {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;border-left:0;background:#F6F6F4;}
.anatdsag {font-family:verdana;font-size:10;color:#000033;border:0;border-bottom:1 solid #9cd3ce;border-top:1 solid #9cd3ce;background:#FFFCFC;}
.anatdalt {font-family:verdana;font-size:10;color:#000033;border-top:0 solid #9CD3CE;background:#ffffff;}
.sagictd {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#ffffff;}
#kayantd {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#ffffff;}
.kayantd {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#ffffff;}
#kayantd2 {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#ffffff;}
#kayantd3 {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#ffffff;}
.menutd {font-family:verdana;font-size:10;color:#000033;border:1 solid #F6F6F4;}
.menulink {font-family:verdana;font-size:10;color:#000033;text-decoration:none;font-weight:bold;}
.menulink2 {font-family:verdana;font-size:10;color:#000033;text-decoration:none;}
.menulink2:hover {text-decoration:underline;}
.basliktd {font-family:verdana;font-size:12;color:blue;border-bottom:1 solid #9CD3CE;background:#ffffff;font-weight:bold;}
.basliktd2 {font-family:verdana;font-size:10;color:#000033;border:0 solid #9CD3CE;background:#ffffff;font-weight:bold;}
.kayittd {font-family:verdana;font-size:10;color:#000033;border:1 solid #9CD3CE;background:#F6F6F4;}
.inp {font-family:verdana;font,size:10;color:#000033;border:1 solid #9cd3ce;background:white;}
.sub {font-family:verdana;font,size:10;color:#000033;border:1 solid #9cd3ce;background:#f6f6f4;font-weight:bold;}
.formyazi {font-family:verdana;font-size:10;color:#000033;border:0;font-weight:bold;}
</style>
</head>
<body>
<table border=0 cellpadding=0 cellspacing=0 width=100% height=600>
<tr>
<td class=anatd0>

<table border=0 cellpadding=5 cellspacing=0 width=100% height=100%>
<tr>
<td class=anatdust colspan=2 height=100 align=left style="padding:2;">
<?
include("ust.php");
?>
</td>
</tr>

<tr>
<td class=anatdsol width=150 align=left valign=top>
<b>
.::Menu::.<hr color=#9cd3ce size=1>
<?
include("menu.php");
?>
<hr color=#9cd3ce size=1>
<br><br><br>
<table border=0 cellpadding=2 cellspacing=0 width=100% height=100>
<tr>
<td align=center valign=middle class=kayantd style="background:#f6f6e6;">
<b>Haber</b>
</td>
</tr>

<tr>
<td align=justify align=top id=kayantd>

<marquee align=left direction=up BEHAVIOR=SCROLL SCROLLAMOUNT=10 SCROLLDELAY=400 onmouseover="this.stop();this.style.cursor='help';document.all.kayantd.style.borderColor='#000033';" onmouseout="this.start();document.all.kayantd.style.borderColor='#9cd3ce';">
<?echo $haber?>
</marquee>

</td>
</tr>
</table>
<br><br><br>
<table border=0 cellpadding=2 cellspacing=0 width=100% height=100>
<tr>
<td align=center valign=middle class=kayantd style="background:#f6f6e6;">
<b>Anket</b>
</td>
</tr>

<tr>
<td align=justify valign=top id=kayantd2 onmouseover="document.all.kayantd2.style.borderColor='#000033';" onmouseout="document.all.kayantd2.style.borderColor='#9cd3ce';">

<?
include("anket.php");
?>

</td>
</tr>
</table>
<br><br><br>
<table border=0 cellpadding=2 cellspacing=0 width=100% height=40>
<tr>
<td align=center valign=middle class=kayantd style="background:#f6f6e6;">
<b>Toplam Ziyaretçi</b>
</td>
</tr>

<tr>
<td align=right valign=top id=kayantd3 onmouseover="document.all.kayantd3.style.borderColor='#000033';" onmouseout="document.all.kayantd3.style.borderColor='#9cd3ce';">

<?
include("sayac.php");
?>

</td>
</tr>
</table>

</td>
<td class=anatdsag>
<table border=0 cellpadding=4 cellspacing=0 width=100% height=100%>
<tr>
<td align=left valign=top class=sagictd>

<table width=100% cellpadding=3 cellspacing=0 border=0>
<tr>
<td class=basliktd align=left valign=top>
<?echo $sayfa?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
</td>
<td class=basliktd2 align=right valign=top>
ORT
</td>
</tr>
</table>
<br>
<?echo $metin?>


</td>
</tr>
</table>

</td>
</tr>

<tr>
<td class=anatdalt colspan=2 height=50 align=center>
<?
include("altmenu.php");
?>
<hr color=#9cd3ce size=1>
ODTÜ Robot Topluluğu Bahar Tornet Şenliği Web Sitesi
<br>
2003©ORT
</td>
</tr>
</table>

</td>
</tr>
</table>
</body>
</html>