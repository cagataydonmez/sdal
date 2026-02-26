<?
session_start();
if(!(session_is_registered("admin"))) {
session_unset();
session_destroy();

header("location:adminlogin.php");
}
?>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-9" />
<style>
body {font-family:verdana;font-size:10;background:#f6f6f4;}
</style>
<?
include("baglanti.php");

$ks1 = mysql_query("delete from nedir where id = '$sid'",$bag);

?><center>
Kayıt Silindi!!<br><br>
<a href=civilmicik.php>Admin anasayfa</a>
</center>