<?
session_start();
if(session_is_registered("admin")) {
session_unset();
session_destroy();

header("location:adminlogin.php");
}
else {
include("style.php");
die ("<center>Sadece giriþ yapmýþ kullanýcýlar içindir!</center><meta http-equiv='Refresh' content='2; URL=adminlogin.php'>");
}
?>
