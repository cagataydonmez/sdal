<%
set bkm=CreateObject("Scripting.FileSystemObject")
dosya = bkm.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),"bkm.txt")
If bkm.FileExists(dosya) = True Then

Set dsy = bkm.OpenTextFile(dosya)

durum = dsy.ReadLine
if durum <> "evet" then
	response.redirect "default.asp"
end if

End If
%>
<html>
<head>
<title> sdal.org - SDAL Mezunlarý Web Sitesi - Bakým Çalýþmasýnda</title>
</head>
<body>
<center>
<br><br>
<img src="bakim.jpg" border=0>
</center>
</body>
</html>