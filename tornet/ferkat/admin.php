<?
if(!$HTTP_GET_VARS) {
header("location:admin.php?sayfa=1");
}
?>
<style>
body {font-family:verdana;font-size:11;color:#000033;}
a {font-family:verdana;font-size:11;color:#000033;text-decoration:none;font-weight:bold;}
a:hover {font-family:verdana;font-size:11;color:blue;text-decoration:none;font-weight:bold;}
td {font-family:verdana;font-size:11;color:#000033;border:1 solid #000033;}
tr {background:white;}
table {border:0;background:#cbcbcb}
</style>
<?
$bag=mysql_connect("localhost","sdal","2222tttt");
if(!$bag) die ("veri tabaný baðlantýsý kurulamadý!!");

mysql_select_db("catodata", $bag) or die ("Veritabaný açýlamýyor!!!".mysql_error() );

$kactane = 10;

$ilk = (intval($sayfa)-1)*$kactane;

$ks1 = mysql_query("select * from gorusler order by id desc limit $ilk, $kactane",$bag);
?>
<table border=1 bordercolor=#000033 cellpadding=3 width=100%>
<tr>
<td colspan=5>
<b>Kayýtlar</b>
</td></tr>
<?
if(!mysql_fetch_array($ks1)) {
?>
<tr>
<td colspan=5>
<b>Bu sayfada kayýt yoktur,þimdi ilk sayfaya yönlendiriliyorsunuz...</b>
</td></tr>
<meta http-equiv="Refresh" content="0; URL=admin.php?sayfa=1">
<?
}
?>
<tr>
<td bgcolor=#becbed>ID</td>
<td bgcolor=#becbed>Ýsim</td>
<td bgcolor=#becbed>Email</td>
<td bgcolor=#becbed>metin</td>
<td bgcolor=#becbed>tarih</td>
</tr>
<?
while ($ks=mysql_fetch_array($ks1)) {
?>
<tr onmouseover="this.style.backgroundColor='#ebebeb';" onmouseout="this.style.backgroundColor='white';">
<td><?echo $ks['id']?></td>
<td><?echo $ks['isim']?></td>
<td><?echo $ks['email']?></td>
<td><?echo $ks['metin']?></td>
<td><?echo $ks['tarih']?></td>
</tr>

<?
}
?>
</table>
<br><br>
<table width=100% border=0>
<tr>
<td align=left width=50%><?if($sayfa != "1"){?><a href="admin.php?sayfa=<?echo intval($sayfa)-1?>">önceki sayfa</a><?}?></td>
<td align=right width=50%><a href="admin.php?sayfa=<?echo intval($sayfa)+1?>">sonraki sayfa</a></td>
</tr>
</table>