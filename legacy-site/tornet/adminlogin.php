<?
session_start();
?>
<title>Tornet Admin</title>
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
<center>
<? 
if(!$HTTP_POST_VARS) {
?>
<font class=bas>Tornet Admin</font><br>
<form method=post action="adminlogin.php">
Þifre : <input type=password name=sifre size=20 maxlength=15 class=inp>
<input type=submit class=sub value="Gönder">
</form>
<br><br>
<a href=index.php>Anasayfa</a>
<?
}
else {

$asilsifre = "civiltornet";

if($sifre == $asilsifre) {


session_register("admin");
session_encode();
?>
<meta http-equiv="Refresh" content="0; URL=civilmicik.php">
<?
}
else {
echo "Þifreniz yanlýþ.Geri dönüp tekrar deneyiniz!<br><br><a href=javascript:history.back(1);>geri dönüþ</a>";
}

}
?>
</center>