<style>
body {font-family:verdana;font-size:10;color:#000033;font-weight:bold;}
td {font-family:verdana;font-size:10;color:#000033;font-weight:bold;}
input {font-family:verdana;font-size:10;color:#000033;border:1 solid #9cd3ce;}
.sub {font-family:verdana;font,size:10;color:#000033;border:1 solid #9cd3ce;background:#f6f6f4;font-weight:bold;}
</style>
<?
if(!$HTTP_POST_VARS) {
?>
<center>
Kurulumu tamamlayabilmek için lütfen aþaðýdaki bilgileri eksiksiz ve doðru bir biçimde doldurunuz...<br><br>
<form method=post action=kur.php>
<table border=0 cellpadding=3 cellspacing=0 width=300>
<tr>
<td width=100 align=right>Host : </td><td width=200 align=left><input type=text name=host size=20></td>
</tr>
<tr>
<td width=100 align=right>User : </td><td width=200 align=left><input type=text name=user size=20></td>
</tr>
<tr>
<td width=100 align=right>Þifre : </td><td width=200 align=left><input type=text name=password size=20></td>
</tr>
<tr>
<td width=100 align=right>Database : </td><td width=200 align=left><input type=text name=db size=20></td>
</tr>
<tr>
<td colspan=2 align=right>
<input type=submit value="Kurmaya Baþla" class=sub>
</td>
</tr>
</form>
</center>
<?
}
else {

$bag=mysql_connect("$host","$user","$password");
if(!$bag) die ("veri tabaný baðlantýsý kurulamadý!!");

mysql_select_db("$db", $bag) or die ("Veritabaný açýlamýyor!!!".mysql_error() );








$sql = 'CREATE TABLE `gorusler` ( `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `isim` VARCHAR(100) NOT NULL, `email` VARCHAR(100) NOT NULL, `metin` TEXT NOT NULL, `tarih` VARCHAR(20) NOT NULL, `ip` VARCHAR(30) NOT NULL );'; 


$yap = mysql_query($sql,$bag);

?>

<center>Kurulum baþarýyla tamamlandý. Siteye girmek için aþaðýdaki linki týklayýnýz.<br><br><br>
<a href="index.php" title="Anasayfa">Siteye Gir</a></center>

<?
}
?>